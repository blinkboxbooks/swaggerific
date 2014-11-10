$LOAD_PATH.unshift("lib")
require "blinkbox/swaggerific"
require "yaml"

if ENV['SWAGGERIFIC_TLD_LEVEL']
  if ENV['SWAGGERIFIC_TLD_LEVEL'] =~ /^\d+$/
    Blinkbox::Swaggerific::Service.tld_level = ENV['SWAGGERIFIC_TLD_LEVEL'].to_i
  else
    warn "SWAGGERIFIC_TLD_LEVEL is not a number"
  end
end

if ENV['SWAGGERIFIC_SINGLE_SERVICE']
  begin
    Blinkbox::Swaggerific::Service.swagger_store = ENV['SWAGGERIFIC_SINGLE_SERVICE']
  raise
    warn "SWAGGERIFIC_SINGLE_SERVICE is not a Swagger 2.0 file"    
  end
end

run Blinkbox::Swaggerific::Service
