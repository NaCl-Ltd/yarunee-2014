require 'pattern-match'
require 'pp'

class Sim
  def self.d(str)
    puts str if ENV["D"]
  end

  def run(src)
    ops = parse(src)
    VM.new.run(ops)
  end

  def parse(src)
    src.lines.map{|l|
      op, *args = *l.sub(/;.*/, "").rstrip.split
      [op, *args.map(&:to_i)]
    }
  end

  class VM
    class Error < StandardError; end

    #module Taggable
    #  attr_accessor :tag
    #end
    #module Tagging
    #  refine Numeric do include Taggable end
    #end
    #using Tagging

    def initialize
      reset
    end

    def reset
      @c = 0
      @s = []
      @d = [:stop]
      @env = nil
    end

    def dump
      Sim.d("--")
      Sim.d("stack: #{@s.inspect}")
      Sim.d("ctrl: #{@d.inspect}")
      Sim.d("env: #{@env.inspect}")
    end

    def run(ops)
      catch(:stop) do
        execute(ops)
      end
    end

    def execute(ops)
      loop do
        break if @c >= ops.size
        op = ops[@c]

        dump
        Sim.d("op: #{op.inspect}")

        match(op){
          with(_["LDC", n]){
            @s = PUSH(SET_TAG(TAG_INT,n),@s)
            @c = @c+1
          }

          with(_["LD", n_, i]){
            n = n_
            fp = @e
            while n > 0 do            # follow chain of frames to get n'th frame
              fp = FRAME_PARENT(fp)
              n = n-1
            end
            if FRAME_TAG(fp) == TAG_DUM then FAULT(FRAME_MISMATCH) end
            v = FRAME_VALUE(fp, i) # i'th element of frame
            @s = PUSH(v,@s)          # push onto the data stack
            @c = @c+1
          }

          with(_["ADD"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            z = x + y
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["SUB"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            z = x - y
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["MUL"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            z = x * y
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["DIV"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            z = x / y
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["CEQ"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            if x == y then
              z = 1
            else
              z = 0
            end
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["CGT"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            if x > y then
              z = 1
            else
              z = 0
            end
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["CGTE"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if TAG(y) != TAG_INT then FAULT(TAG_MISMATCH) end
            if x >= y then
              z = 1
            else
              z = 0
            end
            @s = PUSH(SET_TAG(TAG_INT,z),@s)
            @c = @c+1
          }

          with(_["ATOM"]){
            x,@s = POP(@s)
            if TAG(x) == TAG_INT then
              y = 1
            else
              y = 0
            end
            @s = PUSH(SET_TAG(TAG_INT,y),@s)
            @c = @c+1
          }

          with(_["CONS"]){
            y,@s = POP(@s)
            x,@s = POP(@s)
            z = ALLOC_CONS(x,y)
            @s = PUSH(SET_TAG(TAG_CONS,z),@s)
            @c = @c+1
          }

          with(_["CAR"]){
            x,@s = POP(@s)
            if TAG(x) != TAG_CONS then FAULT(TAG_MISMATCH) end
            y = CAR(x)
            @s = PUSH(y,@s)
            @c = @c+1
          }

          with(_["CDR"]){
            x,@s = POP(@s)
            if TAG(x) != TAG_CONS then FAULT(TAG_MISMATCH) end
            y = CDR(x)
            @s = PUSH(y,@s)
            @c = @c+1
          }

          with(_["SEL", t, f]){
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            @d = PUSH(SET_TAG(TAG_JOIN,@c+1),@d)   # save the return address
            if x == 0 then
              @c = f
            else
              @c = t
            end
          }

          with(_["JOIN"]){
            x,@d = POP(@d)
            if TAG(x) != TAG_JOIN then FAULT(CONTROL_MISMATCH) end
            @c = x.addr
          }

          with(_["LDF", f]){
            x = ALLOC_CLOSURE(f,@e)
            @s = PUSH(SET_TAG(TAG_CLOSURE,x),@s)
            @c = @c+1
          }

          with(_["AP", n]){
            x,@s = POP(@s)            # get and examine function closure
            if TAG(x) != TAG_CLOSURE then FAULT(TAG_MISMATCH) end
            f = CAR_CLOSURE(x)
            e = CDR_CLOSURE(x)
            fp = ALLOC_FRAME(n)      # create a new frame for the call
            set_FRAME_PARENT(fp, e)
            i = n-1
            while i != -1 do           # copy n values from the stack into the frame in reverse order
              y,@s = POP(@s)
              set_FRAME_VALUE(fp,i, y)
              i = i-1
            end
            @d = PUSH(@e,@d)                     # save frame pointer
            @d = PUSH(SET_TAG(TAG_RET,@c+1),@d)  # save return address
            @e = fp                             # establish new environment
            @c = f                              # jump to function
          }

          with(_["RTN"]){
            x,@d = POP(@d)            # pop return address
            if TAG(x) == TAG_STOP then MACHINE_STOP() end
            if TAG(x) != TAG_RET then FAULT(CONTROL_MISMATCH) end
            y,@d = POP(@d)            # pop frame pointer
            @e = y                    # restore environment
            @c = x.addr                    # jump to return address
          }

          with(_["DUM", n]){
            fp = ALLOC_FRAME(n)       # create a new empty frame of size n
            set_FRAME_PARENT(fp, @e)      # set its parent frame
            set_FRAME_TAG(fp, TAG_DUM)    # mark the frame as dummy
            @e = fp                    # set it as the new environment frame
            @c = @c+1
          }

          with(_["RAP", n]){
            x,@s = POP(@s)            # get and examine function closure
            if TAG(x) != TAG_CLOSURE then FAULT(TAG_MISMATCH) end
            f = CAR_CLOSURE(x)
            fp = CDR_CLOSURE(x)
            if FRAME_TAG(@e) != TAG_DUM then FAULT(FRAME_MISMATCH) end
            if FRAME_SIZE(@e) != n then FAULT(FRAME_MISMATCH) end
            if @e != fp then FAULT(FRAME_MISMATCH) end
            i = n-1
            while i != -1 do           # copy n values from the stack into the empty frame in reverse order
              y,@s = POP(@s)
              set_FRAME_VALUE(fp,i, y)
              i = i-1
            end
            ep = FRAME_PARENT(@e)
            @d = PUSH(ep,@d)                    # save frame pointer
            @d = PUSH(SET_TAG(TAG_RET,@c+1),@d)  # save return address
            unset_FRAME_TAG(fp, TAG_DUM)            # mark the frame as normal
            @e = fp                             # establish new environment
            @c = f                              # jump to function
          }

          with(_["STOP"]){
            MACHINE_STOP()
          }

          with(_["TSEL", t, f]){
            x,@s = POP(@s)
            if TAG(x) != TAG_INT then FAULT(TAG_MISMATCH) end
            if x == 0 then
              @c = f
            else
              @c = t
            end
          }

          with(_["TAP", n]){
            x,@s = POP(@s)            # get and examine function closure
            if TAG(x) != TAG_CLOSURE then FAULT(TAG_MISMATCH) end
            f = CAR_CLOSURE(x)
            e = CDR_CLOSURE(x)
            fp = ALLOC_FRAME(n)      # create a new frame for the call
            set_FRAME_PARENT(fp, e)
            i = n-1
            while i != -1 do            # copy n values from the stack into the frame in reverse order
              y,@s = POP(@s)
              set_FRAME_VALUE(fp,i, y)
              i = i-1
            end
            @e = fp                   # establish new environment
            @c = f                    # jump to function
          }

          with(_["TRAP", n]){
            x,@s = POP(@s)            # get and examine function closure
            if TAG(x) != TAG_CLOSURE then FAULT(TAG_MISMATCH) end
            f = CAR_CLOSURE(x)
            fp = CDR_CLOSURE(x)
            if FRAME_TAG(@e) != TAG_DUM then FAULT(FRAME_MISMATCH) end
            if FRAME_SIZE(@e) != n then FAULT(FRAME_MISMATCH) end
            if @e != fp then FAULT(FRAME_MISMATCH) end
            i = n-1
            while i != -1 do            # copy n values from the stack into the empty frame in reverse order
              y,@s = POP(@s)
              set_FRAME_VALUE(fp,i, y)
              i = i-1
            end
            unset_FRAME_TAG(fp, TAG_DUM)
            @e = fp                   # establish new environment
            @c = f                    # jump to function
          }

          with(_["ST", n, i]){
            fp = @e
            while n > 0 do            # follow chain of frames to get n'th frame
              fp = FRAME_PARENT(fp)
              n = n-1
            end
            if FRAME_TAG(fp) == TAG_DUM then FAULT(FRAME_MISMATCH) end
            v,@s = POP(@s)           # pop value from the data stack
            set_FRAME_VALUE(fp, i, v) # modify i'th element of frame
            @c = @c+1
          }

          with(_["DBUG"]){
            x,@s = POP(@s)
            @c = @c+1
          }

          with(_["BRK"]){
            @c = @c+1
          }

          with(_){
            raise "unknown op: #{op}"
          }
        }
      end

      dump
      Sim.d("--")
    end

    def PUSH(a, st)
      st.push(a)
      return st
    end

    def POP(st)
      if st.empty?
        raise Error, "空の@sをpopしようとした" if st.equal?(@s)
        raise Error, "空の@dをpopしようとした" if st.equal?(@d)
        raise Error, "空のスタックをpopしようとした"
      end
      return [st.pop, st]
    end

    class ConsCell
      def initialize(car, cdr)
        @car, @cdr = car, cdr
      end
      attr_reader :car, :cdr

      def inspect
        "(#{@car.inspect}, #{@cdr.inspect})"
      end
    end
    def ALLOC_CONS(x, y)
      ConsCell.new(x, y)
    end
    def CAR(c)
      raise Error, "#{c.inspect}のcarを取ろうとした" unless c.is_a?(ConsCell)
      c.car
    end
    def CDR(c)
      raise Error, "#{c.inspect}のcdrを取ろうとした" unless c.is_a?(ConsCell)
      c.car
    end

    Closure = Struct.new(:f, :e)
    def ALLOC_CLOSURE(f, e)
      Closure.new(f, e)
    end
    def CAR_CLOSURE(x)
      raise TypeError unless x.is_a?(Closure)
      x.f
    end
    def CDR_CLOSURE(x)
      raise TypeError unless x.is_a?(Closure)
      x.e
    end

    Frame = Struct.new(:values, :parent, :tag)
    def ALLOC_FRAME(n)
      Frame.new(Array.new(n, nil), nil, nil)
    end
    def set_FRAME_PARENT(frame, e)
      raise TypeError unless frame.is_a?(Frame)
      frame.parent = e
    end
    def set_FRAME_VALUE(frame, i, v)
      raise TypeError unless frame.is_a?(Frame)
      raise IndexError unless (0...frame.values.length).cover?(i)
      frame.values[i] = v
    end
    def set_FRAME_TAG(frame, tag)
      raise TypeError unless frame.is_a?(Frame)
      frame.tag = tag
    end
    def unset_FRAME_TAG(frame, tag)
      raise TypeError unless frame.is_a?(Frame)
      raise RuntimeError unless frame.tag == tag
      frame.tag = nil
    end
    def FRAME_PARENT(frame)
      raise TypeError unless frame.is_a?(Frame)
      frame.parent
    end
    def FRAME_TAG(frame)
      raise TypeError unless frame.is_a?(Frame)
      frame.tag
    end
    def FRAME_VALUE(frame, i)
      raise TypeError unless frame.is_a?(Frame)
      raise IndexError unless (0...frame.values.length).cover?(i)
      frame.values[i]
    end
    def FRAME_SIZE(frame)
      raise TypeError unless frame.is_a?(Frame)
      frame.values.length
    end

    TaggedInt = Struct.new(:i) {
      include Comparable
      def <=>(other); i <=> other.to_i; end
      def +(other); i + other.to_i; end
      def -(other); i - other.to_i; end
      def *(other); i * other.to_i; end
      def /(other); (i / other.to_i).floor; end
      def to_i
        i
      end
    }
    Join = Struct.new(:addr)
    Ret = Struct.new(:addr)

    TAG_INT = :tag_int
    TAG_CONS = :tag_cons
    TAG_DUM = :tag_dum
    TAG_JOIN = :tag_join
    TAG_CLOSURE = :tag_closure
    TAG_RET = :tag_ret
    TAG_STOP = :tag_stop
    def TAG(item)
      case item
      when TaggedInt then TAG_INT
      when ConsCell then TAG_CONS
      when Closure then TAG_CLOSURE
      when Join then TAG_JOIN
      when Ret then TAG_RET
      when :stop then TAG_STOP
      else raise "not tagged: #{item.inspect}"
      end
    end

    def SET_TAG(tag, item)
      case tag
      when TAG_INT
        raise Error, "not an int: #{item.inspect}(#{item.class})" unless item.is_a?(Fixnum)
        TaggedInt.new(item)
      when TAG_CONS
        raise Error, "not a cons: #{item.inspect}" unless item.is_a?(ConsCell)
        item
      when TAG_CLOSURE
        raise Error, "not a closure: #{item.inspect}" unless item.is_a?(Closure)
        item
      when TAG_JOIN
        raise Error, "not a addr: #{item.inspect}" unless item.is_a?(Integer)
        Join.new(item)
      when TAG_RET
        raise Error, "not a addr: #{item.inspect}" unless item.is_a?(Integer)
        Ret.new(item)
      else
        raise "unknown tag: #{tag.inspect}"
      end
    end

    FRAME_MISMATCH = "frame mismatch"
    TAG_MISMATCH = "tag mismatch"
    CONTROL_MISMATCH = "control mismatch"
    def FAULT(str)
    end

    def MACHINE_STOP
      throw :stop, :machine_stop
    end
  end
end

if $0 == __FILE__
  src = <<EOD
LDF 3
AP 0
RTN
LDC 8
RTN
EOD
  p Sim.new.run(src)
end
