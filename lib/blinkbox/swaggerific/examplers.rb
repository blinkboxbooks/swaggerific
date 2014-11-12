module Blinkbox::Swaggerific
  class ExamplesExampler
    def self.from_examples(examples)
      return nil if !examples.is_a?(Hash) || examples.keys.empty?
      exampler = self.new
      exampler.instance_variable_set('@examples', examples)
      exampler
    end

    def generatable_types
      @examples.keys
    end

    def example(content_type)
      return nil unless generatable_types.include?(content_type)
      @examples[content_type].to_s
    end
  end

  class SchemaExampler
    def self.from_schema(schema)
      return nil if !schema.is_a?(Hash)
      exampler = self.new
      exampler.instance_variable_set('@schema', schema)
      exampler
    end

    def generatable_types
      ["application/json"]
    end

    def example(content_type)
      return nil unless generatable_types.include?(content_type)
      JSONSchema.new(@schema).genny.to_json
    end
  end
end
