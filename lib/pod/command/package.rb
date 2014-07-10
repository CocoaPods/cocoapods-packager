module Pod
  class Command
    class Package < Command
      self.summary = 'Package a podspec into a static library.'
      self.arguments = [['NAME', :required]]

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
          newspec = spec_metadata

          @spec.available_platforms.each do |platform|
            build_in_sandbox(platform)

            fwk_base = @spec.name + '-' + platform.name.to_s + '.framework'
            newspec += <<SPEC
  s.#{platform.name}.platform             = :#{platform.symbolic_name}, '#{platform.deployment_target}'
  s.#{platform.name}.preserve_paths       = '#{fwk_base}'
  s.#{platform.name}.public_header_files  = '#{fwk_base}/Versions/A/Headers/*.h'
  #s.#{platform.name}.resource            = '#{fwk_base}/Versions/A/Resources/#{fwk_base}.bundle'
  s.#{platform.name}.vendored_frameworks  = '#{fwk_base}'

SPEC
          end

          newspec += 'done'
          File.open(@spec.name + '.podspec', 'w') { |file| file.write(newspec) }
        else
          help! "Unable to find a podspec with path or name."
        end
      end

      def spec_with_name(name)
        return unless not name.nil?

        set = SourcesManager.search(Dependency.new(name))

        if set
          set.specification.root
        end
      end

      def spec_with_path(path)
        if not path.nil? and Pathname.new(path).exist?
          @path = path
          Specification.from_file(path)
        end
      end

      def build_in_sandbox(platform)
        config.sandbox_root       = 'Pods'
        config.integrate_targets  = false
        config.skip_repo_update   = true

        install_pod(platform.name)
        xcodebuild

        if platform.name == :ios
          xcodebuild('-sdk iphonesimulator', 'build-sim')
          Pathname.new('ios').mkdir
          `lipo #{config.sandbox_root}/build/libPods.a #{config.sandbox_root}/build-sim/libPods.a -create -output ios/lib#{@spec.name}.a`
        else
          Pathname.new('osx').mkdir
          `cp #{config.sandbox_root}/build/libPods.a osx/lib#{@spec.name}.a`
        end

        Pathname.new(config.sandbox_root).rmtree
        Pathname.new('Podfile.lock').delete
      end

      def xcodebuild(args='', build_dir='build')
        `xcodebuild CONFIGURATION_BUILD_DIR=#{build_dir} clean build #{args} -project #{config.sandbox_root}/Pods.xcodeproj 2>&1`
      end

      def spec_metadata
        return <<SPEC
Pod::Spec.new do |s|
  s.name          = "#{@spec.name}"
  s.version       = "#{@spec.version}"
  s.summary       = "#{@spec.summary}"
  s.license       = #{@spec.license}
  s.authors       = #{@spec.authors}
  s.source        = #{@spec.source}

SPEC
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
