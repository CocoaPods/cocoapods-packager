require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Spec::Package do
    describe 'IntegrationTests' do
      after do
        Dir.glob("NikeKit-*").each { |dir| Pathname.new(dir).rmtree }
        Pathname.new('spec/fixtures/PackagerTest/NikeKit.framework').rmtree
      end

  	 it 'Allow integration into project alongside CocoaPods' do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run
        `cp -Rp NikeKit-*/ios/NikeKit.framework spec/fixtures/PackagerTest`

        Dir.chdir('spec/fixtures/PackagerTest') do
          `pod install`
          `xcodebuild -workspace PackagerTest.xcworkspace -scheme PackagerTest`
        end

        true.should == true  # To make the test pass without any shoulds
  	 end
    end
  end
end
