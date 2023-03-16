module Pod
  class Builder
    def initialize(platform, static_installer, source_dir, static_sandbox_root, dynamic_sandbox_root, public_headers_root, spec, embedded, mangle, dynamic, config, bundle_identifier, exclude_deps)
      @platform = platform
      @static_installer = static_installer
      @source_dir = source_dir
      @static_sandbox_root = static_sandbox_root
      @dynamic_sandbox_root = dynamic_sandbox_root
      @public_headers_root = public_headers_root
      @spec = spec
      @embedded = embedded
      @mangle = mangle
      @dynamic = dynamic
      @config = config
      @bundle_identifier = bundle_identifier
      @exclude_deps = exclude_deps

      @file_accessors = @static_installer.pod_targets.select { |t| t.pod_name == @spec.name }.flat_map(&:file_accessors)
    end

    def build(package_type)
      case package_type
      when :static_library
        build_static_library
      when :static_framework
        build_static_framework
      when :dynamic_framework
        build_dynamic_framework
      end
    end

    def build_static_library
      UI.puts("Building static library #{@spec} with configuration #{@config}")

      defines = compile
      build_sim_libraries(defines)

      platform_path = Pathname.new(@platform.name.to_s)
      platform_path.mkdir unless platform_path.exist?

      output = platform_path + "lib#{@spec.name}.a"

      if @platform.name == :ios
        build_static_library_for_ios(output)
      else
        build_static_library_for_mac(output)
      end
    end

    def build_static_framework
      UI.puts("Building static framework #{@spec} with configuration #{@config}")

      defines = compile
      build_sim_libraries(defines)

      create_framework
      output = @fwk.versions_path + Pathname.new(@spec.name)

      if @platform.name == :ios
        build_static_library_for_ios(output)
      else
        build_static_library_for_mac(output)
      end

      copy_headers
      copy_license
      copy_resources
    end

    def link_embedded_resources
      target_path = @fwk.root_path + Pathname.new('Resources')
      target_path.mkdir unless target_path.exist?

      Dir.glob(@fwk.resources_path.to_s + '/*').each do |resource|
        resource = Pathname.new(resource).relative_path_from(target_path)
        `ln -sf #{resource} #{target_path}`
      end
    end

    def build_dynamic_framework
      UI.puts("Building dynamic framework #{@spec} with configuration #{@config}")

      defines = compile
      build_sim_libraries(defines)

      if @bundle_identifier
        defines = "#{defines} PRODUCT_BUNDLE_IDENTIFIER='#{@bundle_identifier}'"
      end

      output = "#{@dynamic_sandbox_root}/build/#{@spec.name}.framework/#{@spec.name}"

      clean_directory_for_dynamic_build
      if @platform.name == :ios
        build_dynamic_framework_for_ios(defines, output)
      else
        build_dynamic_framework_for_mac(defines, output)
      end

      copy_resources
    end

    def build_dynamic_framework_for_ios(defines, output)
      # Specify frameworks to link and search paths
      linker_flags = static_linker_flags_in_sandbox
      defines = "#{defines} OTHER_LDFLAGS='$(inherited) #{linker_flags.join(' ')}'"

      # Build Target Dynamic Framework for both device and Simulator
      device_defines = "#{defines} LIBRARY_SEARCH_PATHS=\"#{Dir.pwd}/#{@static_sandbox_root}/build\""
      device_options = ios_build_options << ' -sdk iphoneos'
      xcodebuild(device_defines, device_options, 'build', @spec.name.to_s, @dynamic_sandbox_root.to_s)

      sim_defines = "#{defines} LIBRARY_SEARCH_PATHS=\"#{Dir.pwd}/#{@static_sandbox_root}/build-sim\" ONLY_ACTIVE_ARCH=NO"
      xcodebuild(sim_defines, '-sdk iphonesimulator', 'build-sim', @spec.name.to_s, @dynamic_sandbox_root.to_s)

      # Combine architectures
      `lipo #{@dynamic_sandbox_root}/build/#{@spec.name}.framework/#{@spec.name} #{@dynamic_sandbox_root}/build-sim/#{@spec.name}.framework/#{@spec.name} -create -output #{output}`

      FileUtils.mkdir(@platform.name.to_s)
      `mv #{@dynamic_sandbox_root}/build/#{@spec.name}.framework #{@platform.name}`
      `mv #{@dynamic_sandbox_root}/build/#{@spec.name}.framework.dSYM #{@platform.name}`
    end

    def build_dynamic_framework_for_mac(defines, _output)
      # Specify frameworks to link and search paths
      linker_flags = static_linker_flags_in_sandbox
      defines = "#{defines} OTHER_LDFLAGS=\"#{linker_flags.join(' ')}\""

      # Build Target Dynamic Framework for osx
      defines = "#{defines} LIBRARY_SEARCH_PATHS=\"#{Dir.pwd}/#{@static_sandbox_root}/build\""
      xcodebuild(defines, nil, 'build', @spec.name.to_s, @dynamic_sandbox_root.to_s)

      FileUtils.mkdir(@platform.name.to_s)
      `mv #{@dynamic_sandbox_root}/build/#{@spec.name}.framework #{@platform.name}`
      `mv #{@dynamic_sandbox_root}/build/#{@spec.name}.framework.dSYM #{@platform.name}`
    end

    def build_sim_libraries(defines)
      if @platform.name == :ios
        xcodebuild(defines, '-sdk iphonesimulator', 'build-sim')
      end
    end

    def build_static_library_for_ios(output)
      static_libs = static_libs_in_sandbox('build') + static_libs_in_sandbox('build-sim') + vendored_libraries
      libs = ios_architectures.map do |arch|
        library = "#{@static_sandbox_root}/build/package-#{arch}.a"
        `libtool -arch_only #{arch} -static -o #{library} #{static_libs.join(' ')}`
        library
      end

      `lipo -create -output #{output} #{libs.join(' ')}`
    end

    def build_static_library_for_mac(output)
      static_libs = static_libs_in_sandbox + vendored_libraries
      `libtool -static -o #{output} #{static_libs.join(' ')}`
    end

    def build_with_mangling(options)
      UI.puts 'Mangling symbols'
      defines = Symbols.mangle_for_pod_dependencies(@spec.name, @static_sandbox_root)
      defines << ' ' << @spec.consumer(@platform).compiler_flags.join(' ')

      UI.puts 'Building mangled framework'
      xcodebuild(defines, options)
      defines
    end

    def clean_directory_for_dynamic_build
      # Remove static headers to avoid duplicate declaration conflicts
      FileUtils.rm_rf("#{@static_sandbox_root}/Headers/Public/#{@spec.name}")
      FileUtils.rm_rf("#{@static_sandbox_root}/Headers/Private/#{@spec.name}")

      # Equivalent to removing derrived data
      FileUtils.rm_rf('Pods/build')
    end

    def compile
      defines = "GCC_PREPROCESSOR_DEFINITIONS='$(inherited) PodsDummy_Pods_#{@spec.name}=PodsDummy_PodPackage_#{@spec.name}'"
      defines << ' ' << @spec.consumer(@platform).compiler_flags.join(' ')

      if @platform.name == :ios
        options = ios_build_options
      end

      xcodebuild(defines, options)

      if @mangle
        return build_with_mangling(options)
      end

      defines
    end

    def copy_headers
      headers_source_root = "#{@public_headers_root}/#{@spec.name}"

      Dir.glob("#{headers_source_root}/**/*.h").
        each { |h| `ditto #{h} #{@fwk.headers_path}/#{h.sub(headers_source_root, '')}` }

      # If custom 'module_map' is specified add it to the framework distribution
      # otherwise check if a header exists that is equal to 'spec.name', if so
      # create a default 'module_map' one using it.
      if !@spec.module_map.nil?
        module_map_file = @file_accessors.flat_map(&:module_map).first
        module_map = File.read(module_map_file) if Pathname(module_map_file).exist?
      elsif File.exist?("#{@public_headers_root}/#{@spec.name}/#{@spec.name}.h")
        module_map = <<MAP
