module Pod
  class SpecBuilder
    def initialize(spec, source)
      @spec = spec
      @source = source.nil? ? '{}' : source
    end

    def spec_platform(platform)
      fwk_base = platform.name.to_s + '/' + @spec.name + '.framework'
      <<SPEC
  s.#{platform.name}.platform             = :#{platform.symbolic_name}, '#{platform.deployment_target}'
  s.#{platform.name}.preserve_paths       = '#{fwk_base}'
  s.#{platform.name}.public_header_files  = '#{fwk_base}/Versions/A/Headers/*.h'
  s.#{platform.name}.resource             = '#{fwk_base}/Versions/A/Resources/*.bundle'
  s.#{platform.name}.vendored_frameworks  = '#{fwk_base}'

SPEC
    end

    def spec_metadata
      spec = <<SPEC
Pod::Spec.new do |s|
  s.name          = "#{@spec.name}"
  s.version       = "#{@spec.version}"
  s.summary       = "#{@spec.summary}"
  s.license       = #{@spec.license}
  s.authors       = #{@spec.authors}
  s.homepage      = "#{@spec.homepage}"
  s.source        = #{@source}

SPEC

      if @spec.available_platforms.length == 1
        platform = @spec.available_platforms.first

        spec += <<SPEC
  s.platform      = :#{platform.symbolic_name}, '#{platform.deployment_target}'

SPEC
      end

      spec
    end

    def spec_close
      'end'
    end
  end
end
