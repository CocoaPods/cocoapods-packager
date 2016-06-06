require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Spec::Package do
  	describe 'Subspecs' do
  	  after do
  	  	Dir.glob("KFData-*").each { |dir| Pathname.new(dir).rmtree }
      end

      it 'can package a single subspec' do
      	Pod::Config.instance.sources_manager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/KFData.podspec --subspecs=Core})
        command.run

        true.should == true  # To make the test pass without any shoulds
      end

      it 'can package a list of subspecs' do
      	Pod::Config.instance.sources_manager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/KFData.podspec --subspecs=Core,Compatibility})
        command.run

        true.should == true  # To make the test pass without any shoulds
      end
  	end
  end
end

