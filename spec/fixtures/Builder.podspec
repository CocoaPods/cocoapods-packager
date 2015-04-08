Pod::Spec.new do |s|
  s.name         = 'Builder'
  s.version      = '0.0.1'
  s.summary      = 'Yo'
  s.homepage     = 'https://github.com/CocoaPods/cocoapods-packager'
  s.license      = {:type => 'MIT'}
  s.authors      = { 'Boris Bügling' => 'http://buegling.com' }
  s.source       = { :git => 'https://github.com/CocoaPods/cocoapods-packager.git', 
                     :tag => s.version.to_s }

  s.libraries               = 'xml2'
  s.requires_arc            = true
  s.xcconfig                = { 'OTHER_LDFLAGS' => '-lObjC' }
  s.compiler_flag           = "-DBASE_FLAG"

  s.ios.frameworks          = 'Foundation'
  s.ios.deployment_target   = '8.0'
  s.ios.compiler_flag       = "-DIOS_FLAG"

  s.osx.frameworks          = 'AppKit'
  s.osx.deployment_target   = "10.8"
  s.osx.requires_arc        = false
  s.osx.xcconfig            = { 'CFLAGS' => '-I.' }
  s.osx.compiler_flag       = "-DOSX_FLAG"
end
