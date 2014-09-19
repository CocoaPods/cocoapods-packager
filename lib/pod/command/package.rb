require 'tmpdir'

module Pod
  class Command
    class Package < Command
      self.summary = 'Package a podspec into a static library.'
      self.arguments = [
        CLAide::Argument.new('NAME', true),
        CLAide::Argument.new('SOURCE', false),
      ]

      def self.options
        [
          ['--force',     'Overwrite existing files.'],
          ['--no-mangle', 'Do not mangle symbols of depedendant Pods.'],
          ['--embedded',  'Generate embedded frameworks.'],
          ['--library',   'Generate static libraries.'],
          ['--subspecs',  'Only include the given subspecs'],
          ['--spec-sources=private,master', 'The sources to pull dependant ' \
            'pods from (defaults to master)'],
        ]
      end

      def initialize(argv)
        @embedded = argv.flag?('embedded')
        @force = argv.flag?('force')
        @library = argv.flag?('library')
        @mangle = argv.flag?('mangle', true)
        @name = argv.shift_argument
        @source = argv.shift_argument
        @spec_sources = argv.option('spec-sources', 'master').split(',')

        subspecs = argv.option('subspecs')
        @subspecs = subspecs.split(',') unless subspecs.nil?

        @source_dir = Dir.pwd
        @spec = spec_with_path(@name)
        @spec = spec_with_name(@name) unless @spec
        super
      end

      def validate!
        super
        help! 'A podspec name or path is required.' unless @spec
        help! 'podspec has binary-only depedencies, mangling not possible.' if binary_only? @spec
      end

      def run
        if @path.nil? || @spec.nil?
          help! 'Unable to find a podspec with path or name.'
          return
        end

        target_dir, work_dir = create_working_directory
        return if target_dir.nil?
        build_package
        `mv #{work_dir} #{target_dir}`
        Dir.chdir(@source_dir)
      end

      :private

      def build_in_sandbox(platform)
        config.sandbox_root       = 'Pods'
        config.integrate_targets  = false
        config.skip_repo_update   = true

        sandbox = install_pod(platform.name)

        perform_build(platform, sandbox)

        Pathname.new(config.sandbox_root).rmtree
        FileUtils.rm_f('Podfile.lock')
      end

      def build_package
        builder = SpecBuilder.new(@spec, @source, @embedded)
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

      def perform_build(platform, sandbox)
        builder = Pod::Builder.new(
          @source_dir,
          config.sandbox_root,
          sandbox.public_headers.root,
          @spec,
          @embedded,
          @mangle)

        builder.build(platform, @library)

        return unless @embedded
        builder.link_embedded_resources
      end
    end
  end
end
