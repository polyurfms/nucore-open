$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "external_accounts/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "external_accounts"
  spec.version     = ExternalAccounts::VERSION
  spec.authors     = [""]
  spec.email       = [""]
  spec.homepage    = ""
  spec.summary     = ""
  spec.description = ""


  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

end
