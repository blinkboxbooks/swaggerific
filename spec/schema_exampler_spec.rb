context Blinkbox::Swaggerific::SchemaExampler do
  {
    "string" => [
      {},
      {"format" => "uri"},
      {"format" => "ipv4"},
      {"format" => "ipv6"},
      {"format" => "date-time"}
    ],
    "boolean" => [{}],
    "null" => [{}],
    "integer" => [
      {},
      # {"minimum" => 9000},
      # {"maximum" => 1},
      {"minimum" => 0, "maximum" => 1}
    ],
    "number" => [{}],
    "object" => [
      {
        "properties" => {
          "key" => {
            "type" =>"string"
          }
        }
      }
    ],
    "enum" => [
      {
        "enum" => [ "val1", "val2" ]
      }
    ],
    "array" => [
      {
        "items" => {
          "type" => "string"
        }
      }
    ]
  }.each_pair do |type, schemas|
    describe "for the #{type} type" do
      schemas.each do |schema|
        it "must work with #{schema.to_json}" do
          schema["type"] = type unless type == "enum"
          exampler = described_class.new(schema, additional_properties: 1)
          generated = exampler.gen
          expect { JSON::Validator.validate!(schema, generated) }.to_not raise_error
        end
      end
    end
  end
end