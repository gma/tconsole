# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "tconsole/version"

Gem::Specification.new do |s|
  s.name        = "tconsole"
  s.version     = TConsole::VERSION
  s.authors     = ["Alan Johnson"]
  s.email       = ["alan@commondream.net"]
  s.homepage    = ""
  s.summary     = %q{tconsole is a helpful console for running Rails tests}
  s.description = <<-EOF
    tconsole allows Rails developers to easily and quickly run their tests as a whole or in subsets. It forks the testing processes from
    a preloaded test environment to ensure that developers don't have to reload their entire Rails environment between test runs.
  EOF

  s.rubyforge_project = "tconsole"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "chattyproc", "~> 1.0.0"
  s.add_runtime_dependency "termin-ansicolor", "~> 1.3.0.2"
end
