module Symbols
  def symbols_from_library(library)
    syms = `nm -defined-only -extern-only #{library}`.split("\n")
    result = classes_from_symbols(syms)
    result += constants_from_symbols(syms)

    result.select do |e|
      case e
      when 'llvm.cmdline', 'llvm.embedded.module', '__clang_at_available_requires_core_foundation_framework'
        false
      else
        true
      end
    end
  end

  module_function :symbols_from_library

  private

  def classes_from_symbols(syms)
    classes = syms.select { |klass| klass[/OBJC_CLASS_\$_/] }
    classes = classes.uniq
    classes.map! { |klass| klass.gsub(/^.*\$_/, '') }
  end

  def constants_from_symbols(syms)
    consts = syms.select { |const| const[/ S /] }
    consts = consts.select { |const| const !~ /OBJC|\.eh/ }
    consts = consts.uniq
    consts = consts.map! { |const| const.gsub(/^.* _/, '') }

    other_consts = syms.select { |const| const[/ T /] }
    other_consts = other_consts.uniq
    other_consts = other_consts.map! { |const| const.gsub(/^.* _/, '') }

    consts + other_consts
  end

  module_function :classes_from_symbols
  module_function :constants_from_symbols
end
