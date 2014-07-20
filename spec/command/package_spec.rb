require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Spec::Package do
    describe 'CLAide' do
      it 'registers itself' do
        Command.parse(%w{ package }).should.be.instance_of Command::Package
      end

      it 'presents the help if no spec is provided' do
        command = Command.parse(%w{ package })
        should.raise CLAide::Help do
          command.validate!
        end.message.should.match /required/
      end

      it "errors if it cannot find a spec" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package KFData })
        should.raise CLAide::Help do
          command.run
        end.message.should.match /Unable to find/
      end

      it "runs with a path to a spec" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/KFData.podspec })
        command.run

        true.should == true  # To make the test pass without any shoulds
      end

      #it "runs with a spec in the master repository" do
      #  command = Command.parse(%w{ package KFData })
      #  command.run

      #  true.should == true  # To make the test pass without any shoulds
      #end
    end
  end
end
