require 'tmpdir'
module Pod
  class Command
    class Package < Command
      self.summary = 'Package a podspec into a static library.'
      self.arguments = [
        CLAide::Argument.new('NAME', true),
        CLAide::Argument.new('SOURCE', false)
      ]

      def self.options
        [
          ['--force',     'Overwrite existing files.'],
          ['--no-mangle', 'Do not mangle symbols of depedendant Pods.'],
          ['--embedded',  'Generate embedded frameworks.'],
          ['--library',   'Generate static libraries.'],
          ['--dynamic',   'Generate dynamic framework.'],
          ['--bundle-identifier', 'Bundle identifier for dynamic framework'],
          ['--exclude-deps', 'Exclude symbols from dependencies.'],
          ['--configuration', 'Build the specified configuration (e.g. Debug). Defaults to Release'],
          ['--subspecs', 'Only include the given subspecs'],
          ['--spec-sources=private,https://github.com/CocoaPods/Specs.git', 'The sources to pull dependant ' \
            'pods from (defaults to https://github.com/CocoaPods/Specs.git)']
        ]
      end

      def initialize(argv)
        @embedded = argv.flag?('embedded')
        @force = argv.flag?('force')
        @library = argv.flag?('library')
        @dynamic = argv.flag?('dynamic')
        @mangle = argv.flag?('mangle', true)
        @bundle_identifier = argv.option('bundle-identifier', nil)
        @exclude_deps = argv.flag?('exclude-deps', false)
        @name = argv.shift_argument
        @source = argv.shift_argument
        @spec_sources = argv.option('spec-sources', 'https://github.com/CocoaPods/Specs.git').split(',')

        subspecs = argv.option('subspecs')
        @subspecs = subspecs.split(',') unless subspecs.nil?

        @config = argv.option('configuration', 'Release')

        @source_dir = Dir.pwd
        @spec = spec_with_path(@name)
        @spec = spec_with_name(@name) unless @spec
        super
      end

      def validate!
        super
        help! 'A podspec name or path is required.' unless @spec
        help! 'podspec has binary-only depedencies, mangling not possible.' if @mangle && binary_only?(@spec)
        help! '--bundle-identifier option can only be used for dynamic frameworks' if @bundle_identifier && !@dynamic
        help! '--exclude-deps option can only be used for static libraries' if @exclude_deps && @dynamic
      end

      def run
        if @path.nil? || @spec.nil?
          help! 'Unable to find a podspec with path or name.'
          return
        end

        target_dir, work_dir = create_working_directory
        return if target_dir.nil?
        build_package

        `mv "#{work_dir}" "#{target_dir}"`
        Dir.chdir(@source_dir)
      end

      private

      def build_in_sandbox(platform)
        config.installation_root  = Pathname.new(Dir.pwd)
        config.sandbox_root       = 'Pods'

        static_sandbox = build_static_sandbox(@dynamic)
        static_installer = install_pod(platform.name, static_sandbox)

        if @dynamic
          dynamic_sandbox = build_dynamic_sandbox(static_sandbox, static_installer)
          install_dynamic_pod(dynamic_sandbox, static_sandbox, static_installer)
        end

        begin
          perform_build(platform, static_sandbox, dynamic_sandbox)

        ensure # in case the build fails; see Builder#xcodebuild.
          Pathname.new(config.sandbox_root).rmtree
          FileUtils.rm_f('Podfile.lock')
        end
      end

      def build_package
        builder = SpecBuilder.new(@spec, @source, @embedded, @dynamic)
        newspec = builder.spec_metadata

        @spec.available_platforms.each do |platform|
          build_in_sandbox(platform)

          newspec += builder.spec_platform(platform)
        end

        newspec += builder.spec_close
        File.open(@spec.name + '.podspec', 'w') { |file| file.write(newspec) }
      end

      def create_target_directory
        target_dir = "#{@source_dir}/#{@spec.name}-#{@spec.version}"
        if File.exist? target_dir
          if @force
            Pathname.new(target_dir).rmtree
          else
            UI.puts "Target directory '#{target_dir}' already exists."
            return nil
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

      def perform_build(platform, static_sandbox, dynamic_sandbox)
        static_sandbox_root = config.sandbox_root.to_s

        if @dynamic
          static_sandbox_root = "#{static_sandbox_root}/#{static_sandbox.root.to_s.split('/').last}"
          dynamic_sandbox_root = "#{config.sandbox_root}/#{dynamic_sandbox.root.to_s.split('/').last}"
        end

        builder = Pod::Builder.new(
          @source_dir,
          static_sandbox_root,
          dynamic_sandbox_root,
          static_sandbox.public_headers.root,
          @spec,
          @embedded,
          @mangle,
          @dynamic,
          @config,
          @bundle_identifier,
          @exclude_deps
        )

        builder.build(platform, @library)

        return unless @embedded
        builder.link_embedded_resources
      end
    end
  end
end
