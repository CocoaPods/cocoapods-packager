require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe SpecBuilder do
    def compare_attributes(first_spec, second_spec, attribute_name)
      first_spec.attributes_hash[attribute_name].should ==
        second_spec.attributes_hash[attribute_name]

      %w(ios osx).each do |platform|
        first_spec.attributes_hash[platform][attribute_name].should ==
          second_spec.attributes_hash[platform][attribute_name]
      end
    end

    def specification_from_builder(builder)
      spec_string = builder.spec_metadata
      spec_string += builder.spec_platform(Platform.ios)
      spec_string += builder.spec_platform(Platform.osx)
      spec_string += builder.spec_close

      return Specification.from_string(spec_string, 'Builder.podspec')
    end

    describe 'Preserve attributes from source specification' do
      before do
        @spec = Specification.from_file('spec/fixtures/Builder.podspec')
        @builder = SpecBuilder.new(@spec, nil, false, nil)
      end

      it "preserves platform.frameworks" do
        spec = specification_from_builder(@builder)
        compare_attributes(spec, @spec, 'frameworks')
      end

      it "preserves platform.weak_frameworks" do
        spec = specification_from_builder(@builder)
        compare_attributes(spec, @spec, 'weak_frameworks')
      end

      it "preserves platform.libraries" do
        spec = specification_from_builder(@builder)
        compare_attributes(spec, @spec, 'libraries')
      end

      it "preserves platform.requires_arc" do
        spec = specification_from_builder(@builder)
        compare_attributes(spec, @spec, 'requires_arc')
      end

      it "preserves platform.deployment_target" do
        spec = specification_from_builder(@builder)
        compare_attributes(spec, @spec, 'deployment_target')
      end

      it "preserves platform.xcconfig" do
        spec = specification_from_builder(@builder)
        compare_attributes(spec, @spec, 'xcconfig')
      end
    end
  end
end
