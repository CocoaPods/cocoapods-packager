require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Spec::Package do
    describe 'CLAide' do
      after do
        Dir.glob("KFData-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("NikeKit-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("foo-bar-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("a-*").each { |dir| Pathname.new(dir).rmtree }
      end

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

      it "mangles symbols if the Pod has dependencies" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.reject { |e| e =~ /PodNikeKit/ }
        symbols.should == %w{ BBUNikePlusActivity BBUNikePlusSessionManager 
                              BBUNikePlusTag }
      end

      it "mangles symbols if the Pod has dependencies regardless of name" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/a.podspec })
        command.run

        lib = Dir.glob("a-*/ios/a.framework/a").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.reject { |e| e =~ /Poda/ }
        symbols.should == %w{ BBUNikePlusActivity BBUNikePlusSessionManager 
                                BBUNikePlusTag }
      end

      it "does not mangle symbols if option --no-mangle is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --no-mangle })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.select { |e| e =~ /PodNikeKit/ }
        symbols.should == []
      end

      it "includes the correct architectures when packaging an iOS Pod" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        `lipo #{lib} -verify_arch armv7 armv7s arm64`
        $?.success?.should == true
      end

      it "does not fail when the pod name contains a dash" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/foo-bar.podspec })
        command.run

        true.should == true  # To make the test pass without any shoulds
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
