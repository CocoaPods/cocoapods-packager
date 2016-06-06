module Framework
  class Tree
    attr_reader :headers_path
    attr_reader :module_map_path
    attr_reader :resources_path
    attr_reader :root_path
    attr_reader :versions_path

    def delete_resources
      Pathname.new(@resources_path).rmtree
      (Pathname.new(@fwk_path) + Pathname.new('Resources')).delete
    end

    def initialize(name, platform, embedded)
      @name = name
      @platform = platform
      @embedded = embedded
    end

    def make
      make_root
      make_framework
      make_headers
      make_resources
      make_current_version
    end

    private

    def make_current_version
      current_version_path = @versions_path + Pathname.new('../Current')
      `ln -sf A #{current_version_path}`
      `ln -sf Versions/Current/Headers #{@fwk_path}/`
      `ln -sf Versions/Current/Resources #{@fwk_path}/`
      `ln -sf Versions/Current/#{@name} #{@fwk_path}/`
    end

    def make_framework
      @fwk_path = @root_path + Pathname.new(@name + '.framework')
      @fwk_path.mkdir unless @fwk_path.exist?

      @module_map_path = @fwk_path + Pathname.new('Modules')
      @versions_path = @fwk_path + Pathname.new('Versions/A')
    end

    def make_headers
      @headers_path = @versions_path + Pathname.new('Headers')
      @headers_path.mkpath unless @headers_path.exist?
    end

    def make_resources
      @resources_path = @versions_path + Pathname.new('Resources')
      @resources_path.mkpath unless @resources_path.exist?
    end

    def make_root
      @root_path = Pathname.new(@platform)

      if @embedded
        @root_path += Pathname.new(@name + '.embeddedframework')
      end

      @root_path.mkpath unless @root_path.exist?
    end
  end
end
