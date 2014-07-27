require 'lam'

TESTS_ = <<EOD
1
:
LDC 1
RTN
--
-1
:
LDC -1
RTN
--
(+ 1 2)
:
LDC 1
LDC 2
ADD
RTN
--
(cons 1 2)
:
LDC 1
LDC 2
CONS
RTN
--
(if 7 8 9)
:
LDC 7
SEL 3 5
RTN
LDC 8
JOIN
LDC 9
JOIN
--
((lambda () 1))
:
LDF 3
TAP 0
RTN
LDC 1
RTN
--
((lambda (x) x) 7)
:
LDC 7
LDF 4
AP 1
RTN
LD 0 0
RTN
--
(lambda (x) (lambda (y) x))
:
LDF 2
RTN
LDF 4
RTN
LD 1 0
RTN
--
(+ 7 (inline "DBG\nSTOP"))
:
LDC 7
DBG
STOP
ADD
RTN
--
(list 7 8 9)
:
LDC 7
LDC 8
LDC 9
LDC 0
CONS
CONS
CONS
RTN
--
(debug 1)
:
LDC 1
DBUG
RTN
--
(define (f) 1)
(define (g) f)
1
:
DUM 2
LDF 8
LDF 10
LDF 6
RAP 2
RTN
LDC 1
RTN
LDC 1
RTN
LD 1 0
RTN
LDC 1
RTN
--
(break 1)
:
LDC 1
BRK
RTN
--
(cond (1 2) (3 4) (else 5))
:
LDC 1
SEL 3 5
RTN
LDC 2
JOIN
LDC 3
SEL 8 10
JOIN
LDC 4
JOIN
LDC 5
JOIN
EOD

TESTS = TESTS_.split(/^--.*$/).map{|x|
  scm, gcc = *x.split(/^:$/)
  [scm.strip, gcc.lstrip]
}

PARSER_TESTS = {
  '(foo bar "baz" 1 -1)' => [[:foo, :bar, "baz", 1, -1]],
  '"foo\nbar"' => ["foo\nbar"],
  '(foo) (bar)' => [[:foo], [:bar]],
  "(foo) ; 説明\n  (bar)" => [[:foo], [:bar]],
  '(+ 1 2)' => [[:+, 1, 2]],
  '(- 1 2)' => [[:-, 1, 2]],
  '(* 1 2)' => [[:*, 1, 2]],
  '(/ 1 2)' => [[:'/', 1, 2]],
  '(= 1 2)' => [[:'=', 1, 2]],
  '(> 1 2)' => [[:>, 1, 2]],
  '(>= 1 2)' => [[:>=, 1, 2]],
  '(int? 1)' => [[:int?, 1]],
  '(lambda (x) (lambda (y) x))' => [[:lambda, [:x], [:lambda, [:y], :x]]],
  '(let1 (x 1) bar)' => [[:let1, [:x, 1], :bar]],
}

module Lam
  describe 'Lam' do
    TESTS.each do |scm, gcc|
      it "should compile #{scm.inspect}" do
        result = Lam.compile(scm).lines.map{|l|
          # コメントを削除する
          l.sub(/ ;.*/, "")
        }.join
        expect(result).to eq(gcc)
      end
    end

    describe 'Parser' do
      PARSER_TESTS.each do |input, output|
        it "should parse #{input.inspect}" do
          expect(Lam::Parser.run(input)).to eq(output)
        end
      end
    end
  end
end
