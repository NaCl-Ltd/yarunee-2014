require 'pattern-match'

module Lam
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
          if x.is_a?(Op) then "func" else x.inspect end
        }.join(', ')

        return "#<#{@op}[#{sargs}]>"
      end
    end

    def to_gcc
      sargs = @args.map{|x|
        if x.is_a?(Gcc)
          x.lineno
        else
          x.to_s
        end
      }.join(' ')

      return "#{@op} #{sargs}"
    end
  end

  class Gcc
    def initialize(ops)
      raise TypeError unless ops.is_a?(Array)
      @ops = ops
    end
    attr_reader :ops

    def +(other)
      raise TypeError unless other.is_a?(Gcc)
      Gcc.new(@ops + other.ops)
    end

    def lineno
      @ops.first.lineno
    end

    # Opの配列をgccプログラム文字列に変換する
    def emit
      blocks = @ops.flat_map(&:blocks)
      ops = @ops + blocks.flat_map(&:ops)

      # 1. 各Opに行番号を振る
      ops.each_with_index{|op, i|
        op.lineno = i
      }

      # 2. 上から順に出力する
      return ops.map{|op|
        op.to_gcc + "\n"
      }.join
    end
  end

  class Compiler
    def self.compile(e)
      c = new
      c.emit(c.compile_main(e))
    end
    
    def compile_main(e)
      body = compile(e)
      return body + Gcc.new([Op[:RTN]])
    end

    # lam ASTをOpの配列に変換する
    def compile(e)
      match(e){
        with(Integer){
          Gcc.new([Op[:LDC, e]])
        }
        with(_[:cons, ex, ey]){
          compile(ex) +
          compile(ey) +
          Gcc.new([Op[:CONS]])
        }

        with(_[:lambda, params, body]){
          cbody = compile(body) +
                  Gcc.new([Op[:RTN]])

          Gcc.new([Op[:LDF, cbody]]) 
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
    [:cons, 0, [:lambda, [], [:cons, 0, 1]]]
  )
  pp ops
  puts "--"
  puts ops.emit
end
