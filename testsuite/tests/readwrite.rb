# encoding: utf-8

# Module:  TFTP server configuration
# Summary: Testsuite
# Authors: Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class ReadwriteClient < Client
    def main
      # testedfiles: TftpServer.ycp Service.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = {
        "etc"    => {
          "xinetd_d" => {
            "tftp" => {
              "section" => { "tftp" => {} },
              "value"   => {
                "tftp" => {
                  "disable"     => nil,
                  "server_args" => "-s -v /srv/boot"
                }
              }
            }
          }
        },
        "target" => { "size" => 0 }
      }

      @WRITE = {}

      @EXECUTE = {
        "target" =>
          # 	    "remove": true, // /etc/yp.conf.sv
          {
            # ok if used both for `lsof` and `rcfoo start`
            "bash_output" => {
              "exit"   => 0,
              "stderr" => "",
              "stdout" => "p3316\ncxinetd\n"
            }
          }
      }

      TESTSUITE_INIT([@READ, @WRITE, @EXECUTE], nil)

      Yast.import "TftpServer"

      TEST(lambda { TftpServer.Read }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(lambda { TftpServer.Write }, [@READ, @WRITE, @EXECUTE], nil) 

      #READ["etc","xinetd_d","tftp","value","tftp","server_args"] = ...

      nil
    end
  end
end

Yast::ReadwriteClient.new.main
