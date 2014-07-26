require 'pattern-match'
require 'sexp'

module Lam
  # S-式の文字列をlam ASTに変換するクラス
  class Parser
    def self.run(src)
      src = src.gsub(/;.*$/, "") # ;から後ろはコメントとして除去する。
      return SExpressionParser.parse(src)
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
    def initialize(varnames)
      @varnames = varnames
    end

    def merge(varnames)
      Env.new(@varnames + varnames)
    end
  end

  # lam ASTをLam::Gccに変換する
  class Compiler
    def self.compile(e)
      c = new
      c.compile_main(e).emit
    end
    
    def compile_main(e)
      env = Env.new([])
      return compile(e, env) + [Op[:RTN]]
    end

    def compile(e, env)
      match(e){
        with(Integer){
          Gcc.new([Op[:LDC, e]])
        }
        with(_[:cons, ex, ey]){
          compile(ex, env) +
          compile(ey, env) +
          [Op[:CONS]]
        }

        # 変数参照
        with(Symbol){
          raise "TODO"
        }

        with(_[:lambda, params, body]){
          cbody = compile(body, env.merge(params)) +
                  [Op[:RTN]]

          Gcc.new([Op[:LDF, cbody]])
        }

        with(_[:if, cond, expr1, expr2]){
          cexpr1 = compile(expr1, env) + [Op[:JOIN]]
          cexpr2 = compile(expr2, env) + [Op[:JOIN]]

          compile(cond, env) +
          [Op[:SEL, cexpr1, cexpr2]]
        }

        # 関数適用
        with(_[func, *args]){
          cargs = args.map{|arg|
            compile(arg, env)
          }.inject(:+)

          cargs +
          compile(func, env) +
          [Op[:AP, args.length]]
        }

        with(_){
          raise "ast parse error: #{e.inspect}"
        }
      }
    end
  end
end

if $0 == __FILE__
  require 'pp'
  c = Lam::Compiler.new
  ops = c.compile_main(
    [[:lambda, [:x], 7], 8]
  )
  pp ops
  puts "--"
  puts ops.emit
end
