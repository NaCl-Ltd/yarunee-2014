require 'pattern-match'

class Ghc
  class Error < StandardError; end

  def self.d(str)
    puts str if ENV["D"]
  end

  def run(src)
    ops = parse(src)
    VM.new.run(ops)
  end

  class Op
    def initialize(opecode, args)
      @opecode, @args = opecode, args
    end
    attr_reader :opecode, :args
    def self.deconstruct(val)
      accept_self_instance_only(val)
      [val.opecode, val.args]
    end

    def inspect
      sargs = ' ' + @args.map{|x|
        match(x){
          with(_[:reg, name]){ name }
          with(_[:ref, name]){ "[#{name}]" }
          with(_){ x.to_s }
        }
      }.join(',')
      sargs = '' if @args.empty?

      "#<#{@opecode}#{sargs}>"
    end
  end

  def parse(src)
    src.lines.reject{|l|
      l.strip.empty?
    }.map{|l|
      l.sub(/;.*$/, "")
    }.map{|l|
      opecode, *rest = l.split.map(&:strip)
      rawargs = rest.join.split(/,/).map(&:strip)

      args = rawargs.map{|item|
        case item
        when /\d+/
          item.to_i
        when /\[(.*)\]/
          [:ref, $1.strip.upcase]
        else
          [:reg, item.upcase]
        end
      }

      Op.new(opecode.upcase.to_sym, args)
    }
  end

  class VM
    def initialize
      reset
    end

    def reset
      @pc = 0
      @registers = ("A".."H").map{|x| [x, 0]}.to_h
      @mem = Array.new(256, 0)
    end

    def dump
      Ghc.d("--")
      Ghc.d("registers: #{@registers.inspect}")
      #Ghc.d("mem: #{@mem.inspect}")
      #Ghc.d("pc: #{@pc.inspect}")
    end

    def run(ops)
      catch(:hlt) do
        run1(ops)
      end
    end

    def run1(ops)
      loop do
        break if @pc >= ops.length
        op = ops[@pc]
        dump
        Ghc.d("op: #{op.inspect}")

        match(op){
          with(Op.(:MOV, _[_[:reg, reg], src])){
            @registers[reg] = value(src)
            @pc += 1
          }
          with(Op.(:INC, _[pos])){
            set(pos, (value(pos) + 1) % 256)
            @pc += 1
          }
          with(Op.(:DEC, _[pos])){
            set(pos, (value(pos) - 1) % 256)
            @pc += 1
          }
          with(Op.(:ADD, _[_[:reg, reg], src])){
            @registers[reg] = (@registers[reg] + value(src)) % 256
            @pc += 1
          }
          with(Op.(:SUB, _[_[:reg, reg], src])){
            @registers[reg] = (@registers[reg] - value(src)) % 256
            @pc += 1
          }
          with(Op.(:MUL, _[_[:reg, reg], src])){
            @registers[reg] = (@registers[reg] * value(src)) % 256
            @pc += 1
          }
          with(Op.(:DIV, _[_[:reg, reg], src])){
            @registers[reg] = (@registers[reg] / value(src)).floor
            @pc += 1
          }
          with(Op.(:AND, _[_[:reg, reg], src])){
            @registers[reg] &= value(src)
            @pc += 1
          }
          with(Op.(:OR, _[_[:reg, reg], src])){
            @registers[reg] |= value(src)
            @pc += 1
          }
          with(Op.(:XOR, _[_[:reg, reg], src])){
            @registers[reg] ^= value(src)
            @pc += 1
          }

          with(Op.(:JLT, _[addr, x, y])){
            if value(x) < value(y) then @pc += value(addr) else @pc += 1 end
          }
          with(Op.(:JEQ, _[addr, x, y])){
            if value(x) == value(y) then @pc += value(addr) else @pc += 1 end
          }
          with(Op.(:JGT, _[addr, x, y])){
            if value(x) > value(y) then @pc += value(addr) else @pc += 1 end
          }

          with(Op.(:INT, _[i])){
            case value(i)
            when 0
              dir = @registers["A"]
              msg("ゴーストの向きを#{dir}に設定しました")
            when 1
              x, y = 0, 0
              @registers["A"] = x
              @registers["B"] = y
              msg("プレイヤー1の座標を取得しました(#{x}, #{y})")
            when 2
              x, y = 0, 0
              @registers["A"] = x
              @registers["B"] = y
              msg("プレイヤー2の座標を取得しました(#{x}, #{y})")
            when 3
              i = 0
              @registers["A"] = i
              msg("ゴーストの番号を取得しました(#{i})")
            when 4
              i = @registers["A"]
              x, y = 0, 0
              @registers["A"] = x
              @registers["B"] = y
              msg("ゴースト#{i}の初期座標を取得しました(#{x}, #{y})")
            when 5
              i = @registers["A"]
              x, y = 0, 0
              @registers["A"] = x
              @registers["B"] = y
              msg("ゴースト#{i}の座標を取得しました(#{x}, #{y})")
            when 6
              i = @registers["A"]
              v, d = 0, 0
              @registers["A"] = v
              @registers["B"] = d
              msg("ゴースト#{i}の情報を取得しました(vitality #{v}, direction #{d})")
            when 7
              x, y = @registers["A"], @registers["B"]
              m = 0
              @registers["A"] = 0
              msg("地図の(#{x}, #{y})の情報を取得しました(#{m})")
            when 8
              msg("pc: #{@pc}")
              msg("registers: #{@registers.inspect}")
            end
            @pc += 1
          }
          with(Op.(:HLT, _[])){
            throw :hlt
          }

          with(_){
            raise "unknown op: #{op.inspect}"
          }
        }
      end
      Ghc.d("--")
    end

    def msg(s)
      puts s
    end

    def value(src)
      match(src){
        with(_[:reg, x]){ @registers[x] }
        with(_[:ref, x]){ @mem[@registers[x]] }
        with(Fixnum){ src }
        with(_){ raise "cannot get a value: #{src.inspect}" }
      }
    end

    def set(pos, val)
      match(pos){
        with(_[:reg, x]){ @registers[x] = val }
        with(_[:ref, x]){ @mem[@registers[x]] = val }
        with(_){ raise "cannot set to #{src.inspect}" }
      }
    end
  end
end

if $0 == __FILE__
  src = <<EOD
mov a,255  
mov b,0    
mov c,255  
           
inc c      
jgt 7,[c],a
           
mov a,[c]
EOD

  p Ghc.new.run(src)
end
