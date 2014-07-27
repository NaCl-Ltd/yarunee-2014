class Ghc
  # ラベルを展開する
  def self.compile(source)
    raw_lines = source.split("\n")
    labels = {}
    lines_without_label = []
    raw_lines.each do |l|
      if (md = /\A\s*([a-zA-Z0-9]+):/.match(l)) # ラベル行
        name = md[1]
        labels[name] = lines_without_label.length
        next
      end
      lines_without_label << l
    end
    label_names_regexp = /\((#{labels.keys.join("|")})\)/
    lines = lines_without_label.map do |l|
      l.gsub(label_names_regexp) do
        labels[Regexp.last_match[1]]
      end
    end
    return lines.map {|l| l + "\n"}.join
  end
end
