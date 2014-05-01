module Pod
  class Command
    class Package < Command
      self.summary = 'Package a podspec into a static library.'
      self.arguments = '[ NAME | NAME.podspec ]'

      def initialize(argv)
        @name = argv.shift_argument
        @spec = spec_with_path(@name)
        @spec = spec_with_name(@name) unless @spec
        super
      end

      def validate!
        super
        help! "A podspec name or path is required." unless @spec
      end

      def run
        if @spec
          # TODO perform the magic!
        else
          help! "Unable to find a podspec with path or name."
        end
      end

      def spec_with_name(name)
        set = SourcesManager.search(Dependency.new(name))

        if set
          set.specification.root
        end
      end

      def spec_with_path(path)
        if Pathname.new(path).exist?
          Specification.from_file(path)
        end
      end
    end
  end
end
