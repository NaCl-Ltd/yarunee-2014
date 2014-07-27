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
    additional_comments = {} # {<address number> => [<comment1>, ...]}
    label_names_regexp = /\((#{labels.keys.join("|")})\)/
    lines = lines_without_label.each_with_index.map do |l, n|
      refs = []
      l = l.gsub(label_names_regexp) do # ラベル参照の置換え
        ref = Regexp.last_match[1]
        refs << ref
        labels[ref]
      end
      if refs.length > 0 # ラベル参照コメント
        additional_comments[n] = refs.sort.uniq.map {|x| "(#{x})"}
      end
      l
    end
    labels.each do |label, n| # ラベル定義コメント
      additional_comments[n] ||= []
      additional_comments[n].unshift("#{label}:")
    end
    return lines.each_with_index.map do |l, n|
      comments = additional_comments[n]
      comment = comments ? comments.map {|c| " " + c}.join : ""
      l + " ; #{n}#{comment}\n"
    end.join
  end
end
