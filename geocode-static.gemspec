lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'geocode/static/version'

Gem::Specification.new do |spec|
  spec.name          = "geocode-static"
  spec.version       = Geocode::Static::VERSION
  spec.authors       = ["Scott Bronson"]
  spec.email         = ["brons_geost@rinspin.com"]
  spec.summary       = "Generate a Ruby if statement to geocode IP addresses"
  spec.description   = "Geocode an IP address with a single if statement.  No network access, no context switches, no waiting."
  spec.homepage      = "http://github.com/bronson/geocode-static"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end