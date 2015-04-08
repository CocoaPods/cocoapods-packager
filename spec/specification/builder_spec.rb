require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Builder do
    before do
      @spec = Specification.from_file('spec/fixtures/Builder.podspec')

      @builder = Builder.new(nil, nil, nil, @spec, nil, nil)
    end

    describe 'Xcodebuild command' do

      it "includes proper compiler flags for iOS" do
        @builder.expects(:xcodebuild).with('GCC_PREPROCESSOR_DEFINITIONS=\'PodsDummy_Pods_Builder=PodsDummy_PodPackage_Builder\' -DBASE_FLAG -DIOS_FLAG ARCHS="x86_64 i386 arm64 armv7 armv7s"').returns(nil)
        @builder.compile(Platform.new(:ios))
      end

      it "includes proper compiler flags for OSX" do
        @builder.expects(:xcodebuild).with("GCC_PREPROCESSOR_DEFINITIONS='PodsDummy_Pods_Builder=PodsDummy_PodPackage_Builder' -DBASE_FLAG -DOSX_FLAG").returns(nil)
        @builder.compile(Platform.new(:osx))
      end
    end
  end
end
