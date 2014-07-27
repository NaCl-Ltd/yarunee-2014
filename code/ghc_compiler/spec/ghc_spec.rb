require 'ghc'

class Ghc
  describe 'Ghc' do
    it "should extract labels" do
      expect(Ghc.compile(<<INPUT)).to eq(<<OUTPUT)
mov a,0
jeq (end),a,0
mov a,1

end:
int 0
hlt
INPUT
mov a,0
jeq 3,a,0
mov a,1
int 0
hlt
OUTPUT
    end

    it "should extract indented labels" do
      expect(Ghc.compile(<<INPUT)).to eq(<<OUTPUT)
mov a,0
jeq (end),a,0
mov a,1

  end:
    int 0
    hlt
INPUT
mov a,0
jeq 3,a,0
mov a,1
    int 0
    hlt
OUTPUT
    end

    it "should extract jmp" do
      expect(Ghc.compile(<<INPUT)).to eq(<<OUTPUT)
jmp 2
mov a,0
hlt
INPUT
jeq 2,0,0
mov a,0
hlt
OUTPUT
    end
  end
end
