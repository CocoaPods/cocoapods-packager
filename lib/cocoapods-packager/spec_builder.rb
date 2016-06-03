module Pod
  class SpecBuilder
    def initialize(spec, source, embedded, dynamic)
      @spec = spec
      @source = source.nil? ? '{ :path => \'.\' }' : source
      @embedded = embedded
      @dynamic = dynamic
    end

    def framework_path
      if @embedded
        @spec.name + '.embeddedframework' + '/' + @spec.name + '.framework'
      else
        @spec.name + '.framework'
      end
    end

    def spec_platform(platform)
      fwk_base = platform.name.to_s + '/' + framework_path
      spec = <<RB
  s.#{platform.name}.deployment_target    = '#{platform.deployment_target}'
  s.#{platform.name}.vendored_framework   = '#{fwk_base}'
RB

      %w(frameworks weak_frameworks libraries requires_arc xcconfig).each do |attribute|
        attributes_hash = @spec.attributes_hash[platform.name.to_s]
        next if attributes_hash.nil?
        value = attributes_hash[attribute]
        next if value.nil?

        value = "'#{value}'" if value.class == String
        spec += "  s.#{platform.name}.#{attribute} = #{value}\n"
      end
      spec
    end

    def spec_metadata
      spec = spec_header
      spec
    end

    def spec_close
      "end\n"
    end

    private

    def spec_header
      spec = "Pod::Spec.new do |s|\n"

      %w(name version summary license authors homepage description social_media_url
         docset_url documentation_url screenshots frameworks weak_frameworks libraries requires_arc
         deployment_target xcconfig).each do |attribute|
        value = @spec.attributes_hash[attribute]
        next if value.nil?
        value = value.dump if value.class == String
        spec += "  s.#{attribute} = #{value}\n"
      end

      spec + "  s.source = #{@source}\n\n"
    end
  end
end
