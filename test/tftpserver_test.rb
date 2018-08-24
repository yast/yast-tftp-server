#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "TftpServer"

describe "Yast::TftpServer" do
  describe "#Write" do
    subject(:tftp_server) { Yast::TftpServerClass.new }

    before do
      allow(Yast2::SystemService).to receive(:find).with("tftp").and_return(service)

      allow(Yast2::Systemd::Service).to receive(:find!).with("tftp").and_return(systemd_service)

      allow(Yast2::Systemd::Socket).to receive(:find!).with("tftp").and_return(socket)

      allow(Y2Firewall::Firewalld).to receive(:instance).and_return(firewalld)

      allow(CFA::TftpSysconfig).to receive(:new).and_return(sysconfig)

      allow(Yast::SCR).to receive(:Execute)

      allow(Yast::Mode).to receive(:auto) { auto }
      allow(Yast::Mode).to receive(:commandline) { commandline }

      tftp_server.main
    end

    let(:service) { instance_double(Yast2::SystemService, save: true) }

    let(:systemd_service) { instance_double(Yast2::Systemd::Service, stop: true) }

    let(:socket) { instance_double(Yast2::Systemd::Socket, enable: true, disable: true, start: true, stop: true) }

    let(:sysconfig) do
      instance_double(
        CFA::TftpSysconfig,
        directory: "/path/to/boot_image_directory",
        :directory= => nil,
        save: true,
        user: nil
      )
    end

    let(:firewalld) { instance_double(Y2Firewall::Firewalld, write_only: true, reload: true) }

    let(:auto) { false }
    let(:commandline) { false }

    shared_examples "old behavior" do
      it "does not save the system service" do
        expect(service).to_not receive(:save)

        tftp_server.Write
      end

      it "stops the systemd service" do
        expect(systemd_service).to receive(:stop)

        tftp_server.Write
      end

      context "when the socket should not be started" do
        before do
          allow(tftp_server).to receive(:start).and_return(false)
        end

        it "disables the socket" do
          expect(socket).to receive(:disable)

          tftp_server.Write
        end

        it "stops the socket" do
          expect(socket).to receive(:stop)

          tftp_server.Write
        end
      end

      context "when the socket should be started" do
        before do
          allow(tftp_server).to receive(:start).and_return(true)
        end

        it "enables the socket" do
          expect(socket).to receive(:enable)

          tftp_server.Write
        end

        it "starts the socket" do
          expect(socket).to receive(:start)

          tftp_server.Write
        end
      end
    end

    context "when running in command line" do
      let(:commandline) { true }

      include_examples "old behavior"
    end

    context "when running in AutoYaST mode" do
      let(:auto) { true }

      include_examples "old behavior"
    end

    context "when running in normal mode" do
      it "does not stop the systemd service directly" do
        expect(systemd_service).to_not receive(:stop)

        tftp_server.Write
      end

      it "does not modify the systemd socket directly" do
        expect(socket).to_not receive(:enable)
        expect(socket).to_not receive(:disable)
        expect(socket).to_not receive(:start)
        expect(socket).to_not receive(:stop)

        tftp_server.Write
      end

      it "saves the system service" do
        expect(service).to receive(:save)

        tftp_server.Write
      end
    end
  end
end
