require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe 'Packager' do
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
  end
end
