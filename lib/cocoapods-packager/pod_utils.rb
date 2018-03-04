module Pod
  class Command
    class Package < Command
      private

      def build_static_sandbox(dynamic)
        static_sandbox_root = if dynamic
                                Pathname.new(config.sandbox_root + '/Static')
                              else
                                Pathname.new(config.sandbox_root)
                              end
        Sandbox.new(static_sandbox_root)
      end

      def install_pod(platform_name, sandbox)
        podfile = podfile_from_spec(
          @path.to_s,
          @spec.name,
          platform_name,
          @spec.deployment_target(platform_name),
          @subspecs,
          @spec_sources
        )

        static_installer = Installer.new(sandbox, podfile)
        static_installer.install!

        unless static_installer.nil?
          static_installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
              config.build_settings['CLANG_MODULES_AUTOLINK'] = 'NO'
              config.build_settings['GCC_GENERATE_DEBUGGING_SYMBOLS'] = 'NO'
            end
          end
          static_installer.pods_project.save
        end

        static_installer
      end

      def podfile_from_spec(path, spec_name, platform_name, deployment_target, subspecs, sources)
        options = {}
        if path && @local
          options[:path] = path
        elsif path
          options[:podspec] = path
        end
        options[:subspecs] = subspecs if subspecs
        Pod::Podfile.new do
          sources.each { |s| source s }
          platform(platform_name, deployment_target)
          pod(spec_name, options)

          install!('cocoapods',
                   :integrate_targets => false,
                   :deterministic_uuids => false)

          target('packager') do
            inherit! :complete
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

        set = Pod::Config.instance.sources_manager.search(Dependency.new(name))
        return nil if set.nil?

        set.specification.root
      end

      def spec_with_path(path)
        return if path.nil? || !Pathname.new(path).exist?

        @path = Pathname.new(path).expand_path

        if @path.directory?
          help! @path + ': is a directory.'
          return
        end

        unless ['.podspec', '.json'].include? @path.extname
          help! @path + ': is not a podspec.'
          return
        end

        Specification.from_file(@path)
      end

      #----------------------
      # Dynamic Project Setup
      #----------------------

      def build_dynamic_sandbox(_static_sandbox, _static_installer)
        dynamic_sandbox_root = Pathname.new(config.sandbox_root + '/Dynamic')
        dynamic_sandbox = Sandbox.new(dynamic_sandbox_root)

        dynamic_sandbox
      end

      def install_dynamic_pod(dynamic_sandbox, static_sandbox, static_installer)
        # 1 Create a dynamic target for only the spec pod.
        dynamic_target = build_dynamic_target(dynamic_sandbox, static_installer)

        # 2. Build a new xcodeproj in the dynamic_sandbox with only the spec pod as a target.
        project = prepare_pods_project(dynamic_sandbox, dynamic_target.name, static_installer)

        # 3. Copy the source directory for the dynamic framework from the static sandbox.
        copy_dynamic_target(static_sandbox, dynamic_target, dynamic_sandbox)

        # 5. Update the file accecssors.
        dynamic_target = update_file_accessors(dynamic_target, dynamic_sandbox)

        # 6. Create the file references.
        install_file_references(dynamic_sandbox, [dynamic_target], project)

        # 7. Install the target.
        install_library(dynamic_sandbox, dynamic_target)

        # 9. Write the actual Xcodeproject to the dynamic sandbox.
        write_pod_project(project, dynamic_sandbox)
      end

      def build_dynamic_target(dynamic_sandbox, static_installer)
        spec_targets = static_installer.pod_targets.select do |target|
          target.name == @spec.name
        end
        static_target = spec_targets[0]

        dynamic_target = Pod::PodTarget.new(static_target.specs, static_target.target_definitions, dynamic_sandbox)
        dynamic_target.host_requires_frameworks = true
        dynamic_target.user_build_configurations = static_target.user_build_configurations
        dynamic_target
      end

      def prepare_pods_project(dynamic_sandbox, spec_name, installer)
        # Create a new pods project
        pods_project = Pod::Project.new(dynamic_sandbox.project_path)

        # Update build configurations
        installer.analysis_result.all_user_build_configurations.each do |name, type|
          pods_project.add_build_configuration(name, type)
        end

        # Add the pod group for only the dynamic framework
        local = dynamic_sandbox.local?(spec_name)
        path = dynamic_sandbox.pod_dir(spec_name)
        was_absolute = dynamic_sandbox.local_path_was_absolute?(spec_name)
        pods_project.add_pod_group(spec_name, path, local, was_absolute)

        dynamic_sandbox.project = pods_project
        pods_project
      end

      def copy_dynamic_target(static_sandbox, _dynamic_target, dynamic_sandbox)
        command = "cp -a #{static_sandbox.root}/#{@spec.name} #{dynamic_sandbox.root}"
        `#{command}`
      end

      def update_file_accessors(dynamic_target, dynamic_sandbox)
        pod_root = dynamic_sandbox.pod_dir(dynamic_target.root_spec.name)

        path_list = Sandbox::PathList.new(pod_root)
        file_accessors = dynamic_target.specs.map do |spec|
          Sandbox::FileAccessor.new(path_list, spec.consumer(dynamic_target.platform))
        end

        dynamic_target.file_accessors = file_accessors
        dynamic_target
      end

      def install_file_references(dynamic_sandbox, pod_targets, pods_project)
        installer = Pod::Installer::Xcode::PodsProjectGenerator::FileReferencesInstaller.new(dynamic_sandbox, pod_targets, pods_project)
        installer.install!
      end

      def install_library(dynamic_sandbox, dynamic_target)
        return if dynamic_target.target_definitions.flat_map(&:dependencies).empty?
        target_installer = Pod::Installer::Xcode::PodsProjectGenerator::PodTargetInstaller.new(dynamic_sandbox, dynamic_target)
        target_installer.install!

        # Installs System Frameworks
        dynamic_target.file_accessors.each do |file_accessor|
          file_accessor.spec_consumer.frameworks.each do |framework|
            if dynamic_target.should_build?
              dynamic_target.native_target.add_system_framework(framework)
            end
          end

          file_accessor.spec_consumer.libraries.each do |library|
            if dynamic_target.should_build?
              dynamic_target.native_target.add_system_library(library)
            end
          end
        end
      end

      def write_pod_project(dynamic_project, dynamic_sandbox)
        UI.message "- Writing Xcode project file to #{UI.path dynamic_sandbox.project_path}" do
          dynamic_project.pods.remove_from_project if dynamic_project.pods.empty?
          dynamic_project.development_pods.remove_from_project if dynamic_project.development_pods.empty?
          dynamic_project.sort(:groups_position => :below)
          dynamic_project.recreate_user_schemes(false)

          # Edit search paths so that we can find our dependency headers
          dynamic_project.targets.first.build_configuration_list.build_configurations.each do |config|
            config.build_settings['HEADER_SEARCH_PATHS'] = "$(inherited) #{Dir.pwd}/Pods/Static/Headers/**"
            config.build_settings['USER_HEADER_SEARCH_PATHS'] = "$(inherited) #{Dir.pwd}/Pods/Static/Headers/**"
            config.build_settings['OTHER_LDFLAGS'] = '$(inherited) -ObjC'
          end
          dynamic_project.save
        end
      end
    end
  end
end
