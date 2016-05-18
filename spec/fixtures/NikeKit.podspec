Pod::Spec.new do |s|
  s.name         = 'NikeKit'
  s.version      = '0.0.1'
  s.summary      = 'Objective-C implementation of the Nike+ API.'
  s.homepage     = 'https://github.com/neonichu/NikeKit'
  s.license      = {:type => 'MIT', :file => 'LICENSE'}
  s.authors      = { 'Boris Bügling' => 'http://buegling.com' }
  s.source       = { :git => 'https://github.com/neonichu/NikeKit.git', :tag => s.version.to_s }
  s.platform     = :ios, '8.0'
  
  s.public_header_files = '*.h'
  s.source_files = '*.{h,m}'
  s.frameworks = 'Foundation'
  s.requires_arc = true

  s.dependency 'AFNetworking'
  s.dependency 'ISO8601DateFormatter'
  s.dependency 'KZPropertyMapper'
end
