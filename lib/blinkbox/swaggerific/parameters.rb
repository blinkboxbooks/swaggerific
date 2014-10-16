module Blinkbox
  module Swaggerific
    class Parameters
      include Helpers

      # TODO: Headers, query, body?
      def initialize(spec, path: {}, env: {}, header: {}, query: {})
        @spec = spec
        # NB. When 'all' is called, a keys present in more than one section will be overridden by the value in the latest section.
        @params = {
          path: path,
          # TODO: The rescue is to cope with the case where one form item is sent, it's a file but no actual file is specified. Better way to deal with this?
          formData: (Rack::Multipart::Parser.new(env).parse || {} rescue {}),
          # TODO: May need to cope with unusual casing in header keys?
          header: header,
          query: query
        }

        if !missing.empty?
          halt(400, {
            "error" => "missing_params",
            "message" => "Required parameters are missing",
            "details" => {
              "reasons" => missing
            }
          }.to_json)
        end
      end

      def missing
        # TODO: Probably also need to do non-required but present params
        @missing ||= Hash[@spec.map { |param_spec|
          next nil if !param_spec['required']
          value = @params[param_spec['in'].to_sym][param_spec['name']]
          reason = "is missing" if value.nil?
          reason ||= case param_spec['type']
          when 'file'
            "is not a file" if !value.is_a?(Hash) || !value[:tempfile] || !value[:tempfile].is_a?(Tempfile)
          when 'string'
            if value.match(/^.*$/)
              case param_spec['format']
              when "string"
              when nil
                # No action for either of these, there's no required format
              when %w{integer long float double byte boolean date dateTime uri}
                # TODO: support some of these
                "has a required format that Swaggerific doesn't support yet. Sorry!"
              else
                "isn't of the required format" unless Regexp.new(param_spec['format']).match(value)
              end
            else
              "is not a string"
            end
          when 'number'
            "is not a number" unless value.match(/^-?\d+(?:\.\d+)?$/)
          when 'integer'
            "is not an integer" unless value.match(/^-?\d+$/)
          when 'boolean'
            # TODO: Cope with Booleans
            "is supposed to be a boolean and I dont't know how to cope with that..."
          else
            "is untestable as no type was specified in the swagger docs"
          end
          [ param_spec['name'], reason ] unless reason.nil?
        }.compact]
        @missing
      end

      def all(symbol_keys: true)
        all_params = @params.inject({}) do |all_params, group|
          all_params.merge!(group.last)
        end
        Hash[all_params.map{ |k, v| [k.to_sym, v] }] if symbol_keys
      end
    end
  end
end