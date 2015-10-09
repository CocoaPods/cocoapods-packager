module Symbols
  def symbols_from_library(library)
    syms = `nm -gU #{library}`.split("\n")

    result = classes_from_symbols(syms)
    result = result + constants_from_symbols(syms)

    all_syms = `nm #{library}`.split("\n")
    result = result + categories_from_symbols(all_syms)

    result.reject { |e| e == "llvm.cmdline" || e == "llvm.embedded.module" }
  end

  module_function :symbols_from_library

  :private

  def classes_from_symbols(syms)
    classes = syms.select { |klass| klass[/OBJC_CLASS_\$_/] }
    classes = classes.uniq
    classes.map! { |klass| klass.gsub(/^.*\$_/, '') }
  end

  def categories_from_symbols(syms)
    classes = syms.select { |klass| klass[/OBJC_\$_CATEGORY_/] }
    classes.map! { |klass| klass.gsub(/^.*\$_/, '') }
    classes = classes.uniq
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

  module_function :categories_from_symbols
  module_function :classes_from_symbols
  module_function :constants_from_symbols
end
