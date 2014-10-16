require File.join(__dir__, "lib/blinkbox/swaggerific/service")
require "yaml"

if ENV['SWAGGERIFIC_TLD_LEVEL']
  if ENV['SWAGGERIFIC_TLD_LEVEL'] =~ /^\d+$/
    warn "SWAGGERIFIC_TLD_LEVEL is not a number"
  else
    Blinkbox::Swaggerific::Service.tld_level = ENV['SWAGGERIFIC_TLD_LEVEL'].to_i
  end
end

if ENV['SWAGGERIFIC_SINGLE_SERVICE']
  spec = YAML.load(open(ENV['SWAGGERIFIC_SINGLE_SERVICE'])) rescue nil
  if spec.nil? || spec['swagger'].to_f < 2.0
    warn "SWAGGERIFIC_SINGLE_SERVICE is not a Swagger 2.0 file"
  else
    Blinkbox::Swaggerific::Service.swagger_store = ENV['SWAGGERIFIC_SINGLE_SERVICE']
  end
end

run Blinkbox::Swaggerific::Service
