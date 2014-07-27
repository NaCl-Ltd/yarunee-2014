require 'tempfile'
require 'json'
require 'optparse'

ai = ""
ai += File.read("./code/gcc_compiler/lam/prelude.lam")
ai += File.read("./code/lambdaman.lam")

game = {
  ghosts: []
}
opt = OptionParser.new
opt.on("--g1 VALUE"){|v| game[:ghosts][0] = File.read(v)}
opt.on("--g2 VALUE"){|v| game[:ghosts][1] = File.read(v)}
opt.on("--g3 VALUE"){|v| game[:ghosts][2] = File.read(v)}
opt.on("--g4 VALUE"){|v| game[:ghosts][3] = File.read(v)}
opt.on("-m VALUE")  {|v| game[:map]     = File.read(v)}
opt.parse!(ARGV)

Tempfile.open("lamprog") do |f|
  f.write(ai)
  f.flush
  game[:gcc] = `bundle exec ./lam #{f.path}`
end

@js = <<JS
var game = #{game.to_json}

runAi(game);
JS

File.open(__dir__ + "/main.js", "w"){|f| f.write(@js)}
`firefox ./simulator/run_ai.html`