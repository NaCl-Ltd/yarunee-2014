VERSION = "1.0.0"

desc "Compile a.lam"
task :a do
  sh "bundle exec ./lam a.lam > a.gcc && cat a.gcc"
end

desc "Run spec of gcc_compiler/"
task :lam_spec do
  chdir "gcc_compiler" do
    sh "bundle exec rspec"
  end
end

task :tag do
  sh "git tag #{VERSION}"
end

task :archive do
  sh "git archive --format=tar.gz -9 #{VERSION} > yarunee-#{VERSION}.tar.gz"
end

desc "Release"
task release: %i(tag archive)
