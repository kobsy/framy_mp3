require "framy_mp3/version"
require "framy_mp3/frame"
require "framy_mp3/id3_tag"
require "framy_mp3/file"

module FramyMP3

  def self.merge(*files)
    raise ArgumentError, "all files must be FramyMP3::File" if files.any? { |file| !file.is_a?(FramyMP3::File) }
    raise ArgumentError, "expected at least one file" unless files.count.positive?
    outfile = files.first.dup
    files[1..-1].each do |file|
      outfile.frames.push(*file.frames)
    end
    outfile
  end

end
