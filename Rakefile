VERSION = "1.0.0"

desc "Compile a.lam"
task :a do
  sh "bundle exec ./lam a.lam > a.gcc && cat a.gcc"
end

task :aa do
  sh "bundle exec ./lam a.lam > a.gcc && cat a.gcc && pbcopy < a.gcc"
end

desc "Run spec of gcc_compiler/"
task :lam_spec do
  chdir "code/gcc_compiler" do
    sh "bundle exec rspec"
  end
end

desc "Build solution file"
task :solution do
  chdir "code" do
    sh "bundle exec ./lam lambdaman.lam > ../solution/lambdaman.gcc"
  end
end

task :check_all_committed do
  sh "git diff --exit-code --quiet"
end

task :tag do
  sh "git tag #{VERSION}"
end

task :archive do
  sh "git archive --format=tar.gz -9 #{VERSION} > yarunee-#{VERSION}.tar.gz"
end

desc "Release"
task release: %i(solution check_all_committed tag archive)
