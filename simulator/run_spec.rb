require 'tempfile'
require 'json'

tuples = [
  # The state of the world is encoded as follows:
  #
  # A 4-tuple consisting of
  #
  # 1. The map;
  # 2. the status of Lambda-Man;
  # 3. the status of all the ghosts;
  # 4. the status of fruit at the fruit location.
  #
  # The map is encoded as a list of lists (row-major) representing the 2-d
  # grid. An enumeration represents the contents of each grid cell:
  #
  #   * 0: Wall (`#`)
  #   * 1: Empty (`<space>`)
  #   * 2: Pill
  #   * 3: Power pill
  #   * 4: Fruit location
  #   * 5: Lambda-Man starting position
  #   * 6: Ghost starting position
  #
  # For example, this map
  #
  #   #####
  #   ##.##
  #   #.\%#
  #   ##.##
  #   #####
  "(list (list 0 0 0 0 0) (list 0 0 2 0 0) (list 0 2 5 4 0) (list 0 0 2 0 0) (list 0 0 0 0 0))",

  # The Lambda-Man status is a 5-tuple consisting of:
  #   1. Lambda-Man's vitality;
  #   2. Lambda-Man's current location, as an (x,y) pair;
  #   3. Lambda-Man's current direction;
  #   4. Lambda-Man's remaining number of lives;
  #   5. Lambda-Man's current score.
  "(list 4 (cons 2 2) 0 3 0)",

  # The status for each ghost is a 3-tuple consisting of
  #   1. the ghost's vitality
  #   2. the ghost's current location, as an (x,y) pair
  #   3. the ghost's current direction
  #
  # The Ghosts' vitality is an enumeration:
  #   * 0: standard;
  #   * 1: fright mode;
  #   * 2: invisible.
  #
  # The Ghosts' and Lambda-Man's direction is an enumeration:
  #   * 0: up;
  #   * 1: right;
  #   * 2: down;
  #   * 3: left.
  "(list 7 8 9)",

  # The status of the fruit is a number which is a countdown to the expiry of
  # the current fruit, if any.
  #   * 0: no fruit present;
  #   * n > 0: fruit present: the number of game ticks remaining while the
  #            fruit will will be present.
  "0"
]

def get_world(tuples)
  return "(list #{tuples.join(" ")})"
end

def update_tuples(tuples, index, tuple)
  copy_tuples = tuples.dup
  copy_tuples[index] = tuple
  return get_world(copy_tuples)
end

@spec = <<SPEC
(current_pos #{get_world(tuples)})
=> (2, 2)
--
(current_dir #{get_world(tuples)})
=> 0
--
(current_dir #{update_tuples(tuples, 1, "(list 4 (cons 11 16) 1 3 0)")})
=> 1
--
(current_dir #{update_tuples(tuples, 1, "(list 4 (cons 11 16) 2 3 0)")})
=> 2
--
(current_dir #{update_tuples(tuples, 1, "(list 4 (cons 11 16) 3 3 0)")})
=> 3
--
(search 1 2 (list (list 1 2 3) (list 4 5 6)))
=> 6
--
(map_pos (cons 2 1) #{tuples[0]})
=> 2
--
(map_pos (cons 2 3) #{tuples[0]})
=> 2
--
(direction 0)
=> (0, -1)
--
(direction 1)
=> (1, 0)
--
(direction 2)
=> (0, 1)
--
(direction 3)
=> (-1, 0)
--
(is_pill_pos #{get_world(tuples)} (cons -1 0))
=> 1
--
(is_pill_pos #{get_world(tuples)} (cons 1 0))
=> 0
--
(plus_cons (cons 1 2) (cons 1 2))
=> (2, 4)
SPEC

library = ""
library += File.read("./code/lambdaman.lam")
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
