require File.expand_path('../../spec_helper', __FILE__)

module Pod

  DONT_CODESIGN = true

  describe Command::Spec::Package do
    describe 'IntegrationTests' do
      after do
        Dir.glob("NikeKit-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("LibraryDemo-*").each { |dir| Pathname.new(dir).rmtree }
        FileUtils.rm_rf('spec/fixtures/PackagerTest/NikeKit.framework')
      end

  	 it 'Allow integration into project alongside CocoaPods' do
        Pod::Config.instance.sources_manager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run
        `cp -Rp NikeKit-*/ios/NikeKit.framework spec/fixtures/PackagerTest`

        log = ''

        Dir.chdir('spec/fixtures/PackagerTest') do
          `pod install 2>&1`
          log << `xcodebuild -workspace PackagerTest.xcworkspace -scheme PackagerTest -sdk iphonesimulator CODE_SIGN_IDENTITY=- 2>&1`
        end

        puts log if $?.exitstatus != 0
        $?.exitstatus.should == 0
  	 end

     it 'Allow integration of dynamic framework into project alongside CocoaPods' do
        Pod::Config.instance.sources_manager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run
        `cp -Rp NikeKit-*/ios/NikeKit.framework spec/fixtures/PackagerTest`

        log = ''

        Dir.chdir('spec/fixtures/PackagerTest') do
          `pod install 2>&1`
          log << `xcodebuild -workspace PackagerTest.xcworkspace -scheme PackagerTest -sdk iphonesimulator CODE_SIGN_IDENTITY=- 2>&1`
        end

        puts log if $?.exitstatus != 0
        $?.exitstatus.should == 0
  	 end

     it 'allows integration of a library without dependencies' do
        Pod::Config.instance.sources_manager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/LibraryDemo.podspec })
        command.run

        log = ''

        Dir.chdir('spec/fixtures/LibraryConsumerDemo') do
          `pod install 2>&1`
          log << `xcodebuild -workspace LibraryConsumer.xcworkspace -scheme LibraryConsumer 2>&1`
          log << `xcodebuild -sdk iphonesimulator -workspace LibraryConsumer.xcworkspace -scheme LibraryConsumer 2>&1`
        end

        puts log if $?.exitstatus != 0
        $?.exitstatus.should == 0
     end
    end
  end
end
