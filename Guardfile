require "shellwords"

xclip_command = `which xclip`.chomp
clip = (xclip_command == "" ? [`which pbcopy`.chomp] :
        [xclip_command, *%w(-in -selection clipboard)])

ignore %r{/.#}

guard :bundler do
  watch('Gemfile')
end

guard :shell do
  watch(%r{\Acode/gcc_compiler/(lib|spec)/.*\.rb\z}) do
    system("rake lam_spec")
  end

  watch(/(.*).lam\z/) do |m|
    path = m[0]
    puts("processing: #{path}")
    system("bundle exec ./lam #{Shellwords.escape(path)} | #{Shellwords.join(clip)}")
    puts("output to clipboard.")
  end
end
