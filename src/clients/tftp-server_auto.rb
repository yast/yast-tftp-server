# encoding: utf-8

# File:
#   TftpServer_auto.ycp
#
# Package:
#   Configuration of TFTPSERVER
#
# Summary:
#   Client for autoinstallation
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param first a map of TFTPSERVER settings
# @return [Hash] edited settings or an empty map if canceled
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallModule ("tftp-server_auto", [ mm ]);
module Yast
  class TftpServerAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "tftp-server"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("TftpServer auto started")

      Yast.import "TftpServer"
      Yast.include self, "tftp-server/wizards.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Create a summary
      if @func == "Summary"
        @ret = TftpServer.Summary
      # Reset configuration
      elsif @func == "Reset"
        TftpServer.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = TftpServerAutoSequence()
      # Import configuration
      elsif @func == "Import"
        @ret = TftpServer.Import(@param)
      # Return package list
      elsif @func == "Packages"
        @ret = TftpServer.AutoPackages
      # Return actual state
      elsif @func == "Export"
        @ret = TftpServer.Export
      # Read current state
      elsif @func == "Read"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = TftpServer.Read
        Progress.set(@progress_orig)
      # Write givven settings
      elsif @func == "Write"
        # Merging current settings with already existing configuration.
        TftpServer.merge_to_system
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = TftpServer.Write
        Progress.set(@progress_orig)
      elsif @func == "SetModified"
        @ret = TftpServer.SetModified
      elsif @func == "GetModified"
        @ret = TftpServer.GetModified
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("TftpServer auto finished")
      Builtins.y2milestone("----------------------------------------")
      return deep_copy(@ret)
    end
  end
end

Yast::TftpServerAutoClient.new.main
