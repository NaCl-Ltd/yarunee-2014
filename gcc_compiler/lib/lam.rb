require 'pattern-match'
require 'sexp'
require 'forwardable'

module Lam
  class Error < StandardError; end

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
      when String
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
    end
    attr_accessor :lineno

    # このOpがもつblockの一覧を返す
    def blocks
      return @args.grep(Gcc)
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
      sargs = @args.map{|x|
        if x.is_a?(Gcc)
          raise "linenoが未設定です" if x.lineno.nil?
          x.lineno
        else
          x.to_s
        end
      }.join(' ')

      return "#{@op} #{sargs}"
    end
  end

  # gccプログラムの断片(=命令の列)を表すクラス
  class Gcc
    def initialize(ops)
      raise TypeError unless ops.is_a?(Array)
      @ops = ops
    end
    attr_reader :ops

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

    def initialize(varnames)
      @varnames = varnames
    end
    def_delegators :@varnames, :include?, :index

    def merge(varnames)
      Env.new(@varnames + varnames)
    end
  end

  # lam ASTをLam::Gccに変換する
  class Compiler
    def self.compile(e)
      ast = MacroTransformer.new.transform(e)
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

        # 変数参照
        with(varname & Symbol){
          unless env.include?(varname)
            raise Error, "変数#{varname}が定義されていません"
          end

          Gcc.new([Op[:LD, 0, env.index(varname)]])
        }

        with(_[:lambda, params, body]){
          cbody = compile(body, Env.new(params)) +
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
          }.inject(:+)

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

        with(_[head, *args]){
          [head, *args.map{|x| transform(x)}]
        }

        with(_){ program }
      }
    end
  end
end

if $0 == __FILE__
  require 'pp'
  c = Lam::Compiler.new
  prog = [:let, [[:x, 1], [:y, 2]], :x]
  ast = Lam::MacroTransformer.new.transform(prog)
  pp ast
  puts "--"
  ops = c.compile_main(ast)
  pp ops
  puts "--"
  puts ops.emit
end
