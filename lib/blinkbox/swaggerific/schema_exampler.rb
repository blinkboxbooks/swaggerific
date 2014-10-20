require "json"
require "time"
require "uri"

module Blinkbox
  module Swaggerific
    class SchemaExampler
      # The schema file which is being used as a basis
      attr_reader :schema
      # Useful for Swagger documentation, you can define definitions which can be referenced by name
      attr_reader :extra_definitions
      # The probability for generating values for properties which are not required
      attr_reader :additional_properties

      def initialize(schema, extra_definitions = {}, additional_properties: 0.5)
        @schema = schema
        @extra_definitions = extra_definitions
        @additional_properties = additional_properties
      end

      def gen
        process_schema(@schema)
      end

      private

      def process_schema(obj)
        raise "Not a schema object #{obj.inspect}" unless obj.is_a?(Hash)
        return process_schema(get_definition(obj["$ref"])) if obj["$ref"]
        # object is the default??
        type = obj["type"] || (obj.has_key?("enum") ? "enum" : "object")
        method = "gen_#{type}".to_sym
        raise "Cannot generate JSON Schema object of type '#{type}'." unless private_methods.include?(method)
        send(method, obj)
      end

      def get_definition(name)
        return @extra_definitions[name] if @extra_definitions[name]
        raise NotImplementedError, "Use JSON path to pull out schema"
      end

      def gen_object(obj)
        Hash[obj["properties"].map { |key, schema_object|
          next nil if !(obj["required"] || []).include?(key) && (@additional_properties == 0 || Random.rand > @additional_properties)
          [key, process_schema(schema_object)]
        }.compact]
      end

      def gen_null(obj = {})
        nil
      end

      def gen_enum(obj)
        obj["enum"].sample
      end

      def gen_boolean(obj = {})
        [true, false].sample
      end

      def gen_array(obj = {})
        min_count = obj["minItems"] || 2
        max_count = obj["maxItems"] || 5
        count = Random.rand(max_count - min_count + 1) + min_count
        return count.times.map do
          process_schema(obj["items"])
        end
      end

      def gen_integer(obj = {})
        min = obj["minimum"] || 10
        max = obj["maximum"] || 1000
        Random.rand(max - min + 1) + min
      end

      def gen_number(obj = {})
        min = obj["minimum"] || 10
        max = obj["maximum"] || 1000
        # TODO: exclusive minimum/maximum
        Random.rand * (max - min) + min
      end

      def gen_string(obj = {})
        case obj["format"]
        when "date-time"
          Time.at(Random.rand(Time.now.to_i)).utc.iso8601
        when "ipv4"
          4.times.map { Random.rand(255) }.join(".")
        when "ipv6"
          8.times.map { Random.rand(65536).to_s(16).rjust(4, "0") }.join(":")
        when "uri"
          "http://example.com/" + gen_string
        else
          min_length = obj["minLength"] || 10
          max_length = obj["maxLength"] || 10
          length = Random.rand(max_length - min_length + 1) + min_length
          ('a'..'z').to_a.sample(length).join
        end
      end
    end
  end
end
