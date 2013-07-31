# encoding: utf-8

# File:	include/tftp-server/dialogs.ycp
# Package:	Configuration of tftp-server
# Summary:	Dialogs definitions
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  module TftpServerDialogsInclude
    def initialize_tftp_server_dialogs(include_target)
      Yast.import "UI"

      textdomain "tftp-server"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "Label"
      Yast.import "LogView"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "TftpServer"
      Yast.import "Wizard"
    end

    # Check for required packaged to be installed
    # @return `abort if aborted and `next otherwise

    def Packages
      return :abort if !Package.InstallAll(TftpServer.required_packages)

      :next
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      ret = true

      ret = ret && TftpServer.Read

      if TftpServer.foreign_servers != ""
        Popup.Error(TftpServer.ForeignServersError)
        ret = false
      end
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      ret = TftpServer.Write
      ret ? :next : :abort
    end

    # Main dialog
    # @return dialog result
    def MainDialog
      Wizard.SetScreenShotName("tftp-server-1-main")

      start = TftpServer.start
      directory = TftpServer.directory
      changed = false

      # Tftp-server dialog caption
      caption = _("TFTP Server Configuration")

      # firewall widget using CWM
      fw_settings = {
        "services"        => ["service:tftp"],
        "display_details" => true
      }
      fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        fw_settings
      )

      # dialog help text
      help_text = _("<p><big><b>Configuring a TFTP Server</b></big></p>")
      # dialog help text
      help_text = Ops.add(
        help_text,
        _(
          "<p>Use this to enable a server for TFTP (trivial file transfer protocol). The server will be started using xinetd.</p>"
        )
      )
      # enlighten newbies, #102946
      # dialog help text
      help_text = Ops.add(
        help_text,
        _("<p>Note that TFTP and FTP are not the same.</p>")
      )
      # dialog help text
      help_text = Ops.add(
        help_text,
        _(
          "<p><b>Boot Image Directory</b>:\n" +
            "Specify the directory where served files are located. The usual value is\n" +
            "<tt>/tftpboot</tt>. The directory will be created if it does not exist. \n" +
            "The server uses this as its root directory (using the <tt>-s</tt> option).</p>\n"
        )
      )
      help_text = Ops.add(help_text, Ops.get_string(fw_cwm_widget, "help", ""))

      contents = HVSquash(
        VBox(
          RadioButtonGroup(
            Id(:rbg),
            VBox(
              Left(
                RadioButton(
                  Id(:tftpno),
                  Opt(:notify),
                  # Radio button label, disable TFTP server
                  _("&Disable"),
                  !start
                )
              ),
              Left(
                RadioButton(
                  Id(:tftpyes),
                  Opt(:notify),
                  # Radio button label, disable TFTP server
                  _("&Enable"),
                  start
                )
              )
            )
          ),
          VSpacing(1),
          TextAndButton(
            # Text entry label
            # Directory where served files (usually boot images) reside
            TextEntry(Id(:directory), _("&Boot Image Directory"), directory),
            # push button label
            # select a directory from the filesystem
            PushButton(Id(:browse), _("Bro&wse..."))
          ),
          VSpacing(1),
          Ops.get_term(fw_cwm_widget, "custom_widget", Empty()),
          VSpacing(2),
          # push button label
          # display a log file
          PushButton(Id(:viewlog), _("&View Log"))
        )
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        help_text,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      # initialize the widget (set the current value)
      CWMFirewallInterfaces.OpenFirewallInit(fw_cwm_widget, "")

      UI.ChangeWidget(Id(:viewlog), :Enabled, !Mode.config)
      event = nil
      ret = nil
      begin
        UI.ChangeWidget(Id(:directory), :Enabled, start)
        UI.ChangeWidget(Id(:browse), :Enabled, start)

        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        ret = :abort if ret == :cancel

        # handle the events, enable/disable the button, show the popup if button clicked
        CWMFirewallInterfaces.OpenFirewallHandle(fw_cwm_widget, "", event)

        start = UI.QueryWidget(Id(:rbg), :CurrentButton) == :tftpyes
        directory = Convert.to_string(UI.QueryWidget(Id(:directory), :Value))

        # discard the difference in disabled fields:
        # directory is only considered if start is on
        changed = CWMFirewallInterfaces.OpenFirewallModified("") ||
          start != TftpServer.start || # "" because method doesn't use parameter at all, nice :(
          start && directory != TftpServer.directory

        if ret == :browse
          directory = UI.AskForExistingDirectory(
            directory != "" ? directory : "/",
            ""
          )
          UI.ChangeWidget(Id(:directory), :Value, directory) if directory != nil
        elsif ret == :viewlog
          LogView.DisplayFiltered("/var/log/messages", "\\(tftp\\|TFTP\\)")
        end

        # validity checks
        if ret == :next && start
          if CheckDirectorySyntax(directory)
            #ok, say that it will be created
            if !Mode.config &&
                Ops.less_than(SCR.Read(path(".target.size"), directory), 0)
              # the dir does not exist
              ret = Popup.YesNo(Message.DirectoryDoesNotExistCreate(directory)) ? ret : nil
            end
          else
            UI.SetFocus(Id(:directory))
            # error popup
            Popup.Error(
              _(
                "The directory must start with a slash (/)\nand must not contain spaces."
              )
            )
            ret = nil
          end
        end
      end until ret == :next ||
        (ret == :back || ret == :abort) && (!changed || Popup.ReallyAbort(true))

      if ret == :next
        # grab current settings, store them to SuSEFirewall::
        CWMFirewallInterfaces.OpenFirewallStore(fw_cwm_widget, "", event)

        TftpServer.start = start
        TftpServer.directory = directory if start
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end
    def TextAndButton(text, button)
      text = deep_copy(text)
      button = deep_copy(button)
      HBox(Bottom(text), HSpacing(0.5), Bottom(button))
    end
    def CheckDirectorySyntax(dir)
      Builtins.substring(dir, 0, 1) == "/" &&
        Builtins.filterchars(" \t", dir) == ""
    end
  end
end
