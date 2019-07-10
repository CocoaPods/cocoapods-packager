require 'coveralls'
Coveralls.wear!

require 'pathname'
ROOT = Pathname.new(File.expand_path('../../', __FILE__))
$:.unshift((ROOT + 'lib').to_s)
$:.unshift((ROOT + 'spec').to_s)

require 'bundler/setup'
require 'bacon'
require 'mocha-on-bacon'
require 'pretty_bacon'
require 'cocoapods'

require 'cocoapods_plugin'

#-----------------------------------------------------------------------------#

module Pod

  # Disable the wrapping so the output is deterministic in the tests.
  #
  UI.disable_wrap = true

  # Redirects the messages to an internal store.
  #
  module UI
    @output = ''
    @warnings = ''

    class << self
      attr_accessor :output
      attr_accessor :warnings

      def puts(message = '')
        @output << "#{message}\n"
      end

      def warn(message = '', actions = [])
        @warnings << "#{message}\n"
      end

      def print(message)
        @output << message
      end
    end
  end
end

#-----------------------------------------------------------------------------#

module SpecHelper
  def self.fixture(name)
    Fixture.fixture(name)
  end

  def self.temporary_directory
    ROOT + 'tmp'
  end

  module Fixture
    ROOT = Pathname('fixtures').expand_path(__dir__)

    def fixture(name)
      ROOT + name
    end
    module_function :fixture
  end
end

module Bacon
  class Context
    include SpecHelper::Fixture

    def temporary_directory
      SpecHelper.temporary_directory
    end
  end
end