framework module #{@spec.name} {
  umbrella header "#{@spec.name}.h"

  export *
  module * { export * }
}
MAP
      end

      unless module_map.nil?
        @fwk.module_map_path.mkpath unless @fwk.module_map_path.exist?
        File.write("#{@fwk.module_map_path}/module.modulemap", module_map)
      end
    end

    def copy_license
      license_file = @spec.license[:file] || 'LICENSE'
      license_file = Pathname.new("#{@static_sandbox_root}/#{@spec.name}/#{license_file}")
      FileUtils.cp(license_file, '.') if license_file.exist?
    end

    def copy_resources
      bundles = Dir.glob("#{@static_sandbox_root}/build/*.bundle")
      if @dynamic
        resources_path = "ios/#{@spec.name}.framework"
        `cp -rp #{@static_sandbox_root}/build/*.bundle #{resources_path} 2>&1`
      else
        `cp -rp #{@static_sandbox_root}/build/*.bundle #{@fwk.resources_path} 2>&1`
        resources = expand_paths(@spec.consumer(@platform).resources)
        if resources.count == 0 && bundles.count == 0
          @fwk.delete_resources
          return
        end
        if resources.count > 0
          `cp -rp #{resources.join(' ')} #{@fwk.resources_path}`
        end
      end
    end

    def create_framework
      @fwk = Framework::Tree.new(@spec.name, @platform.name.to_s, @embedded)
      @fwk.make
    end

    def dependency_count
      count = @spec.dependencies.count

      @spec.subspecs.each do |subspec|
        count += subspec.dependencies.count
      end

      count
    end

    def expand_paths(path_specs)
      path_specs.map do |path_spec|
        Dir.glob(File.join(@source_dir, path_spec))
      end
    end

    def static_libs_in_sandbox(build_dir = 'build')
      if @exclude_deps
        UI.puts 'Excluding dependencies'
        Dir.glob("#{@static_sandbox_root}/#{build_dir}/lib#{@spec.name}.a")
      else
        Dir.glob("#{@static_sandbox_root}/#{build_dir}/lib*.a")
      end
    end

    def vendored_libraries
      if @vendored_libraries
        @vendored_libraries
      end
      file_accessors = if @exclude_deps
                         @file_accessors
                       else
                         @static_installer.pod_targets.flat_map(&:file_accessors)
                       end
      libs = file_accessors.flat_map(&:vendored_static_frameworks).map { |f| f + f.basename('.*') } || []
      libs += file_accessors.flat_map(&:vendored_static_libraries)
      @vendored_libraries = libs.compact.map(&:to_s)
      @vendored_libraries
    end

    def static_linker_flags_in_sandbox
      linker_flags = static_libs_in_sandbox.map do |lib|
        lib.slice!('lib')
        lib_flag = lib.chomp('.a').split('/').last
        "-l#{lib_flag}"
      end
      linker_flags.reject { |e| e == "-l#{@spec.name}" || e == '-lPods-packager' }
    end

    def ios_build_options
      "ARCHS=\'$(ARCHS_STANDARD)\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'"
    end

    def ios_architectures
      archs = %w(x86_64 i386 arm64 armv7 armv7s)
      vendored_libraries.each do |library|
        archs = `lipo -info #{library}`.split & archs
      end
      archs
    end

    def xcodebuild(defines = '', args = '', build_dir = 'build', target = 'Pods-packager', project_root = @static_sandbox_root, config = @config)
      if defined?(Pod::DONT_CODESIGN)
        args = "#{args} CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO"
      end

      command = "xcodebuild #{defines} #{args} CONFIGURATION_BUILD_DIR=#{build_dir} clean build -configuration #{config} -target #{target} -project #{project_root}/Pods.xcodeproj 2>&1"
      output = `#{command}`.lines.to_a

      if $?.exitstatus != 0
        puts UI::BuildFailedReport.report(command, output)

        # Note: We use `Process.exit` here because it fires a `SystemExit`
        # exception, which gives the caller a chance to clean up before the
        # process terminates.
        #
        # See http://ruby-doc.org/core-1.9.3/Process.html#method-c-exit
        Process.exit
      end
    end
  end
end
