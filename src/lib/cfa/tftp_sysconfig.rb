require "cfa/base_model"
require "cfa/augeas_parser"

module CFA
  class TftpSysconfig < BaseModel
    attributes(
      user:      "TFTP_USER",
      directory: "TFTP_DIRECTORY",
      options:   "TFTP_OPTIONS"
    )

    PATH = "/etc/sysconfig/tftp".freeze

    def initialize(file_handler: nil)
      super(AugeasParser.new("sysconfig.lns"), PATH,
        file_handler: file_handler)
    end
  end
end
