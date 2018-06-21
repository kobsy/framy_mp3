require "framy_mp3/frame"
require "framy_mp3/id3_tag"

module FramyMP3
  class File
    attr_reader :frames, :tags

    def initialize(stream)
      @stream = stream
      @frames = []
      @tags = []

      while (object = next_object)
        frames << object if object.frame?
        tags << object if object.tag?
      end
    end

    def to_blob(options={})
      blob = ""

      keep_xing_headers = vbr? ? false : options.fetch(:keep_xing_headers, false)

      StringIO.open(blob, "wb") do |outfile|
        initial_tag = id3v2_tag
        outfile << initial_tag.data unless initial_tag.nil?
        outfile << xing_header.data unless keep_xing_headers
        (keep_xing_headers ? frames : frames.reject(&:xing_header?)).each do |frame|
          outfile << frame.data
        end
        closing_tag = id3v1_tag
        outfile << closing_tag.data unless closing_tag.nil?
      end

      blob
    end
    alias to_s to_blob

    def variable_bitrate?
      initial_bitrate = frames.first.bitrate
      frames[1..-1].any? do |frame|
        frame.bitrate != initial_bitrate
      end
    end
    alias vbr? variable_bitrate?

    def id3v2_tag
      tags.find(&:v2?)
    end

    def id3v1_tag
      tags.find(&:v1?)
    end

    def total_frames
      frames.count
    end

    def total_frame_bytes
      frames.map { |frame| frame.data.bytesize }.sum
    end

  private
    attr_reader :stream

    def next_frame
      while (object = next_object)
        return object if object.frame?
      end
    end

    def next_id3v2_tag
      while (object = next_object)
        return object if object.tag? && object.v2?
      end
    end

    def next_object
      buffer = stream.read(4)&.unpack("C*")
      return if buffer.nil? # EOF

      loop do
        # Check for an ID3v1 Tag
        if buffer[0] == 84 && buffer[1] == 65 && buffer[2] == 71
          tag_data = buffer.pack("C*")
          remaining_data = stream.read(124)
          return if remaining_data.nil?
          tag_data << remaining_data
          return ID3Tag.new(1, tag_data)
        end

        # Check for an ID3v2 Tag
        if buffer[0] == 73 && buffer[1] == 68 && buffer[2] == 51
          # Read the remainder of the 10-byte tag header
          remainder = stream.read(6).unpack("C*")
          return nil if remainder.nil?

          # The last 4 bytes of the header indicate the length of the tag.
          # This length does not include the header itself.
          tag_length =
            (remainder[2] << (7 * 3)) |
            (remainder[3] << (7 * 2)) |
            (remainder[4] << (7 * 1)) |
            (remainder[5] << (7 * 0))

          tag_data = buffer.pack("C*")
          tag_data << remainder.pack("C*")
          remaining_data = stream.read(tag_length)
          return if remaining_data.nil?
          tag_data << remaining_data
          return ID3Tag.new(2, tag_data)
        end

        # Check for a frame header, indicated by an 11-bit frame-sync sequence.
        if buffer[0] == 0xFF && (buffer[1] & 0xE0) == 0xE0
          begin
            frame = Frame.new(buffer)
            frame.data = buffer.pack("C*")
            frame.data << stream.read(frame.length - 4)
            return frame
          rescue InvalidFrameError
            # For the time being, we'll simply ignore invalid frames...
          end
        end

        # Nothing found. Shift the buffer forward by one byte and try again.
        buffer.shift
        next_byte = stream.read(1)&.unpack("C")&.first
        return if next_byte.nil?
        buffer << next_byte
      end
    end

    def xing_header
      frames.first&.to_xing_header(total_frames: total_frames, total_bytes: total_frame_bytes)
    end

  end
end
