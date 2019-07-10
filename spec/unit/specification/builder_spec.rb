require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Builder do
    describe 'In general' do
      before do
        @spec = Specification.from_file('spec/fixtures/Builder.podspec')
        @static_sandbox_dir = temporary_directory + 'Pods'
        @installer = stub('Installer', :pod_targets => [])
        @builder = Builder.new(Platform.new(:ios), @installer, nil, @static_sandbox_dir, nil, nil, @spec, nil, nil, nil, nil, nil, nil)
      end

      it 'copies the license file if it exists' do
        path = @static_sandbox_dir + 'Builder/LICENSE.md'
        path.dirname.mkpath
        File.open(path, 'w') { |f| f.puts 'Permission is granted...' }
        @spec.stubs(:license).returns({ :file => 'LICENSE.md'})
        FileUtils.expects(:cp).with(path, '.')
        @builder.send(:copy_license)
        FileUtils.rm_rf(path.dirname)
      end
    end

    describe 'Xcodebuild command' do
      describe 'compiler flags' do
        before do
          @spec = Specification.from_file('spec/fixtures/Builder.podspec')
          @installer = stub('Installer', :pod_targets => [])
        end

        it "includes proper compiler flags for iOS" do
          @builder = Builder.new(Platform.new(:ios), @installer, nil, nil, nil, nil, @spec, nil, nil, nil, nil, nil, nil)
          @builder.expects(:xcodebuild).with("GCC_PREPROCESSOR_DEFINITIONS='$(inherited) PodsDummy_Pods_Builder=PodsDummy_PodPackage_Builder' -DBASE_FLAG -DIOS_FLAG", "ARCHS='x86_64 i386 arm64 armv7 armv7s' OTHER_CFLAGS='-fembed-bitcode -Qunused-arguments'").returns(nil)
          @builder.send(:compile)
        end

        it "includes proper compiler flags for OSX" do
          @builder = Builder.new(Platform.new(:osx), @installer, nil, nil, nil, nil, @spec, nil, nil, nil, nil, nil, nil)
          @builder.expects(:xcodebuild).with("GCC_PREPROCESSOR_DEFINITIONS='$(inherited) PodsDummy_Pods_Builder=PodsDummy_PodPackage_Builder' -DBASE_FLAG -DOSX_FLAG", nil).returns(nil)
          @builder.send(:compile)
        end
      end

      describe 'on build failure' do
        before do
          @spec = Specification.from_file('spec/fixtures/Builder.podspec')
          @installer = stub('Installer', :pod_targets => [])
          @builder = Builder.new(Platform.new(:ios), @installer, nil, nil, nil, nil, @spec, nil, nil, nil, nil, nil, nil)
        end

        it 'dumps report and terminates' do
          UI::BuildFailedReport.expects(:report).returns(nil)

          should.raise SystemExit do
            # TODO: check that it dumps report
            @builder.send(:compile)
          end
        end
      end
    end
  end
end
