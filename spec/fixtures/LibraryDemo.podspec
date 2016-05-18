Pod::Spec.new do |s|
  s.name                = 'LibraryDemo'
  s.version             = '1.0.0'
  s.summary             = 'Demo'
  s.author              = {'Ole Gammelgaard Poulsen' => 'ole@shape.dk' }
  s.source              = { :git => 'https://github.com/olegam/LibraryDemo.git', :tag => s.version.to_s }
  s.source_files        = 'sources/**/*.{h,m}'
  s.requires_arc        = true
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.9'

  s.license = 'GPL' # :trollface:
  s.homepage = 'https://www.youtube.com/watch?v=32UGD0fV45g'
end
