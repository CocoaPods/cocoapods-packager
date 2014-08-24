module Pod
  class Command
    class Package < Command
      :private

      def install_pod(platform_name)
        podfile = podfile_from_spec(
          File.basename(@path),
          @spec.name,
          platform_name,
          @spec.deployment_target(platform_name))

        sandbox = Sandbox.new(config.sandbox_root)
        installer = Installer.new(sandbox, podfile)
        installer.install!

        sandbox
      end

      def podfile_from_spec(path, spec_name, platform_name, deployment_target)
        Pod::Podfile.new do
          platform(platform_name, deployment_target)
          if path
            pod spec_name, :podspec => path
          else
            pod spec_name, :path => '.'
          end
        end
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

        if !['.podspec', '.json'].include? Pathname.new(path).extname 
          help! path + ': is not a podspec.'
          return
        end

        Specification.from_file(path)
      end
    end
  end
end
