require 'tempfile'
require 'json'

@spec = <<SPEC
(search 1 2 (list (list 1 2 3) (list 4 5 6)))
=> 6
--
(plus_cons (cons 1 2) (cons 1 2))
=> (2, 4)
SPEC

library = File.read("./code/lambdaman.lam")
library.gsub!(/^;\s+main.*/m, "")

specs = []
@spec.split(/^--.*$/).map{|x|
  spec = {}
  spec[:lamprogram] = x.lines[0..-2].join("\n")
  spec[:expected_result] = x.match(/^=> (.+)/)[1]

  Tempfile.open("lamprog") do |f|
    f.write([library, spec[:lamprogram]].join("\n"))
    f.flush
    spec[:program] = `bundle exec ./lam #{f.path}`
  end
  specs << spec
}

@js = <<JS
var specs = #{specs.to_json}

for (var i = 0; i < specs.length; i++) {
  runSpec(specs[i]);
};
JS

File.open(__dir__ + "/main.js", "w"){|f| f.write(@js)}
`firefox ./simulator/console.html`