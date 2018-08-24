# encoding: utf-8

# File:	include/tftp-server/dialogs.ycp
# Package:	Configuration of tftp-server
# Summary:	Dialogs definitions
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$

require "y2journal"
require "yast2/service_widget"

module Yast
  module TftpServerDialogsInclude
    def initialize_tftp_server_dialogs(include_target)
      Yast.import "UI"

      textdomain "tftp-server"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "Label"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "TftpServer"
      Yast.import "Wizard"
    end

    # Check for required packaged to be installed
    #
    # @return [Symbol] :abort if aborted and :next otherwise
    def Packages
      return :abort if !Package.InstallAll(TftpServer.required_packages)

      :next
    end

    # Read settings dialog
    #
    # @return [Symbol] :abort if aborted and :next otherwise
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
    #
    # @return [Symbol] :abort if aborted and :next otherwise
    def WriteDialog
      ret = TftpServer.Write
      ret ? :next : :abort
    end

    # Main dialog
    #
    # @return [Symbol] dialog result (:next, :cancel, :abort)
    def MainDialog
      Wizard.SetScreenShotName("tftp-server-1-main")

      # start = TftpServer.start
      directory = TftpServer.directory
      changed = false

      # Tftp-server dialog caption
      caption = _("TFTP Server Configuration")

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      # Initialize the widget (set the current value)
      CWMFirewallInterfaces.OpenFirewallInit(firewall_widget, "")

      UI.ChangeWidget(Id(:viewlog), :Enabled, !Mode.config)

      result = handle_events

      Wizard.RestoreScreenShotName
      result
    end

  private

    # Dialog contents
    #
    # @return [Yast::Term]
    def contents
      HVSquash(
        VBox(
          service_widget.content,
          VSpacing(1),
          HBox(
            # Directory where served files (usually boot images) reside
            Bottom(TextEntry(Id(:directory), _("&Boot Image Directory"), TftpServer.directory)),
            HSpacing(0.5),
            # Select a directory from the filesystem
            Bottom(PushButton(Id(:browse), _("Bro&wse...")))
          ),
          VSpacing(1),
          firewall_widget["custom_widget"] || Empty(),
          VSpacing(2),
          # Display a log file
          PushButton(Id(:viewlog), _("&View Log"))
        )
      )
    end

    # Handles dialog events
    #
    # @return [Symbol] :next, :cancel, :abort
    def handle_events
      input = nil

      loop do
        event = UI.WaitForEvent
        input = event["ID"]

        # Handle the events, enable/disable the button, show the popup if button clicked
        CWMFirewallInterfaces.OpenFirewallHandle(firewall_widget, "", event)

        case input
        when :browse
          ask_directory
        when :viewlog
          show_log
        when :next
          if check_directory
            # Grab current settings, store them to SuSEFirewall::
            CWMFirewallInterfaces.OpenFirewallStore(firewall_widget, "", event)
            save_service
            break
          end
        when :cancel, :abort
          break if Popup.ReallyAbort(changes?)
        end
      end

      input
    end

    # Help text
    #
    # @return [String]
    def help
      _("<p><big><b>Configuring a TFTP Server</b></big></p>") +
        _("<p>Use this to enable a server for TFTP (trivial file transfer protocol). The server will be started using xinetd.</p>") +
        _("<p>Note that TFTP and FTP are not the same.</p>") +
        _(
          "<p><b>Boot Image Directory</b>:\n" +
            "Specify the directory where served files are located. The usual value is\n" +
            "<tt>/tftpboot</tt>. The directory will be created if it does not exist. \n" +
            "The server uses this as its root directory (using the <tt>-s</tt> option).</p>\n"
        ) +
        firewall_widget["help"] || ""
    end

    # Widget to define state and start mode of the service
    #
    # @return [Yast2::ServiceWidget]
    def service_widget
      @service_widget ||= Yast2::ServiceWidget.new(TftpServer.service)
    end

    # Firewall widget using CWM
    #
    # @return [Hash] see CWMFirewallInterfaces.CreateOpenFirewallWidget
    def firewall_widget
      @firewall_widget ||= CWMFirewallInterfaces.CreateOpenFirewallWidget(
        "services"        => ["tftp"],
        "display_details" => true
      )
    end

    # Value of the input field to indicate the Boot Image Directory
    #
    # @return [String]
    def directory
      UI.QueryWidget(Id(:directory), :Value)
    end

    # Opens a dialog to ask for the directory
    #
    # @note The input field is updated with the selected directory.
    def ask_directory
      search_path = directory.empty? ? "/" : directory

      directory = UI.AskForExistingDirectory(search_path, "")
      UI.ChangeWidget(Id(:directory), :Value, directory)
    end

    # Asks whether to create the directory (usefull when the directory does not exist)
    #
    # @return [Boolean]
    def ask_create_directory
      Popup.YesNo(Message.DirectoryDoesNotExistCreate(directory))
    end

    # Checks whether the given path is valid, and if so, it asks for creating the directory
    # when it does not exist yet
    #
    # @return [Boolean] true when the given path is valid and exists (or should be created);
    #   false otherwise.
    def check_directory
      if !valid_directory?
        show_directory_error
        false
      elsif !exist_directory?
        ask_create_directory
      else
        true
      end
    end

    # Checks whether the given directory path is valid
    #
    # @return [Boolean]
    def valid_directory?
      directory.start_with?("/") && !directory.match?(/[ \t]/)
    end

    # Checks whether the given directory path already exists
    #
    # @return [Boolean]
    def exist_directory?
      return true if Mode.config

      SCR.Read(path(".target.size"), directory) >= 0
    end

    # Opens a popup to indicate the error when the given directory path is not valid
    def show_directory_error
      message = _("The directory must start with a slash (/)\nand must not contain spaces.")

      Popup.Error(message)
    end

    # Shows both service and socket logs since current boot
    def show_log
      query = Y2Journal::Query.new(interval: "0", filters: { "unit" => ["tftp.service", "tftp.socket"] })
      Y2Journal::EntriesDialog.new(query: query).run
    end

    # Whether something has been edited
    #
    # @note Changes in the Service Widget are not taken into account.
    #
    # @return [Boolean]
    def changes?
      CWMFirewallInterfaces.OpenFirewallModified("") || directory != TftpServer.directory
    end

    # Saves the service changes
    def save_service
      service_widget.store
      TftpServer.start = TftpServer.service.active?
      TftpServer.directory = directory
    end
  end
end
