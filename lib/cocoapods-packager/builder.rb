module Pod
  class Builder
    def initialize(source_dir, static_sandbox_root, dynamic_sandbox_root, public_headers_root, spec, embedded, mangle, dynamic, config)
      @source_dir = source_dir
      @static_sandbox_root = static_sandbox_root
      @dynamic_sandbox_root = dynamic_sandbox_root
      @public_headers_root = public_headers_root
      @spec = spec
      @embedded = embedded
      @mangle = mangle
      @dynamic = dynamic
      @config = config
    end

    def build(platform, library)
      if library
        build_static_library(platform)
      else
        build_framework(platform)
      end
    end

    def build_static_library(platform)
      UI.puts("Building static library #{@spec} with configuration #{@config}")

      defines = compile(platform)
      build_sim_libraries(platform, defines)

      platform_path = Pathname.new(platform.name.to_s)
      platform_path.mkdir unless platform_path.exist?
      build_library(platform, defines, platform_path + Pathname.new("lib#{@spec.name}.a"))
    end

    def build_framework(platform)
      UI.puts("Building framework #{@spec} with configuration #{@config}")

      defines = compile(platform)
      build_sim_libraries(platform, defines)

      if @dynamic
        build_dynamic_framework(platform, defines, "#{@dynamic_sandbox_root}/build/#{@spec.name}.framework/#{@spec.name}")
        copy_resources(platform)
      else
        create_framework(platform.name.to_s)
        build_library(platform, defines, @fwk.versions_path + Pathname.new(@spec.name))
        copy_headers
        copy_license
        copy_resources(platform)
      end
    end

    def link_embedded_resources
      target_path = @fwk.root_path + Pathname.new('Resources')
      target_path.mkdir unless target_path.exist?

      Dir.glob(@fwk.resources_path.to_s + '/*').each do |resource|
        resource = Pathname.new(resource).relative_path_from(target_path)
        `ln -sf #{resource} #{target_path}`
      end
    end

    :private

    def build_dynamic_framework(platform, defines, output)
      UI.puts("Building dynamic Framework #{@spec} with configuration #{@config}")

      clean_directory_for_dynamic_build
      if platform.name == :ios
        build_dynamic_framework_for_ios(platform, defines, output)
      else
        build_dynamic_framework_for_mac(platform, defines, output)
      end
    end

    def build_library(platform, defines, output)
      static_libs = static_libs_in_sandbox

      if platform.name == :ios
        build_static_lib_for_ios(static_libs, defines, output)
      else
        build_static_lib_for_mac(static_libs, output)
      end
    end

    def build_dynamic_framework_for_ios(platform, defines, output)
      # Specify frameworks to link and search paths
      linker_flags = static_linker_flags_in_sandbox
      defines = "#{defines} OTHER_LDFLAGS='${inherited} #{linker_flags.join(' ')}'"

      # Build Target Dynamic Framework for both device and Simulator
      device_defines = "#{defines} LIBRARY_SEARCH_PATHS=\"#{Dir.pwd}/#{@static_sandbox_root}/build\""
      device_options = ios_build_options << " -sdk iphoneos"
      xcodebuild(device_defines, device_options, 'build', "#{@spec.name}", "#{@dynamic_sandbox_root}")

      sim_defines = "#{defines} LIBRARY_SEARCH_PATHS=\"#{Dir.pwd}/#{@static_sandbox_root}/build-sim\" ONLY_ACTIVE_ARCH=NO"
      xcodebuild(sim_defines, '-sdk iphonesimulator', 'build-sim', "#{@spec.name}", "#{@dynamic_sandbox_root}")

      # Combine architectures
      `lipo #{@dynamic_sandbox_root}/build/#{@spec.name}.framework/#{@spec.name} #{@dynamic_sandbox_root}/build-sim/#{@spec.name}.framework/#{@spec.name} -create -output #{output}`

      FileUtils.mkdir("#{platform.name}")
      `mv #{@dynamic_sandbox_root}/build/#{@spec.name}.framework #{platform.name}`
    end

    def build_dynamic_framework_for_mac(platform, defines, output)
      # Specify frameworks to link and search paths
      linker_flags = static_linker_flags_in_sandbox
      defines = "#{defines} OTHER_LDFLAGS=\"#{linker_flags.join(' ')}\""

      # Build Target Dynamic Framework for osx
      defines = "#{defines} LIBRARY_SEARCH_PATHS=\"#{Dir.pwd}/#{@static_sandbox_root}/build\""
      xcodebuild(defines, nil, 'build', "#{@spec.name}", "#{@dynamic_sandbox_root}")

      FileUtils.mkdir("#{platform.name}")
      `mv #{@dynamic_sandbox_root}/build/#{@spec.name}.framework #{platform.name}`
    end

    def build_sim_libraries(platform, defines)
      if platform.name == :ios
        xcodebuild(defines, '-sdk iphonesimulator', 'build-sim')
      end
    end

    def build_static_lib_for_ios(static_libs, defines, output)
      return if static_libs.count == 0
      `libtool -static -o #{@static_sandbox_root}/build/package.a #{static_libs.join(' ')}`

      sim_libs = static_libs_in_sandbox('build-sim')
      `libtool -static -o #{@static_sandbox_root}/build-sim/package.a #{sim_libs.join(' ')}`

      `lipo #{@static_sandbox_root}/build/package.a #{@static_sandbox_root}/build-sim/package.a -create -output #{output}`
    end

    def build_static_lib_for_mac(static_libs, output)
      return if static_libs.count == 0
      `libtool -static -o #{output} #{static_libs.join(' ')}`
    end

    def build_with_mangling(platform, options)
      UI.puts 'Mangling symbols'
      defines = Symbols.mangle_for_pod_dependencies(@spec.name, @static_sandbox_root)
      defines << " " << @spec.consumer(platform).compiler_flags.join(' ')

      UI.puts 'Building mangled framework'
      xcodebuild(defines, options)
      defines
    end

    def clean_directory_for_dynamic_build
      # Remove static headers to avoid duplicate declaration conflicts
      FileUtils.rm_rf("#{@static_sandbox_root}/Headers/Public/#{@spec.name}")
      FileUtils.rm_rf("#{@static_sandbox_root}/Headers/Private/#{@spec.name}")

      # Equivalent to removing derrived data
      FileUtils.rm_rf("Pods/build")
    end

    def compile(platform)
      defines = "GCC_PREPROCESSOR_DEFINITIONS='${inherited} PodsDummy_Pods_#{@spec.name}=PodsDummy_PodPackage_#{@spec.name}'"
      defines << " " << @spec.consumer(platform).compiler_flags.join(' ')

      if platform.name == :ios
        options = ios_build_options
      end

      xcodebuild(defines, options)

      if @mangle
        return build_with_mangling(platform, options)
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
        module_map_file = "#{@static_sandbox_root}/#{@spec.name}/#{@spec.module_map}"
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
      `cp "#{license_file}" .` if Pathname(license_file).exist?
    end

    def copy_resources(platform)
      bundles = Dir.glob("#{@static_sandbox_root}/build/*.bundle")
      if @dynamic
        resources_path = "ios/#{@spec.name}.framework"
        `cp -rp #{@static_sandbox_root}/build/*.bundle #{resources_path} 2>&1`
      else
        `cp -rp #{@static_sandbox_root}/build/*.bundle #{@fwk.resources_path} 2>&1`
        resources = expand_paths(@spec.consumer(platform).resources)
        if resources.count == 0 && bundles.count == 0
          @fwk.delete_resources
          return
        end
        if resources.count > 0
          `cp -rp #{resources.join(' ')} #{@fwk.resources_path}`
        end
      end
    end

    def create_framework(platform)
      @fwk = Framework::Tree.new(@spec.name, platform, @embedded)
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
      Dir.glob("#{@static_sandbox_root}/#{build_dir}/lib*.a")
    end

    def static_linker_flags_in_sandbox
      linker_flags = static_libs_in_sandbox.map do |lib|
        lib.slice!("lib")
        lib_flag = lib.chomp(".a").split("/").last
        "-l#{lib_flag}"
      end
      linker_flags.reject { |e| e == "-l#{@spec.name}"|| e == "-lPods" }
    end

    def ios_build_options
      return "ARCHS=\'x86_64 i386 arm64 armv7 armv7s\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'"
    end

    def xcodebuild(defines = '', args = '', build_dir = 'build', target = 'Pods', project_root = @static_sandbox_root, config = @config)

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
