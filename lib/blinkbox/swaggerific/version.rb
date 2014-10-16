module Blinkbox
  module Swaggerific
    VERSION = begin
      File.read(File.join(__dir__, "../../../VERSION"))
    rescue Errno::ENOENT
      "0.0.0-unknown"
    end
  end
end