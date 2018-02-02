# encoding: utf-8

# File:	modules/TftpServer.ycp
# Package:	Configuration of TftpServer
# Summary:	Data for configuration of TftpServer, input and output functions.
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Representation of the configuration of TftpServer.
# Input and output routines.
require "yast"

require "shellwords"

require "yast2/target_file" # allow CFA to work on change scr
require "cfa/tftp_sysconfig"
require "y2firewall/firewalld"


module Yast
  class TftpServerClass < Module

    SOCKET_NAME = "tftp"
    PACKAGE_NAME = "tftp"
    SERVER_BIN = "in.tftp"

    include Yast::Logger

    def main
      textdomain "tftp-server"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "SystemdSocket"
      Yast.import "SystemdService"
      Yast.import "Summary"

      # Any settings modified?
      # As we have only a single dialog which handles it by itself,
      # it is used only by autoinst cloning.
      @modified = false

      # Required packages for operation
      @required_packages = [PACKAGE_NAME]

      # tftpd socket
      @socket = SystemdSocket.find(SOCKET_NAME)
      # if socket start tftp
      @start = false

      # sysconfig model
      @sysconfig = ::CFA::TftpSysconfig.new
      # sysconfig values we are interested in. Allow to change it with UI.
      # TODO when doing bigger changes use sysconfig model everywhere
      @directory = "/src/tftpboot" # default value

      # Detect who is serving tftp:
      # Inetd may be running, it is the default. But it is ok unless it is
      # serving tftp. So we detect who is serving tftp and warn if it is
      # not socket or in.tftpd.
      # If nonempty, the user is notified and the module gives up.
      @foreign_servers = ""
    end

    # firewall instance
    def firewall
      @firewall ||= Y2Firewall::Firewalld.instance
    end

    # Returns true if the settings were modified
    # @return settings were modified
    def GetModified
      @modified
    end

    # Function sets an internal variable indicating that any
    # settings were modified to "true".
    # Used for autoinst cloning.
    def SetModified
      @modified = true

      nil
    end

    # Read all tftp-server settings
    # @return true on success
    def Read
      # foreign_servers:
      # get command names via lsof, filter out xinetd and in.tftpd
      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/usr/bin/lsof -i :tftp -Fc")
      )
      lines = Ops.get_string(out, "stdout", "").lines
      # the command is field 'c'
      lines = lines.select { |l| l.start_with?("c") }
      # strip the c
      lines.map! { |l| l[1..-1].strip }
      # filter out our servers
      lines.reject! { |l| l == "in.tftpd" }
      @foreign_servers = lines.join(", ")

      @sysconfig.load
      @directory = @sysconfig.directory

      # force find of socket. It can happen if we need to install package first
      @socket = SystemdSocket.find!(SOCKET_NAME)
      @start = @socket.enabled?

      # TODO only when we have our own Progress
      #boolean progress_orig = Progress::set (false);
      firewall.read
      #Progress::set (progress_orig);

      true
    end

    # Return error string to be used in WriteOnly (for autoinst)
    # or before the edit dialog.
    # @return error string
    def ForeignServersError
      # error popup
      # %1 is a command name (or a comma (, ) separated list of them)
      Builtins.sformat(
        _(
          "This module can only use systemd socket to set up TFTP.\n" +
            "However, another program is serving TFTP: %1.\n" +
            "Exiting.\n"
        ),
        @foreign_servers
      )
    end

    # Write all tftp-server settings
    # without actually (re)starting the service
    # @return true on success
    def WriteOnly
      Builtins.y2milestone("Writing")

      # give up if tftp is served by someone else
      if @foreign_servers != ""
        Report.Error(ForeignServersError())
        return false
      end

      @sysconfig.directory = @directory
      @sysconfig.save


      # image dir: if does not exist, create with root:root rwxr-xr-x
      SCR.Execute(path(".target.mkdir"), @directory)
      # and then switch to user which is used for tftp service
      SCR.Execute(path(".target.bash_output"), "/usr/bin/chown #{@sysconfig.user}: #{Shellwords.escape(@directory)}")

      # enable and (re)start xinetd
      if @start
        @socket.enable
        @socket.start
      else
        @socket.disable
        @socket.stop
      end

      # TODO only when we have our own Progress
      #boolean progress_orig = Progress::set (false);
      firewall.write_only
      #Progress::set (progress_orig);

      true
    end

    # Write all tftp-server settings
    # @return true on success
    def Write
      # write the config file
      # image dir: if does not exist, create with root:root rwxr-xr-x
      # firewall??
      # enable and (re)start xinetd

      return false if !WriteOnly()

      # in.tftpd will linger around for 15 minutes waiting for a new connection
      # so we must kill it otherwise it will be using the old parameters
      SystemdService.find!("tftp").stop

      # TODO only when we have our own Progress
      #boolean progress_orig = Progress::set (false);
      firewall.reload
      #Progress::set (progress_orig);

      true
    end

    # Set module data, without validity checking
    # @param [Hash] settings may be empty for reset
    # @return [void]
    def Set(settings)
      settings = deep_copy(settings)
      @start = Ops.get_boolean(settings, "start_tftpd", false)
      @directory = Ops.get_string(settings, "tftp_directory", "/srv/tftpboot")

      nil
    end


    # Get all tftp-server settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      if settings != {}
        s = "start_tftpd"
        d = "tftp_directory"
        if !Builtins.haskey(settings, s)
          Builtins.y2error("Missing at Import: '%1'.", s)
          return false
        end
        if Ops.get_boolean(settings, s, false) && !Builtins.haskey(settings, d)
          Builtins.y2error("Missing at Import: '%1'.", d)
          return false
        end
      end
      Set(settings)
      true
    end

    # Dump the tftp-server settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      settings = { "start_tftpd" => @start }
      Ops.set(settings, "tftp_directory", @directory) if @start
      deep_copy(settings)
    end

    # @return Html formatted configuration summary
    def Summary
      summary = ""
      nc = Summary.NotConfigured

      # summary header
      summary = Summary.AddHeader(summary, _("TFTP Server Enabled:"))
      # summary item: an option is turned on
      summary = Summary.AddLine(summary, @start ? _("Yes") : nc)

      # summary header
      summary = Summary.AddHeader(summary, _("Boot Image Directory:"))
      summary = Summary.AddLine(summary, @directory != "" ? @directory : nc)

      summary
    end

    # Return needed packages and packages to be removed
    # during autoinstallation.
    # @return [Hash] of lists.
    #
    #

    def AutoPackages
      install_pkgs = deep_copy(@required_packages)
      remove_pkgs = []
      { "install" => install_pkgs, "remove" => remove_pkgs }
    end

    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :variable => :required_packages, :type => "list <string>"
    publish :variable => :start, :type => "boolean"
    publish :variable => :directory, :type => "string"
    publish :variable => :foreign_servers, :type => "string"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :ForeignServersError, :type => "string ()"
    publish :function => :WriteOnly, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Set, :type => "void (map)"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :AutoPackages, :type => "map ()"
  end

  TftpServer = TftpServerClass.new
  TftpServer.main
end
