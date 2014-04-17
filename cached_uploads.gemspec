Gem::Specification.new do |s|
  s.name         = 'cached_uploads'
  s.version      = '0.0.3'
  s.date         = '2014-04-11'
  s.summary      = 'Validation-friendly uploads for Rails'
  s.description  = 'Caches file uploads when validation fails.'
  s.authors      = ['Jarrett Colby']
  s.email        = 'jarrett@madebyhq.com'
  s.files        = Dir.glob('lib/**/*')
  s.homepage     = 'https://github.com/jarrett/cached_uploads'
  s.license      = 'MIT'
  
  s.add_development_dependency 'turn', '~> 0'
end