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

module Yast
  class TftpServerClass < Module
    def main
      textdomain "tftp-server"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "Summary"
      Yast.import "SuSEFirewall"

      # Any settings modified?
      # As we have only a single dialog which handles it by itself,
      # it is used only by autoinst cloning.
      @modified = false

      # Required packages for operation
      @required_packages = ["xinetd", "tftp"]

      # Start tftpd via xinetd?
      @start = false

      # Image directory, last argument of in.tftpd
      @directory = ""

      # Other arguments to in.tftpd, ie. not including -s or /dir
      @other_args = ""


      # Detect who is serving tftp:
      # Inetd may be running, it is the default. But it is ok unless it is
      # serving tftp. So we detect who is serving tftp and warn if it is
      # not xinetd or in.tftpd.
      # If nonempty, the user is notified and the module gives up.
      @foreign_servers = ""
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

    # Extract the directory and other arguments.
    # global to make testing easier
    # @param [String] server_args server_args from xinetd.conf
    def ParseServerArgs(server_args)
      # extract the last argument and kick "-s".
      server_args_l = Builtins.filter(Builtins.splitstring(server_args, " \t")) do |s|
        s != ""
      end
      sz = Builtins.size(server_args_l)
      i = 0
      other_args_l = Builtins.filter(server_args_l) do |s|
        i = Ops.add(i, 1)
        s != "-s" && i != sz
      end
      @directory = Ops.get(server_args_l, Ops.subtract(sz, 1), "")
      @other_args = Builtins.mergestring(other_args_l, " ")

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
      lines = Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
      # the command is field 'c'
      lines = Builtins.filter(lines) { |l| Builtins.substring(l, 0, 1) == "c" }
      # strip the c
      lines = Builtins.maplist(lines) do |l|
        Builtins.substring(l, 1, Ops.subtract(Builtins.size(l), 1))
      end
      # filter out our servers
      lines = Builtins.filter(lines) { |l| l != "xinetd" && l != "in.tftpd" }
      @foreign_servers = Builtins.mergestring(lines, ", ")

      xinetd_start = Service.Enabled("xinetd")

      # is the config file there at all?
      sections = SCR.Dir(path(".etc.xinetd_d.tftp.section"))
      disable = Convert.to_string(
        SCR.Read(path(".etc.xinetd_d.tftp.value.tftp.disable"))
      )
      @start = xinetd_start && sections != [] && disable != "yes"

      server_args = Convert.to_string(
        SCR.Read(path(".etc.xinetd_d.tftp.value.tftp.server_args"))
      )
      if server_args == nil
        # default
        #	server_args = "-s /tftpboot";
        server_args = ""
      end

      ParseServerArgs(server_args)

      # TODO only when we have our own Progress
      #boolean progress_orig = Progress::set (false);
      SuSEFirewall.Read
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
          "This module can only use xinetd to set up TFTP.\n" +
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

      # write the config file
      #
      #  create it if it does not exist
      #  could be a normal situation at initial setup
      #  or a broken setup, ok if we fix it when writing
      #  but that means messing up with other parameters
      #  lets touch just the basics
      #  the first "item" is the brace following the section start
      SCR.Write(path(".etc.xinetd_d.tftp.value.tftp.\"{\""), "")
      SCR.Write(path(".etc.xinetd_d.tftp.value_type.tftp.\"{\""), 1)
      SCR.Write(
        path(".etc.xinetd_d.tftp.value.tftp.disable"),
        @start ? "no" : "yes"
      )
      if @start
        SCR.Write(path(".etc.xinetd_d.tftp.value.tftp.socket_type"), "dgram")
        SCR.Write(path(".etc.xinetd_d.tftp.value.tftp.protocol"), "udp")
        SCR.Write(path(".etc.xinetd_d.tftp.value.tftp.wait"), "yes")
        SCR.Write(path(".etc.xinetd_d.tftp.value.tftp.user"), "root")
        SCR.Write(
          path(".etc.xinetd_d.tftp.value.tftp.server"),
          "/usr/sbin/in.tftpd"
        )
        server_args = Builtins.sformat("%1 -s %2", @other_args, @directory)
        SCR.Write(
          path(".etc.xinetd_d.tftp.value.tftp.server_args"),
          server_args
        )
      end

      # flush
      SCR.Write(path(".etc.xinetd_d.tftp"), nil)

      # image dir: if does not exist, create with root:root rwxr-xr-x
      SCR.Execute(path(".target.mkdir"), @directory)

      # firewall??

      # enable and (re)start xinetd
      Service.Enable("xinetd") if @start

      # TODO only when we have our own Progress
      #boolean progress_orig = Progress::set (false);
      SuSEFirewall.WriteOnly
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

      # enable and (re)start xinetd

      # in.tftpd will linger around for 15 minutes waiting for a new connection
      # so we must kill it otherwise it will be using the old parameters
      SCR.Execute(path(".target.bash"), "/usr/bin/killall in.tftpd")

      if @start
        Service.Restart("xinetd")
      else
        # xinetd may be needed for other services so we never turn it
        # off. It will exit anyway if no services are configured.
        # If it is running, restart it.
        Service.RunInitScript("xinetd", "try-restart")
      end

      # TODO only when we have our own Progress
      #boolean progress_orig = Progress::set (false);
      SuSEFirewall.ActivateConfiguration
      #Progress::set (progress_orig);

      true
    end

    # Set module data, without validity checking
    # @param [Hash] settings may be empty for reset
    # @return [void]
    def Set(settings)
      settings = deep_copy(settings)
      @start = Ops.get_boolean(settings, "start_tftpd", false)
      @directory = Ops.get_string(settings, "tftp_directory", "")
      @other_args = ""

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
    publish :variable => :other_args, :type => "string"
    publish :variable => :foreign_servers, :type => "string"
    publish :function => :ParseServerArgs, :type => "void (string)"
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
