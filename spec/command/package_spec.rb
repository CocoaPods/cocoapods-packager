require File.expand_path('../../spec_helper', __FILE__)

module Pod

  DONT_CODESIGN = true

  describe Command::Spec::Package do
    describe 'CLAide' do
      after do
        Dir.glob("KFData-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("NikeKit-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("foo-bar-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("a-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("FH-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("cxa-symbols-*").each { |dir| Pathname.new(dir).rmtree }
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

      it "should produce a dynamic library when dynamic is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        file_command = "file #{lib}"
        output = `#{file_command}`.lines.to_a

        output[0].should.match /Mach-O universal binary with 5 architectures/
        output[1].should.match /Mach-O dynamically linked shared library i386/
      end

      it "should link category symbols when dynamic is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        file_command = "nm #{lib}"
        output = `#{file_command}`.lines.to_a

        match = output.detect { |line| line =~ /UIButton\(AFNetworking\)/ }
        match.should.not.be.empty
      end

      it "should produce a dynamic library for OSX when dynamic is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/KFData.podspec --dynamic })
        command.run

        lib = Dir.glob("KFData-*/osx/KFData.framework/KFData").first
        file_command = "file #{lib}"
        output = `#{file_command}`.lines.to_a

        output[0].should.match /Mach-O 64-bit dynamically linked shared library x86_64/
      end

      it "should produce a static library when dynamic is not specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        file_command = "file #{lib}"
        output = `#{file_command}`.lines.to_a

        output[0].should.match /Mach-O universal binary with 5 architectures/
        output[1].should.match /current ar archive random library/
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

      it "mangles symbols if the Pod has dependencies and framework is dynamic" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.reject { |e| e =~ /PodNikeKit/ }

        symbols.should == %w{ BBUNikePlusActivity BBUNikePlusSessionManager
                              BBUNikePlusTag NikeKitVersionNumber NikeKitVersionString }
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

      it "does not mangle standalone preserve symbols" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/cxa-symbols.podspec --preserve-symbols=__cxa_throw})
        command.run

        lib = Dir.glob("cxa-symbols-*/ios/cxa-symbols.framework/cxa-symbols").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.reject { |e| e =~ /Podcxa_symbols|PodsDummy_cxa_symbols/ }
        symbols.should == %w{ BBUNikePlusActivity BBUNikePlusSessionManager
                              BBUNikePlusTag __cxa_throw }
      end
      
      it "does not mangle preserve symbol patterns" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/cxa-symbols.podspec --preserve-symbols=__cxa_throw,^KSCrash$})
        command.run

        lib = Dir.glob("cxa-symbols-*/ios/cxa-symbols.framework/cxa-symbols").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.reject { |e| e =~ /Podcxa_symbols|PodsDummy_cxa_symbols/ }
        symbols.should == %w{ BBUNikePlusActivity BBUNikePlusSessionManager
                              BBUNikePlusTag KSCrash __cxa_throw }
      end

      it "does not mangle symbols if option --no-mangle is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --no-mangle })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.select { |e| e =~ /PodNikeKit/ }
        symbols.should == []
      end

      it "does not mangle preserve symbols if option --no-mangle is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/cxa-symbols.podspec --no-mangle --preserve-symbols=__cxa_throw })
        command.run

        lib = Dir.glob("cxa-symbols-*/ios/cxa-symbols.framework/cxa-symbols").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.reject { |e| e =~ /Podcxa_symbols|PodsDummy_cxa_symbols/ }
        symbols.should.include '__cxa_throw'
      end

      it "does not mangle symbols if option --no-mangle and --dynamic are specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --no-mangle --dynamic })
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
        `lipo #{lib} -verify_arch x86_64 i386 armv7 armv7s arm64`
        $?.success?.should == true
      end

      it "includes the correct architectures when packaging an iOS Pod as --dynamic" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        `lipo #{lib} -verify_arch armv7 armv7s arm64`
        $?.success?.should == true
      end

      it "includes Bitcode for device arch slices when packaging an iOS Pod" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first

        #Check for __LLVM segment in each device architecture
        `lipo -extract armv7 #{lib} -o armv7.a && otool -l armv7.a`.should.match /__LLVM/
        `lipo -extract armv7s #{lib} -o armv7s.a && otool -l armv7s.a`.should.match /__LLVM/
        `lipo -extract arm64 #{lib} -o arm64.a && otool -l arm64.a`.should.match /__LLVM/
        `rm armv7.a armv7s.a arm64.a`
      end

      it "includes Bitcode for device arch slices when packaging an dynamic iOS Pod" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first

        #Check for __LLVM segment in each device architecture
        `lipo -extract armv7 #{lib} -o armv7.a && otool -l armv7.a`.should.match /__LLVM/
        `lipo -extract armv7s #{lib} -o armv7s.a && otool -l armv7s.a`.should.match /__LLVM/
        `lipo -extract arm64 #{lib} -o arm64.a && otool -l arm64.a`.should.match /__LLVM/
        `rm armv7.a armv7s.a arm64.a`
      end

      it "does not include Bitcode for simulator arch slices when packaging an iOS Pod" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first

        #Check for __LLVM segment in each simulator architecture
        `lipo -extract i386 #{lib} -o i386.a && otool -l i386.a`.should.not.match /__LLVM/
        `lipo -extract x86_64 #{lib} -o x86_64.a && otool -l x86_64.a`.should.not.match /__LLVM/
        `rm i386.a x86_64.a`
      end

      it "does not include Bitcode for simulator arch slices when packaging an dynamic iOS Pod" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first

        #Check for __LLVM segment in each simulator architecture
        `lipo -extract i386 #{lib} -o i386.a && otool -l i386.a`.should.not.match /__LLVM/
        `lipo -extract x86_64 #{lib} -o x86_64.a && otool -l x86_64.a`.should.not.match /__LLVM/
        `rm i386.a x86_64.a`
      end

      it "does not include local ModuleCache references" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first

        #Check for ModuleCache references
        `strings #{lib}`.should.not.match /ModuleCache/
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

      it "it respects module_map directive" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/FH.podspec })
        command.run

        modulemap_contents = File.read(Dir.glob("FH-*/ios/FH.framework/Modules/module.modulemap").first)
        module_map = <<MAP
framework module FH {
  umbrella header "FeedHenry.h"

  export *
  module * { export * }
}
MAP
        modulemap_contents.should == module_map
      end

      # it "runs with a spec in the master repository" do
      #  command = Command.parse(%w{ package KFData })
      #  command.run
      #
      #  true.should == true  # To make the test pass without any shoulds
      # end
    end
  end
end
