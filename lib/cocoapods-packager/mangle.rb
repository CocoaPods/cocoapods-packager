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
    pod_libs = Dir.glob("#{sandbox_root}/build/lib*.a").select do |file|
      file !~ /lib#{pod_name}.a$/
    end

    dummy_alias = alias_symbol "PodsDummy_#{pod_name}", pod_name
    all_syms = [dummy_alias]

    pod_libs.each do |pod_lib|
      syms = Symbols.symbols_from_library(pod_lib)
      all_syms += syms.map! { |sym| alias_symbol sym, pod_name }
    end

    "GCC_PREPROCESSOR_DEFINITIONS='$(inherited) #{all_syms.uniq.join(' ')}'"
  end

  def alias_symbol(sym, pod_name)
    pod_name = pod_name.tr('-', '_')
    sym + "=Pod#{pod_name}_" + sym
  end

  module_function :mangle_for_pod_dependencies, :alias_symbol
end
