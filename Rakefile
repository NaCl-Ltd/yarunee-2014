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
