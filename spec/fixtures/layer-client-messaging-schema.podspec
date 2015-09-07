Pod::Spec.new do |s|
  s.name         = "layer-client-messaging-schema"
  s.version      = "20140715104949748"
  s.summary      =  "Packages the database schema and migrations for layer-client-messaging-schema"
  s.homepage     = "http://github.com/layerhq"
  s.author       =  { "Steven Jones" => "steven@layer.com" }
  s.source       =  { :git => "https://github.com/neonichu/CPDColors.git",
  					  :tag => "0.1.0" }
  s.license      =  'Commercial'
  s.requires_arc = true
  s.platform     = :ios, '7.0'
  s.resource_bundles = { 'layer-client-messaging-schema' => ['Code/**/*.h'] }
end
