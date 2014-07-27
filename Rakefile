VERSION = "2.0.0"

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

desc "Run spec of ghc_compiler/"
task :ghc_spec do
  chdir "code/ghc_compiler" do
    sh "bundle exec rspec"
  end
end

desc "Run spec of ai"
task :ai_spec do
  sh "bundle exec ruby simulator/run_spec.rb"
end

desc "Run lambdaman AI"
task :run_ai do
  sh "bundle exec ruby simulator/run_ai.rb"
end

desc "Build solution file"
task :solution do
  chdir "code" do
    sh "bundle exec ./lam lambdaman.lam > ../solution/lambdaman.gcc"
    4.times do |n|
      sh "bundle exec ./ghcc ghost#{n}.aghc > ../solution/ghost#{n}.ghc"
    end
  end
end

task :check_all_committed do
  sh "git diff --exit-code --quiet"
end

task :tag do
  sh "git tag -u `git config --get user.email` -s -a -m 'yarunee!' #{VERSION}"
end

task :archive do
  sh "git archive --format=tar.gz -9 #{VERSION} > yarunee-#{VERSION}.tar.gz"
end

desc "Release"
task release: %i(solution check_all_committed tag archive)
