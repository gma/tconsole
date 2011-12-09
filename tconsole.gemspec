# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "tconsole/version"

Gem::Specification.new do |s|
  s.name        = "tconsole"
  s.version     = TConsole::VERSION
  s.authors     = ["Alan Johnson"]
  s.email       = ["alan@commondream.net"]
  s.homepage    = ""
  s.summary     = %q{tconsole gives you a helpful console for running Rails tests}
  s.description = %q{tconsole gives you a helpful console for running Rails tests}

  s.rubyforge_project = "tconsole"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
