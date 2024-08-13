require_relative "lib/version"

Gem::Specification.new do |spec|
  spec.version = SOLID::CommunityClient::VERSION
  spec.name = 'solid-community-client-simple'
  spec.authors = ['Mark Wilkinson']
  spec.email = ['mark.wilkinson@upm.es']

  spec.summary = 'A simple client to interact with the SOLID Community Server.'
  spec.description = 'A simple client to interact with the SOLID Community Server.  NOTA BENE - this is NOT a fully functional SOLID client. It does only what I need it to do for a specific project.  It may or may not be useful to anyone else.  It is badly documented (if at all!). It has only been tested against the Docker version of the Solid Community Server runnign on localhost.  Don't blame me if it doesn't work for you.  Enough said?'
  spec.homepage = 'https://github.com/markwilkinson/solid-community-client-simple'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.6'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage + '/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  # spec.require_paths = []

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
