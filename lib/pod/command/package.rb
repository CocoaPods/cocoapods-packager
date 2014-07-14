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

          newspec += 'end'
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

        sandbox = install_pod(platform.name)

        UI.puts 'Building framework'
        xcodebuild
        defines = Symbols.mangle_for_pod_dependencies(@spec.name, config.sandbox_root)
        xcodebuild(defines)

        versions_path, headers_path = create_framework_tree(platform.name.to_s)
        `cp #{sandbox.public_headers.root}/#{@spec.name}/*.h #{headers_path}`

        if platform.name == :ios
          xcodebuild(defines, '-sdk iphonesimulator', 'build-sim')
          `lipo #{config.sandbox_root}/build/libPods.a #{config.sandbox_root}/build-sim/libPods.a -create -output #{versions_path}/#{@spec.name}`
        else
          `cp #{config.sandbox_root}/build/libPods.a #{versions_path}/#{@spec.name}`
        end

        Pathname.new(config.sandbox_root).rmtree
        Pathname.new('Podfile.lock').delete
      end

      def xcodebuild(defines='', args='', build_dir='build')
        `xcodebuild #{defines} CONFIGURATION_BUILD_DIR=#{build_dir} clean build #{args} -project #{config.sandbox_root}/Pods.xcodeproj 2>&1`
      end

      def create_framework_tree(platform)
        root_path = Pathname.new(@spec.name + '-' + platform + '.framework')
        root_path.mkdir unless root_path.exist?

        versions_path = root_path + Pathname.new('Versions/A')

        headers_path = versions_path + Pathname.new('Headers')
        headers_path.mkpath unless headers_path.exist?

        current_version_path = versions_path + Pathname.new('../Current')
        `ln -sf A #{current_version_path}`
        `ln -sf Versions/Current/Headers #{root_path}/`
        `ln -sf Versions/Current/#{@spec.name} #{root_path}/`

        return versions_path, headers_path
      end

      def spec_metadata
        return <<SPEC
Pod::Spec.new do |s|
  s.name          = "#{@spec.name}"
  s.version       = "#{@spec.version}"
  s.summary       = "#{@spec.summary}"
  s.license       = #{@spec.license}
  s.authors       = #{@spec.authors}
  s.homepage      = "#{@spec.homepage}"
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

        return sandbox
      end
    end
  end
end
