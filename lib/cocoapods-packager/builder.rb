module Pod
  class Builder
    def initialize(source_dir, sandbox_root, public_headers_root, spec, embedded, mangle)
      @source_dir = source_dir
      @sandbox_root = sandbox_root
      @public_headers_root = public_headers_root
      @spec = spec
      @embedded = embedded
      @mangle = mangle
    end

    def build(platform, library)
      if library
        build_static_library(platform)
      else
        build_framework(platform)
      end
    end

    def build_static_library(platform)
      UI.puts('Building static library')

      defines = compile(platform)
      platform_path = Pathname.new(platform.name.to_s)
      platform_path.mkdir unless platform_path.exist?
      build_library(platform, defines, platform_path + Pathname.new("lib#{@spec.name}.a"))
    end

    def build_framework(platform)
      UI.puts('Building framework')

      defines = compile(platform)
      create_framework(platform.name.to_s)
      copy_headers
      build_library(platform, defines, @fwk.versions_path + Pathname.new(@spec.name))
      copy_license
      copy_resources(platform)
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

    def build_library(platform, defines, output)
      static_libs = static_libs_in_sandbox

      if platform.name == :ios
        build_static_lib_for_ios(static_libs, defines, output)
      else
        build_static_lib_for_mac(static_libs, output)
      end
    end

    def build_static_lib_for_ios(static_libs, defines, output)
      return if static_libs.count == 0
      `libtool -static -o #{@sandbox_root}/build/package.a #{static_libs.join(' ')}`

      xcodebuild(defines, '-sdk iphonesimulator', 'build-sim')
      sim_libs = static_libs_in_sandbox('build-sim')
      `libtool -static -o #{@sandbox_root}/build-sim/package.a #{sim_libs.join(' ')}`

      `lipo #{@sandbox_root}/build/package.a #{@sandbox_root}/build-sim/package.a -create -output #{output}`
    end

    def build_static_lib_for_mac(static_libs, output)
      return if static_libs.count == 0
      `libtool -static -o #{output} #{static_libs.join(' ')}`
    end

    def build_with_mangling(platform)
      UI.puts 'Mangling symbols'
      defines = Symbols.mangle_for_pod_dependencies(@spec.name, @sandbox_root)
      defines << " " << @spec.consumer(platform).compiler_flags.join(' ')

      if platform.name == :ios
        defines = "#{defines} ARCHS=\"x86_64 i386 arm64 armv7 armv7s\""
      end

      UI.puts 'Building mangled framework'
      xcodebuild(defines)
      defines
    end

    def compile(platform)
      defines = "GCC_PREPROCESSOR_DEFINITIONS='PodsDummy_Pods_#{@spec.name}=PodsDummy_PodPackage_#{@spec.name}'"
      defines << " " << @spec.consumer(platform).compiler_flags.join(' ')

      if platform.name == :ios
        defines = "#{defines} ARCHS=\"x86_64 i386 arm64 armv7 armv7s\""
      end

      xcodebuild(defines)

      if dependency_count > 0 && @mangle
        return build_with_mangling(platform)
      end

      defines
    end

    def copy_headers
      headers_source_root = "#{@public_headers_root}/#{@spec.name}"

      Dir.glob("#{headers_source_root}/**/*.h").
        each { |h| `ditto #{h} #{@fwk.headers_path}/#{h.sub(headers_source_root, '')}` }

      if File.exist?("#{@public_headers_root}/#{@spec.name}/#{@spec.name}.h")
        module_map = <<MAP
framework module #{@spec.name} {
  umbrella header "#{@spec.name}.h"

  export *
  module * { export * }
}
MAP

        @fwk.module_map_path.mkpath unless @fwk.module_map_path.exist?
        File.write("#{@fwk.module_map_path}/module.modulemap", module_map)
      end
    end

    def copy_license
      license_file = @spec.license[:file] || 'LICENSE'
      license_file = "#{@sandbox_root}/#{@spec.name}/#{license_file}"
      `cp "#{license_file}" .` if Pathname(license_file).exist?
    end

    def copy_resources(platform)
      bundles = Dir.glob("#{@sandbox_root}/build/*.bundle")
      `cp -rp #{@sandbox_root}/build/*.bundle #{@fwk.resources_path} 2>&1`

      resources = expand_paths(@spec.consumer(platform).resources)
      if resources.count == 0 && bundles.count == 0
        @fwk.delete_resources
        return
      end

      if resources.count > 0
        `cp -rp #{resources.join(' ')} #{@fwk.resources_path}`
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
      Dir.glob("#{@sandbox_root}/#{build_dir}/libPods-*.a")
    end

    def xcodebuild(defines = '', args = '', build_dir = 'build')
      `xcodebuild #{defines} CONFIGURATION_BUILD_DIR=#{build_dir} clean build #{args} -configuration Release -target Pods -project #{@sandbox_root}/Pods.xcodeproj 2>&1`
    end
  end
end
