require 'tmpdir'

module Pod
  class Command
    class Package < Command
      self.summary = 'Package a podspec into a static library.'
      self.arguments = [['NAME', :required], ['SOURCE']]

      def self.options
        [
          ['--force',     'Overwrite existing files.'],
          ['--no-mangle', 'Do not mangle symbols of depedendant Pods.'],
          ['--embedded',  'Generate embedded frameworks.']
        ]
      end

      def initialize(argv)
        @embedded = argv.flag?('embedded')
        @force = argv.flag?('force')
        @mangle = argv.flag?('mangle', true)
        @name = argv.shift_argument
        @source = argv.shift_argument

        @source_dir = Dir.pwd
        @spec = spec_with_path(@name)
        @spec = spec_with_name(@name) unless @spec
        super
      end

      def validate!
        super
        help! 'A podspec name or path is required.' unless @spec
      end

      def run
        if @spec.nil?
          help! 'Unable to find a podspec with path or name.'
          return
        end

        target_dir, work_dir = create_working_directory
        return if target_dir.nil?
        build_package
        `mv #{work_dir} #{target_dir}`
      end

      :private

      def build_package
        builder = SpecBuilder.new(@spec, @source)
        newspec = builder.spec_metadata

        @spec.available_platforms.each do |platform|
          build_in_sandbox(platform)

          newspec += builder.spec_platform(platform)
        end

        newspec += builder.spec_close
        File.open(@spec.name + '.podspec', 'w') { |file| file.write(newspec) }
      end

      def create_framework(platform)
        fwk = Framework::Tree.new(@spec.name, platform, @embedded)
        fwk.make
        [fwk.root_path, fwk.versions_path, fwk.headers_path, fwk.resources_path]
      end

      def create_target_directory
        target_dir = "#{@source_dir}/#{@spec.name}-#{@spec.version}"
        if File.exist? target_dir
          if @force
            Pathname.new(target_dir).rmtree
          else
            UI.puts "Target directory '#{target_dir}' already exists."
            nil
          end
        end
        target_dir
      end

      def create_working_directory
        target_dir = create_target_directory
        return if target_dir.nil?

        work_dir = Dir.tmpdir + '/cocoapods-' + Array.new(8) { rand(36).to_s(36) }.join
        Pathname.new(work_dir).mkdir
        `cp #{@path} #{work_dir}`
        Dir.chdir(work_dir)

        [target_dir, work_dir]
      end

      def spec_with_name(name)
        return if name.nil?

        set = SourcesManager.search(Dependency.new(name))
        return nil if set.nil?

        set.specification.root
      end

      def spec_with_path(path)
        return if path.nil? || !Pathname.new(path).exist?

        @path = path
        Specification.from_file(path)
      end

      def build_in_sandbox(platform)
        config.sandbox_root       = 'Pods'
        config.integrate_targets  = false
        config.skip_repo_update   = true

        sandbox = install_pod(platform.name)

        UI.puts 'Building framework'

        if @spec.dependencies.count > 0 && @mangle
          xcodebuild
          UI.puts 'Mangling symbols'
          defines = Symbols.mangle_for_pod_dependencies(@spec.name, config.sandbox_root)
          UI.puts 'Building mangled framework'
          xcodebuild(defines)
        else
          xcodebuild
        end

        root_path, versions_path, headers_path, resources_path = create_framework(platform.name.to_s)
        headers_source_root = "#{sandbox.public_headers.root}/#{@spec.name}"
        Dir.glob("#{headers_source_root}/**/*.h").
          each { |h| `ditto #{h} #{headers_path}/#{h.sub(headers_source_root, '')}` }
        `cp -rp #{config.sandbox_root}/build/*.bundle #{resources_path} 2>&1`

        static_libs = Dir.glob("#{config.sandbox_root}/build/*.a").reject { |e| e =~ /libPods\.a$/ }

        if platform.name == :ios
          `libtool -static -o #{config.sandbox_root}/build/package.a #{static_libs.join(' ')}`

          xcodebuild(defines, '-sdk iphonesimulator', 'build-sim')
          sim_libs = static_libs.map { |path| "#{config.sandbox_root}/build-sim/#{File.basename(path)}" }
          `libtool -static -o #{config.sandbox_root}/build-sim/package.a #{sim_libs.join(' ')}`

          `lipo #{config.sandbox_root}/build/package.a #{config.sandbox_root}/build-sim/libPods.a -create -output #{versions_path}/#{@spec.name}`
        else
          `libtool -static -o #{versions_path}/#{@spec.name} #{static_libs.join(' ')}`
        end

        resources = expand_paths(@spec.consumer(platform).resources)
        if resources.count > 0
          `cp -rp #{resources.join(' ')} #{resources_path}`
        end

        if @embedded
          target_path = root_path + Pathname.new('Resources')
          target_path.mkdir unless target_path.exist?

          Dir.glob(resources_path.to_s + '/*').each do |resource|
            resource = Pathname.new(resource).relative_path_from(target_path)
            `ln -sf #{resource} #{target_path}`
          end
        end

        license_file = @spec.license[:file]
        license_file = 'LICENSE' unless license_file
        `cp "#{config.sandbox_root}/#{@spec.name}/#{license_file}" .`

        Pathname.new(config.sandbox_root).rmtree
        Pathname.new('Podfile.lock').delete
      end

      def expand_paths(path_specs)
        paths = []

        path_specs.each do |path_spec|
          paths += Dir.glob(File.join(@source_dir, path_spec))
        end

        paths
      end

      def xcodebuild(defines = '', args = '', build_dir = 'build')
        `xcodebuild #{defines} CONFIGURATION_BUILD_DIR=#{build_dir} clean build #{args} -configuration Release -target Pods -project #{config.sandbox_root}/Pods.xcodeproj 2>&1`
      end

      def podfile_from_spec(platform_name, deployment_target)
        name     = @spec.name
        path     = @path
        Pod::Podfile.new do
          platform(platform_name, deployment_target)
          if path
            pod name, :podspec => path
          else
            pod name, :path => '.'
          end
        end
      end

      def install_pod(platform_name)
        podfile = podfile_from_spec(platform_name, @spec.deployment_target(platform_name))
        sandbox = Sandbox.new(config.sandbox_root)
        installer = Installer.new(sandbox, podfile)
        installer.install!

        sandbox
      end
    end
  end
end
