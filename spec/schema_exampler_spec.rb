context Blinkbox::Swaggerific::SchemaExampler do
  test_schema = YAML.load(open(File.join(__dir__, "example_schema.yaml")))
  test_schema.each_pair do |type, schemas|
    describe "for the #{type} type" do
      schemas.each do |schema|
        it "must work with #{schema.to_json}" do
          exampler = described_class.new(schema, additional_properties: 1)
          generated = exampler.gen
          expect { JSON::Validator.validate!(schema, generated) }.to_not raise_error
        end
      end
    end
  end
end