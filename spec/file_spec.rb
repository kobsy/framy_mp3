require "spec_helper"

describe FramyMP3::File do
  attr_reader :file

  before(:each) do
    File.open File.join(File.dirname(__FILE__), "support", "files", "framy1.mp3"), "rb" do |f|
      @file = described_class.new(f)
    end
  end

  it "should parse the number of frames in the file" do
    expect(file.total_frames).to eq(101)
  end

  it "should sum the size of frames in the file" do
    expect(file.total_frame_bytes).to eq(52_767)
  end

  it "should determine if the file is variable bitrate" do
    expect(file.vbr?).to be false
  end

  it "should find any id3v2 tags" do
    expect(file.id3v2_tag).to be_instance_of(FramyMP3::ID3Tag)
  end

  it "should find any id3v1 tags" do
    # TODO: Add ID3v1 tag to sample file
    expect(file.id3v1_tag).to be_nil
  end

  context "#to_blob" do
    it "should reassemble the frames into a correct mp3 file" do
      new_file = described_class.new(StringIO.new(file.to_blob, "rb"))
      expect(new_file).to be_instance_of(described_class)
      expect(new_file.total_frames).to eq(100)
    end

    it "should strip out existing xing header frames by default" do
      xing_header_data = file.frames.select(&:xing_header?).map(&:data)
      new_file = described_class.new(StringIO.new(file.to_blob, "rb"))
      expect(new_file.frames.map(&:data)).not_to include(xing_header_data.first)
    end

    it "should include a new xing header frame by default" do
      new_file = described_class.new(StringIO.new(file.to_blob, "rb"))
      expect(new_file.frames.any?(&:xing_header?)).to be true
    end

    it "should allow leaving in existing xing headers if specified" do
      xing_header_data = file.frames.select(&:xing_header?).map(&:data)
      new_file = described_class.new(StringIO.new(file.to_blob(keep_xing_headers: true), "rb"))
      expect(new_file.frames.map(&:data)).to include(xing_header_data.first)
    end
  end
end
