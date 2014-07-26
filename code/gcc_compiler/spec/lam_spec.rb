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
AP 0
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
LDF 12
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
EOD

TESTS = TESTS_.split(/^--.*$/).map{|x|
  scm, gcc = *x.split(/^:$/)
  [scm.strip, gcc.lstrip]
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
  end
end
