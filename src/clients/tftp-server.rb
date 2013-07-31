# encoding: utf-8

# File:	clients/tftp-server.ycp
# Package:	Configuration of tftp-server
# Summary:	Main file
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Main file for tftp-server configuration. Uses all other files.
module Yast
  class TftpServerClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of the tftp-server</h3>

      textdomain "tftp-server"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Tftp-server module started")

      Yast.include self, "tftp-server/wizards.rb"

      Yast.import "CommandLine"

      # description map for command line
      @cmdline_description = {
        "id"         => "tftp-server",
        "guihandler" => fun_ref(method(:TftpServerSequence), "symbol ()"),
        "initialize" => fun_ref(TftpServer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(TftpServer.method(:Write), "boolean ()"),
        "help"       => _("Configure a TFTP server"),
        "actions"    => {
          "status"    => {
            #command line: help text for "status" command
            "help"    => _(
              "Status of the TFTP server"
            ),
            "handler" => fun_ref(
              method(:handlerStatus),
              "boolean (map <string, string>)"
            )
          },
          "directory" => {
            #command line: help text for "directory" command
            "help"    => _(
              "Directory of the TFTP server"
            ),
            "handler" => fun_ref(
              method(:handlerDirectory),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          "enable"  => {
            #command line: help text for "enable" command
            "help" => _(
              "Enable the TFTP service"
            )
          },
          "disable" => {
            #command line: help text for "disable" command
            "help" => _(
              "Disable the TFTP service"
            )
          },
          "show"    => {
            #command line: help text for "show" command
            "help" => _(
              "Show the status of the TFTP service"
            )
          },
          "path"    => {
            "type" => "string",
            #command line: help text for "path" command
            "help" => _(
              "Set the directory for the TFTP server"
            )
          },
          "list"    => {
            #command line: help text for "list" command
            "help" => _(
              "Show the directory for the TFTP server"
            )
          }
        },
        "mappings"   => {
          "status"    => ["enable", "disable", "show"],
          "directory" => ["path", "list"]
        }
      }

      # main ui function
      @ret = nil

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Tftp-server module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # handler function for "status" command
    def handlerStatus(options)
      options = deep_copy(options)
      command = CommandLine.UniqueOption(options, ["enable", "disable", "show"])
      case command
        when "show"
          # command line: show status of tftp-server
          CommandLine.Print(
            Builtins.sformat(_("Service Status: %1"), TftpServer.start)
          )
        when "enable"
          TftpServer.start = true
          Builtins.y2milestone("Enable tftp-server")
        when "disable"
          TftpServer.start = false
          Builtins.y2milestone("Disable tftp-server")
      end
      true
    end

    # handler function for "directory" command
    def handlerDirectory(options)
      options = deep_copy(options)
      command = CommandLine.UniqueOption(options, ["path", "list"])
      case command
        when "list"
          # command line: show directory server by tftp-server
          CommandLine.Print(
            Builtins.sformat(_("Directory Path: %1"), TftpServer.directory)
          )
        when "path"
          TftpServer.directory = Ops.get(options, "path", "")
          Builtins.y2milestone("Set directory path to %1", TftpServer.directory)
      end
      true
    end
  end
end

Yast::TftpServerClient.new.main
