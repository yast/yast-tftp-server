require_relative "../test_helper"

require "cfa/memory_file"
require "cfa/tftp_sysconfig"

describe CFA::TftpSysconfig do
  let(:file_handler) do
    file_path = File.expand_path("../../data/tftp_sysconfig", __FILE__)
    CFA::MemoryFile.new(File.read(file_path))
  end

  subject do
    described_class.new(file_handler: file_handler)
  end

  before do
    subject.load
  end

  describe "#load" do
    it "loads all attributes" do
      expect(subject.user).to eq "tftp"
      expect(subject.directory).to eq "/srv/tftpboot"
      expect(subject.options).to eq ""
    end
  end

  describe "#save" do
    it "stores properly attributes" do
      subject.user = "root"
      subject.save

      expect(file_handler.content.lines).to include("TFTP_USER=\"root\"\n")
    end
  end
end
