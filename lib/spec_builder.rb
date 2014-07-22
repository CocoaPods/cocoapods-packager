module Pod
  class SpecBuilder
    def initialize(spec, source)
      @spec = spec
      @source = source.nil? ? '{}' : source
    end

    def spec_platform(platform)
      fwk_base = platform.name.to_s + '/' + @spec.name + '.framework'
      spec = <<SPEC
  s.#{platform.name}.platform             = :#{platform.symbolic_name}, '#{platform.deployment_target}'
  s.#{platform.name}.preserve_paths       = '#{fwk_base}'
  s.#{platform.name}.public_header_files  = '#{fwk_base}/Versions/A/Headers/*.h'
  s.#{platform.name}.resource             = '#{fwk_base}/Versions/A/Resources/**/*'
  s.#{platform.name}.vendored_frameworks  = '#{fwk_base}'
SPEC

      %w(frameworks libraries requires_arc xcconfig).each do |attribute|
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
      spec += spec_single_platform_fix
      spec
    end

    def spec_close
      "end\n"
    end

    :private

    def spec_header
      spec = "Pod::Spec.new do |s|\n"

      %w(name version summary license authors homepage description social_media_url
         docset_url documentation_url screenshots frameworks libraries requires_arc
         deployment_target xcconfig).each do |attribute|
        value = @spec.attributes_hash[attribute]
        next if value.nil?

        value = "'#{value}'" if value.class == String
        spec += "  s.#{attribute} = #{value}\n"
      end

      spec + "  s.source = #{@source}\n\n"
    end

    def spec_single_platform_fix
      return '' if @spec.available_platforms.length > 1

      platform = @spec.available_platforms.first

      <<SPEC
  s.platform = :#{platform.symbolic_name}, '#{platform.deployment_target}'
SPEC
    end
  end
end
