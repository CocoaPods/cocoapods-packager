module Symbols

	#
	# performs symbol aliasing
	#
	# for each dependency:
	# 	- determine symbols for classes and global constants
	# 	- alias each symbol to Pod#{pod_name}_#{symbol}
	# 	- put defines into `GCC_PREPROCESSOR_DEFINITIONS` for passing to Xcode
	#
	def mangle_for_pod_dependencies(pod_name, sandbox_root)
		pod_libs = Dir.glob("#{sandbox_root}/build/libPods-*.a").select do
          |file| file !~ /#{pod_name}/
        end

        all_syms = []

        for pod_lib in pod_libs do
          syms = Symbols.symbols_from_library(pod_lib)
          all_syms += syms.map! { |sym| sym = sym + "=Pod#{pod_name}_" + sym }
        end

        return "GCC_PREPROCESSOR_DEFINITIONS='${inherited} #{all_syms.join(' ')}'"
	end

	module_function :mangle_for_pod_dependencies

end