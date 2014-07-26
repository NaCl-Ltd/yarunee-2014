require 'pattern-match'
require 'sexp'
require 'forwardable'
require 'pp'

module Lam
  class Error < StandardError; end

  def self.compile(src)
    program = Lam::Parser.run(src)
    return Lam::Compiler.compile(program)
  end

  def self.d(str)
    puts str if ENV["D"]
  end

  # S-式の文字列をlam ASTに変換するクラス
  class Parser
    def self.run(src)
      src = src.gsub(/;.*$/, "") # ;から後ろはコメントとして除去する。
      raw_ast = SExpressionParser.parse(src)
      return convert_recursive(raw_ast)
    end

    private

    def self.convert_recursive(ast)
      case ast
      when /\A-\d+\z/
        # 負数が文字列になることへの対処
        return ast.to_s.to_i
      when String
        # SExpressionParserが文字列"foo"を'["a", "b", "c"]'に
        # してしまうことへの対処
        return eval(ast).join
      when Array
        return ast.map{|x| convert_recursive(x)}
      else
        return ast
      end
    end
  end

  # gccプログラムの1つの命令を表すクラス
  #
  # op :: シンボル(:LDC等)
  # args :: 引数
  #   引数はたいていは数値(0, 1等)だが、
  #   LDF命令などはLam::Gccのインスタンスを引数に取る
  class Op
    def self.[](op, *args)
      new(op, *args)
    end

    def initialize(op, *args)
      @op, @args = op, args
      @lineno = nil
      @comment = nil
    end
    attr_accessor :lineno
    attr_accessor :comment

    # このOpがもつblockの一覧を返す
    def blocks
      return @args.flat_map{|arg|
        case arg
        when Gcc
          [arg] + arg.blocks
        else
          []
        end
      }
    end

    def inspect
      if @args.empty?
        "#<#{@op}>"
      else
        sargs = @args.map{|x|
          if x.is_a?(Gcc) then "func" else x.inspect end
        }.join(', ')

        return "#<#{@op}[#{sargs}]>"
      end
    end

    # この命令を.gccファイルの形式に変換する
    # 事前にGcc#linenoが設定されていなければならない
    def to_gcc
      if @op == :INLINE
        return @args.join
      end
      if @args.empty?
        sargs = ''
      else
        sargs = ' ' + @args.map{|x|
          if x.is_a?(Gcc)
            raise "linenoが未設定です" if x.lineno.nil?
            x.lineno
          else
            x.to_s
          end
        }.join(' ')
      end
      if @comment
        sargs += " ; #{@comment}"
      end

      return "#{@op}#{sargs}"
    end
  end

  # gccプログラムの断片(=命令の列)を表すクラス
  class Gcc
    def initialize(ops)
      raise TypeError unless ops.is_a?(Array)
      @ops = ops
    end
    attr_reader :ops

    # このGccがもつblockの一覧を返す
    def blocks
      @ops.flat_map(&:blocks)
    end

    def +(other)
      case other
      when Gcc
        Gcc.new(@ops + other.ops)
      when Array
        Gcc.new(@ops + other)
      else
        raise TypeError
      end
    end

    def lineno
      @ops.first.lineno
    end

    # gccプログラムを生成する
    def emit
      # 全てのブロックをプログラム末尾に連結する
      blocks = @ops.flat_map(&:blocks)
      ops = @ops + blocks.flat_map(&:ops)

      # 各Opに行番号を振る
      ops.each_with_index{|op, i|
        op.lineno = i
      }

      # 上から順に出力する
      return ops.map{|op|
        op.to_gcc + "\n"
      }.join
    end
  end

  # 束縛されている変数の列を表す
  class Env
    extend Forwardable

    def initialize(varnames, parent = nil)
      @varnames = varnames
      @parent = parent
    end
    def_delegators :@varnames, :include?, :index

    def merge(varnames)
      Env.new(@varnames + varnames)
    end

    def lookup(varname, n = 0)
      i = @varnames.index(varname)
      if i
        return n, i
      elsif @parent
        return @parent.lookup(varname, n + 1)
      else
        return nil
      end
    end
  end

  # lam ASTをLam::Gccに変換する
  class Compiler
    def self.compile(exprs)
      *defs, main = exprs

      # defineをパースする
      libdefs = defs.map{|d|
        match(d){
          with(_[:define, _[fname, *params], fbody]){
            [fname, params, fbody]
          }
          with(_){
            raise Error, "malformed define: #{d.inspect}"
          }
        }
      }
      match(main){
        with(_[:define, *rest]){
          raise Error, "mainの処理がありません"
        }
        with(_){}
      }

      # TODO: main内で使われてない関数はlibdefsから除くようにするとよいかも
      # 使われているかの判定は単純に正規表現とかでよいので

      if libdefs.empty?
        newmain = main
      else
        newmain = libdefs.reverse.inject(main){|prog, libdef|
          fname, params, fbody = *libdef
          [[:lambda, [fname], prog],
           [:lambda, params, fbody]]
        }
      end

      Lam.d(newmain.pretty_inspect)
      Lam.d("--")

      ast = MacroTransformer.new.transform(newmain)
      Lam.d(ast.pretty_inspect)
      Lam.d("--")

      new.compile_main(ast).emit
    end
    
    def compile_main(e)
      env = Env.new([])
      return compile(e, env) + [Op[:RTN]]
    end

    def compile(e, env)
      match(e){
        # 整数
        with(Integer){
          Gcc.new([Op[:LDC, e]])
        }
        [ [:+, :ADD],
          [:-, :SUB],
          [:*, :MUL],
          [:/, :DIV],
          [:"=", :CEQ],
          [:>,   :CGT],
          [:>=,  :CGTE],
        ].each do |sym, opname|
          with(_[sym, ex, ey]){
            compile(ex, env) +
            compile(ey, env) +
            Gcc.new([Op[opname]])
          }
        end
        [
          [:<,   :CGT],
          [:<=,  :CGTE],
        ].each do |sym, opname|
          # 引数の順序を入れ替えて、CGT/CGTEにコンパイルする
          with(_[sym, ey, ex]){
            compile(ex, env) +
            compile(ey, env) +
            Gcc.new([Op[opname]])
          }
        end
        with(_[:int?, ex]){
          compile(ex, env) +
          Gcc.new([Op[:ATOM]])
        }
        
        # コンスセル
        with(_[:cons, ex, ey]){
          compile(ex, env) +
          compile(ey, env) +
          Gcc.new([Op[:CONS]])
        }
        with(_[:car, ex]){
          compile(ex, env) +
          Gcc.new([Op[:CAR]])
        }
        with(_[:cdr, ex]){
          compile(ex, env) +
          Gcc.new([Op[:CDR]])
        }

        with(_[:debug, ex]){
          compile(ex, env) +
          Gcc.new([Op[:DBUG]])
        }

        with(_[:break, ex]){
          compile(ex, env) +
          Gcc.new([Op[:BRK]])
        }

        # 変数参照
        with(varname & Symbol){
          n, i = env.lookup(varname)
          unless n
            raise Error, "変数#{varname}が定義されていません"
          end

          op = Op[:LD, n, i]
          op.comment = "varref #{varname}"
          Gcc.new([op])
        }

        with(_[:lambda, params, body]){
          cbody = compile(body, Env.new(params, env)) +
                  [Op[:RTN]]

          Gcc.new([Op[:LDF, cbody]])
        }

        with(_[:if, cond, expr1, expr2]){
          cexpr1 = compile(expr1, env) + [Op[:JOIN]]
          cexpr2 = compile(expr2, env) + [Op[:JOIN]]

          compile(cond, env) +
          Gcc.new([Op[:SEL, cexpr1, cexpr2]])
        }

        with(_[:inline, str]){
          Gcc.new([Op[:INLINE, str]])
        }

        # 関数適用
        with(_[func, *args]){
          cargs = args.map{|arg|
            compile(arg, env)
          }.inject(Gcc.new([]), :+)

          cargs +
          compile(func, env) +
          Gcc.new([Op[:AP, args.length]])
        }

        with(_){
          raise "ast parse error: #{e.inspect}"
        }
      }
    end
  end

  # マクロを展開する
  #
  # NOTE: 現在はマクロ展開結果にはマクロが使えません
  # (使いたい場合は、変化がなくなるまで繰り返しtransformを適用するようにする。)
  class MacroTransformer
    def transform(program)
      match(program){
        with(_[:let1, varname, expr, body]){
          [[:lambda, [varname], transform(body)],
           transform(expr)]
        }

        with(_[:let, defs, body]){
          raise "malformed let: #{program.inspect}" if !defs.is_a?(Array) || defs.any?{|x| !x.is_a?(Array) || x.length != 2}
          varnames = defs.map(&:first)
          values = defs.map(&:last)
          [[:lambda, varnames, transform(body)],
           *values.map{|x| transform(x)}]
        }

        # (list 1 2 3)
        # => (cons 1 (cons 2 (cons 3 0)))
        with(_[:list, *values]){
          values.reverse.inject(0){|b, a|
            [:cons, transform(a), b]
          }
        }

        with(_[head, *args]){
          [transform(head), *args.map{|x| transform(x)}]
        }

        with(_){ program }
      }
    end
  end
end

if $0 == __FILE__
  require 'pp'
  c = Lam::Compiler.new
  prog = [:int?, 1]
  ast = Lam::MacroTransformer.new.transform(prog)
  pp ast
  puts "--"
  ops = c.compile_main(ast)
  pp ops
  puts "--"
  puts ops.emit
end
