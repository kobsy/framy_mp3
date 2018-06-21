require "spec_helper"

describe FramyMP3 do
  attr_reader :file1, :file2, :merged_file

  context ".merge" do
    before(:each) do
      File.open File.join(File.dirname(__FILE__), "support", "files", "framy1.mp3"), "rb" do |f|
        @file1 = FramyMP3::File.new(f)
      end
      File.open File.join(File.dirname(__FILE__), "support", "files", "framy2.mp3"), "rb" do |f|
        @file2 = FramyMP3::File.new(f)
      end
    end

    it "should return one combined file" do
      merge!
      expect(merged_file).to be_instance_of(FramyMP3::File)
    end

    it "should produce a file with the combined number of frames" do
      merge!
      expected_frame_count = file1.frames.count + file2.frames.count
      expect(merged_file.total_frames).to eq(expected_frame_count)
    end

    it "should produce a new XING header and remove existing ones by default when calling #to_blob on the new file" do
      merge!
      new_file = FramyMP3::File.new(StringIO.new(merged_file.to_blob, "rb"))
      expect(new_file.frames.select(&:xing_header?).count).to eq(1)
    end

    it "should use the ID3v2 tag from the first file, if it exists" do
      merge!
      expect(merged_file.id3v2_tag.data).to eq(file1.id3v2_tag.data)
    end
  end

private

  def merge!
    @merged_file = described_class.merge(file1, file2)
  end
end
