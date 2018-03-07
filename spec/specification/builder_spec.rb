require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Builder do
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
