require 'pattern-match'

module Lam
  class Op
    def self.[](op, *args)
      new(op, *args)
    end

    def initialize(op, *args)
      @op, @args = op, args
    end
  end

  class Compiler
    def compile(e)
      match(e){
        with(Integer){
          [Op[:LDC, e]]
        }
        with(_[:cons, e1, e2]){
          [Op[:CONS]
        }
      }
    end
  end
end
