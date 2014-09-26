module Pod
  class Command
    class Package < Command
      :private

      def install_pod(platform_name)
        podfile = podfile_from_spec(
          File.basename(@path),
          @spec.name,
          platform_name,
          @spec.deployment_target(platform_name),
          @subspecs,
          @spec_sources,
        )

        sandbox = Sandbox.new(config.sandbox_root)
        installer = Installer.new(sandbox, podfile)
        installer.install!

        sandbox
      end

      def podfile_from_spec(path, spec_name, platform_name, deployment_target, subspecs, sources)
        Pod::Podfile.new do
          sources.each { |s| source s }
          platform(platform_name, deployment_target)
          if path
            if subspecs
              subspecs.each do |subspec|
                pod spec_name + '/' + subspec, :podspec => path
              end
            else
              pod spec_name, :podspec => path
            end
          else
            if subspecs
              subspecs.each do |subspec|
                pod spec_name + '/' + subspec, :path => '.'
              end
            else
              pod spec_name, :path => '.'
            end
          end
        end
      end

      def binary_only?(spec)
        deps = spec.dependencies.map { |dep| spec_with_name(dep.name) }

        [spec, *deps].each do |specification|
          %w(vendored_frameworks vendored_libraries).each do |attrib|
            if specification.attributes_hash[attrib]
              return true
            end
          end
        end

        false
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

        if Pathname.new(path).directory?
          help! path + ': is a directory.'
          return
        end

        unless ['.podspec', '.json'].include? Pathname.new(path).extname
          help! path + ': is not a podspec.'
          return
        end

        Specification.from_file(path)
      end
    end
  end
end
