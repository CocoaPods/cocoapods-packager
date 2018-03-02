Pod::Spec.new do |s|
  s.name         = "Archs"
  s.version      = "0.1.0"
  s.summary      = "Yo"
  s.homepage     = "http://google.com"
  s.license      = "MIT"
  s.author       = { "Boris Bügling" => "boris@icculus.org" }
  s.platform     = :ios, '8.0'
  s.source       = { :git => "https://github.com/neonichu/CPDColors.git", :tag => s.version }
  s.source_files = 'Code'

  s.dependency 'ABTestingVessel',  '~> 1.3'
end
