Pod::Spec.new do |s|
  s.name             = "Prelinkly"
  s.version      = "0.1.0"
  s.summary      = "Yo"
  s.homepage     = "http://google.com"
  s.license      = "MIT"
  s.author       = { "Boris Bügling" => "boris@icculus.org" }
  s.platform     = :ios, '8.0'
  s.source       = { :git => "https://github.com/neonichu/CPDColors.git", :tag => s.version }

  s.source_files = 'Code'
  s.public_header_files = 'Code/**/*.h'

  s.prepare_command = <<-CMD
    cat > Code/CPDObject.h <<EOF
    @interface CPDObject : NSObject
    -(void)doSomething;
    @end
    EOF

    cat > Code/CPDObject.m <<EOF
    #import "CPDObject.h"
    #import <Parse/PFObject.h>
    @implementation CPDObject
    -(void)doSomething
    {
      PFObject *object = [[PFObject alloc] init];
    }
    @end
    EOF
  CMD

  s.dependency 'Parse-iOS-SDK'
end
