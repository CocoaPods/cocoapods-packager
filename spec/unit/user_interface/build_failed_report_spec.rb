require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  module UserInterface
    describe BuildFailedReport do
      it 'should format a report correctly' do
        UI::BuildFailedReport.report('a', ['b']).should == "Build command failed: a\nOutput:\n    b\n"
      end
    end
  end
end
