Gem::Specification.new do |s|
  s.name          = 'logstash-input-tibems'
  s.version       = '0.1.0'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'this is logstash input plugin to receive messages from tibco ems queues'
  s.description   = 'this is first test plugin'
  s.homepage      = 'https://github.com/tobotak/logstash-input-tibcoems'
  s.authors       = ['tobotak for cgi use']
  s.email         = 'baron5002@gmail.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # plugin needs tibco ems jar files
  s.files << 'lib/jms-2.0.jar'
  s.files << 'lib/tibcrypt.jar'
  s.files << 'lib/tibjms.jar'
  s.files << 'lib/tibjmsadmin.jar'

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'stud', '>= 0.0.22'
  s.add_development_dependency 'logstash-devutils'
end
