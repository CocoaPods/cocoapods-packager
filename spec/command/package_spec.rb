require File.expand_path('../../spec_helper', __FILE__)

module Pod

  DONT_CODESIGN = true

  describe Command::Spec::Package do
    describe 'CLAide' do
      after do
        Dir.glob("Archs-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("CPDColors-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("KFData-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("NikeKit-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("Prelinkly-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("foo-bar-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("a-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("FH-*").each { |dir| Pathname.new(dir).rmtree }
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

      it "should incude vendor symbols if the Pod has binary dependencies" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/CPDColors.podspec --no-mangle })
        command.run

        lib = Dir.glob("CPDColors-*/ios/CPDColors.framework/CPDColors").first
        symbols = Symbols.symbols_from_library(lib)
        symbols.should.include('PFObject')
      end

      it "should incude vendor symbols when prelinking if the Pod has binary dependencies" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/Prelinkly.podspec --no-mangle --prelink })
        command.run

        lib = Dir.glob("Prelinkly-*/ios/Prelinkly.framework/Prelinkly").first
        symbols = Symbols.symbols_from_library(lib)
        symbols.should.include('PFObject')
      end

      it "should only include the requested symbols if --symbols is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/Prelinkly.podspec --no-mangle --prelink --symbols=spec/fixtures/prelinkly-symbols })
        command.run

        lib = Dir.glob("Prelinkly-*/ios/Prelinkly.framework/Prelinkly").first
        symbols = Symbols.symbols_from_library(lib)
        symbols.should == %w{ CPDObject }
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

      it "does not mangle symbols if option --no-mangle is specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --no-mangle })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.select { |e| e =~ /PodNikeKit/ }
        symbols.should == []
      end

      it "does not mangle symbols if option --no-mangle and --dynamic are specified" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --no-mangle --dynamic })
        command.run

        lib = Dir.glob("NikeKit-*/ios/NikeKit.framework/NikeKit").first
        symbols = Symbols.symbols_from_library(lib).uniq.sort.select { |e| e =~ /PodNikeKit/ }
        symbols.should == []
      end

      it "contains a single object when prelinking" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/CPDColors.podspec --no-mangle --prelink })
        command.run

        lib = Dir.glob("CPDColors-*/ios/CPDColors.framework/CPDColors").first
        objects = `nm -AgU #{lib} | cut -d ':' -f 2`.split.uniq.sort
        objects.count.should == 1
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

      it "includes only available architectures when packaging an iOS Pod with binary dependencies" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/Archs.podspec --no-mangle })
        command.run

        lib = Dir.glob("Archs-*/ios/Archs.framework/Archs").first
        `lipo #{lib} -verify_arch x86_64 i386 armv7 arm64`
        $?.success?.should == true
      end

      it "includes only available architectures when prelinking an iOS Pod with binary dependencies" do
        SourcesManager.stubs(:search).returns(nil)

        command = Command.parse(%w{ package spec/fixtures/Archs.podspec --no-mangle --prelink })
        command.run

        lib = Dir.glob("Archs-*/ios/Archs.framework/Archs").first
        `lipo #{lib} -verify_arch x86_64 i386 armv7 arm64`
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
