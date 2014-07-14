module Pod
	class SpecBuilder
		def initialize(spec)
			@spec = spec
		end

		def spec_platform(platform)
			fwk_base = @spec.name + '-' + platform.name.to_s + '.framework'
            return <<SPEC
  s.#{platform.name}.platform             = :#{platform.symbolic_name}, '#{platform.deployment_target}'
  s.#{platform.name}.preserve_paths       = '#{fwk_base}'
  s.#{platform.name}.public_header_files  = '#{fwk_base}/Versions/A/Headers/*.h'
  #s.#{platform.name}.resource            = '#{fwk_base}/Versions/A/Resources/#{fwk_base}.bundle'
  s.#{platform.name}.vendored_frameworks  = '#{fwk_base}'

SPEC
		end

		def spec_metadata
        	return <<SPEC
Pod::Spec.new do |s|
  s.name          = "#{@spec.name}"
  s.version       = "#{@spec.version}"
  s.summary       = "#{@spec.summary}"
  s.license       = #{@spec.license}
  s.authors       = #{@spec.authors}
  s.homepage      = "#{@spec.homepage}"
  s.source        = #{@spec.source}

SPEC
      	end

      	def spec_close
      		return 'end'
      	end

	end

end