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
          build_in_sandbox
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
          @path = path
          Specification.from_file(path)
        end
      end

      def build_in_sandbox
        config.sandbox_root = 'Pods'
        config.integrate_targets = false
        config.skip_repo_update  = true

        # TODO: Obviously, this should not be iOS-specific

        install_pod(:ios)

        `xcodebuild CONFIGURATION_BUILD_DIR=build clean build -project Pods/Pods.xcodeproj 2>&1`
        `xcodebuild CONFIGURATION_BUILD_DIR=build-sim clean build -sdk iphonesimulator -project Pods/Pods.xcodeproj 2>&1`

        `lipo Pods/build/libPods.a Pods/build-sim/libPods.a -create -output lib#{@spec.name}.a`

        Pathname.new('Pods').rmtree
        Pathname.new('Podfile.lock').delete
      end

      def podfile_from_spec(platform_name, deployment_target)
        name     = @spec.name
        path     = @path
        podfile  = Pod::Podfile.new do
          platform(platform_name, deployment_target)
          if (path)
            pod name, :podspec => path
          else
            pod name, :path => '.'
          end
        end
        podfile
      end

      def install_pod(platform_name)
        podfile = podfile_from_spec(platform_name, @spec.deployment_target(platform_name))
        sandbox = Sandbox.new(config.sandbox_root)
        installer = Installer.new(sandbox, podfile)
        installer.install!
      end
    end
  end
end
