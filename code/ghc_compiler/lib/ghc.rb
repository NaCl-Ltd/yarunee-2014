class Ghc
  # ラベルを展開する
  def self.compile(source)
    raw_lines = source.split("\n")
    labels = {}
    lines_without_label = []
    raw_lines.each do |l|
      l = l.sub(/\s*;.*/, "")
      next if "" == l
      if (md = /\A\s*([a-zA-Z0-9]+):/.match(l)) # ラベル行
        name = md[1]
        labels[name] = lines_without_label.length
        next
      end
      if (md = /\A(\s*)jmp(\s+)(.*)/.match(l)) # jmp
        l = md[1] + "jeq" + md[2] + md[3] + ",0,0" + md.post_match
      end
      lines_without_label << l
    end
    label_names_regexp = /\((#{labels.keys.join("|")})\)/
    lines = lines_without_label.map do |l|
      l.gsub(label_names_regexp) do
        labels[Regexp.last_match[1]]
      end
    end
    inverted_labels = labels.invert
    return lines.each_with_index.map do |l, n|
      label = inverted_labels[n]
      label_description = label ? " #{label}:" : ""
      l + " ; #{n}#{label_description}\n"
    end.join
  end
end
