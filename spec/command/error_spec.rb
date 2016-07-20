require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe 'Packager' do
    after do
        Dir.glob("CPDColors-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("layer-client-messaging-schema-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("OpenSans-*").each { |dir| Pathname.new(dir).rmtree }
        Dir.glob("Weakly-*").each { |dir| Pathname.new(dir).rmtree }
      end

    it 'presents the help if a directory is provided' do
      should.raise CLAide::Help do
        command = Command.parse(%w{ package spec })
      end.message.should.match /is a directory/
    end

    it 'presents the help if a random file is provided instead of a specification' do
      should.raise CLAide::Help do
        command = Command.parse(%w{ package README.md })
      end.message.should.match /is not a podspec/
    end

    it 'presents the help if a podspec with binary-only dependencies is used' do
      command = Command.parse(%w{ package spec/fixtures/CPDColors.podspec })
      should.raise CLAide::Help do
        command.validate!
      end.message.should.match /binary-only/
    end

    it 'presents the help if only --bundle-identifier is specified' do
      command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --bundle-identifier=com.example.NikeKit })
      should.raise CLAide::Help do
        command.validate!
      end.message.should.match /--bundle-identifier option can only be used for dynamic frameworks/
    end

    it 'presents the help if both --exclude-deps and --dynamic are specified' do
      command = Command.parse(%w{ package spec/fixtures/NikeKit.podspec --exclude-deps --dynamic })
      should.raise CLAide::Help do
        command.validate!
      end.message.should.match /--exclude-deps option can only be used for static libraries/
    end

    it 'can package a podspec with only resources' do
      command = Command.parse(%w{ package spec/fixtures/layer-client-messaging-schema.podspec --no-mangle })
      command.run

      true.should == true  # To make the test pass without any shoulds
    end

    it 'can package a podspec with binary-only dependencies if --no-mangle is specified' do
      command = Command.parse(%w{ package spec/fixtures/CPDColors.podspec --no-mangle })
      command.run

      true.should == true  # To make the test pass without any shoulds
    end

    it 'can package a podspec with resource bundles' do
      command = Command.parse(%w{ package spec/fixtures/OpenSans.podspec })
      command.run

      bundles = Dir.glob('OpenSans-*/ios/OpenSans.framework/Versions/A/Resources/*.bundle')
      bundles.count.should == 1
    end

    it 'can package a podspec with weak frameworks without strong linking' do
      command = Command.parse(%w{ package spec/fixtures/Weakly.podspec })
      command.run

      `otool -l Weakly-*/ios/Weakly.framework/Weakly`.should.not.match /AssetsLibrary/
    end
  end
end
