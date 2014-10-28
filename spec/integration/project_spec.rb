require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Spec::Package do
    describe 'IntegrationTests' do
      after do
        Dir.glob("NikeKit-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("LibraryDemo-*").each { |dir| Pathname.new(dir).rmtree }
        FileUtils.rm_rf('spec/fixtures/PackagerTest/NikeKit.framework')
      end

  	 it 'Allow integration into project alongside CocoaPods' do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run
        `cp -Rp NikeKit-*/ios/NikeKit.framework spec/fixtures/PackagerTest`

        Dir.chdir('spec/fixtures/PackagerTest') do
          `pod install 2>&1`
          `xcodebuild -workspace PackagerTest.xcworkspace -scheme PackagerTest 2>&1`
        end

        $?.exitstatus.should == 0
  	 end

     it 'allows integration of a library without dependencies' do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/LibraryDemo.podspec })
        command.run

        Dir.chdir('spec/fixtures/LibraryConsumerDemo') do
          `pod install 2>&1`
          `xcodebuild -workspace LibraryConsumer.xcworkspace -scheme LibraryConsumer 2>&1`
          `xcodebuild -sdk iphonesimulator -workspace LibraryConsumer.xcworkspace -scheme LibraryConsumer 2>&1`
        end

        $?.exitstatus.should == 0
     end 
    end
  end
end
