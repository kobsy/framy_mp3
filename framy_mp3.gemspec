
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "framy_mp3/version"

Gem::Specification.new do |spec|
  spec.name          = "framy_mp3"
  spec.version       = FramyMP3::VERSION
  spec.authors       = ["Matthew Kobs"]
  spec.email         = ["matt.kobs@cph.org"]

  spec.summary       = %q{FramyMP3 is a simple library for working with and merging mp3 files in Ruby.}
  spec.homepage      = "https://github.com/kobsy/framy_mp3"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
