# encoding: utf-8

# File:	include/tftp-server/wizards.ycp
# Package:	Configuration of tftp-server
# Summary:	Wizards definitions
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  module TftpServerWizardsInclude
    def initialize_tftp_server_wizards(include_target)
      Yast.import "UI"

      textdomain "tftp-server"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "tftp-server/dialogs.rb"
    end

    # Whole configuration of tftp-server
    # @return sequence result
    def TftpServerSequence
      aliases = {
        "packages" => [lambda { Packages() }, true],
        "read"     => [lambda { ReadDialog() }, true],
        "main"     => lambda { MainDialog() },
        "write"    => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "packages",
        "packages" => { :next => "read", :abort => :abort },
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      # Tftp-server dialog caption
      caption = _("TFTP Server Configuration")

      # progress label
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("tftp-server")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      Convert.to_symbol(ret)
    end

    # Whole configuration of tftp-server
    # @return sequence result
    def TftpServerAutoSequence
      aliases = { "packages" => [lambda { Packages() }, true], "main" => lambda do
        MainDialog()
      end }

      sequence = {
        "ws_start" => "packages",
        "packages" => { :next => "main" },
        "main"     => { :abort => :abort, :next => :next }
      }

      # Tftp-server dialog caption
      caption = _("TFTP Server Configuration")

      # progress label
      contents = Label(_("Initializing ..."))

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("tftp-server")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      Convert.to_symbol(ret)
    end
  end
end
