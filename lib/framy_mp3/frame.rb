module FramyMP3

  class InvalidFrameError < ArgumentError; end

  class Frame
    attr_reader :header
    attr_accessor :data

    MPEG_VERSION_2_5 = 0
    MPEG_VERSION_RESERVED = 1
    MPEG_VERSION_2 = 2
    MPEG_VERSION_1 = 3

    MPEG_LAYER_RESERVED = 0
    MPEG_LAYER_III = 1
    MPEG_LAYER_II = 2
    MPEG_LAYER_I = 3

    CHANNEL_MODE_STEREO = 0
    CHANNEL_MODE_JOINT_STEREO = 1
    CHANNEL_MODE_DUAL = 2
    CHANNEL_MODE_MONO = 3

    BITRATES = {
      MPEG_VERSION_1 => {
        MPEG_LAYER_I => [ 0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448 ],
        MPEG_LAYER_II => [ 0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384 ],
        MPEG_LAYER_III => [ 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 ]
      },
      MPEG_VERSION_2 => {
        MPEG_LAYER_I => [ 0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256 ],
        MPEG_LAYER_II => [ 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 ],
        MPEG_LAYER_III => [ 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 ]
      }
    }.freeze

    SAMPLE_RATES = {
      MPEG_VERSION_1 => [ 44_100, 48_000, 32_000 ],
      MPEG_VERSION_2 => [ 22_050, 24_000, 16_000 ],
      MPEG_VERSION_2_5 => [ 11_025, 12_000, 8_000 ]
    }.freeze

    SAMPLES_PER_FRAME = {
      MPEG_VERSION_1 => {
        MPEG_LAYER_I => 384,
        MPEG_LAYER_II => 1152,
        MPEG_LAYER_III => 1152
      },
      MPEG_VERSION_2 => {
        MPEG_LAYER_I => 384,
        MPEG_LAYER_II => 1152,
        MPEG_LAYER_III => 576
      }
    }.freeze

    def initialize(header)
      @header = header
      raise InvalidFrameError, "Invalid MPEG version" unless valid_mpeg_version?
      raise InvalidFrameError, "Invalid MPEG layer" unless valid_mpeg_layer?
      raise InvalidFrameError, "Bitrate index out of range" unless valid_bitrate_index?
      raise InvalidFrameError, "Sample rate index out of range" unless valid_sample_rate_index?
      raise InvalidFrameError, "Mode extension can only be used with joint stereo mode" unless valid_mode_extension?
      raise InvalidFrameError, "Invalid emphasis" unless valid_emphasis?
    end

    def frame?
      true
    end

    def tag?
      false
    end

    def mpeg_version
      return @mpeg_version if defined?(@mpeg_version)
      @mpeg_version = (header[1] & 0x18) >> 3 # 2 bits
    end

    def valid_mpeg_version?
      mpeg_version != MPEG_VERSION_RESERVED
    end

    def major_mpeg_version
      return @major_mpeg_version if defined?(@major_mpeg_version)
      @major_mpeg_version = mpeg_version == MPEG_VERSION_1 ? MPEG_VERSION_1 : MPEG_VERSION_2
    end

    def mpeg_layer
      return @mpeg_layer if defined?(@mpeg_layer)
      @mpeg_layer = (header[1] & 0x06) >> 1 # 2 bits
    end

    def valid_mpeg_layer?
      mpeg_layer != MPEG_LAYER_RESERVED
    end

    def crc_protection?
      return @crc_protection if defined?(@crc_protection)
      @crc_protection = (header[1] & 0x01).zero? # 1 bit
    end

    def bitrate_index
      return @bitrate_index if defined?(@bitrate_index)
      @bitrate_index = (header[2] & 0xF0) >> 4 # 4 bits
    end

    def valid_bitrate_index?
      bitrate_index.positive? && bitrate_index < 15
    end

    def sample_rate_index
      return @sample_rate_index if defined?(@sample_rate_index)
      @sample_rate_index = (header[2] & 0x0C) >> 2 # 2 bits
    end

    def valid_sample_rate_index?
      sample_rate_index < 3
    end

    def padded?
      return @padding_bit if defined?(@padding_bit)
      @padding_bit = (header[2] & 0x02) == 2 # 1 bit
    end

    def private_bit
      return @private_bit if defined?(@private_bit)
      @private_bit = (header[2] & 0x01) == 1 # 1 bit
    end

    def channel_mode
      return @channel_mode if defined?(@channel_mode)
      @channel_mode = (header[3] & 0xC0) >> 6 # 2 bits
    end

    def mode_extension
      return @mode_extension if defined?(@mode_extension)
      @mode_extension = (header[3] & 0x30) >> 4 # 2 bits
    end

    def valid_mode_extension?
      # Mode extension. Valid only for Joint Stereo mode
      mode_extension.zero? || channel_mode == CHANNEL_MODE_JOINT_STEREO
    end

    def copyrighted?
      return @copyright_bit if defined?(@copyright_bit)
      @copyright_bit = (header[3] & 0x08) == 0x08 # 1 bit
    end

    def original?
      return @original_bit if defined?(@original_bit)
      @original_bit = (header[3] & 0x04) == 0x04 # 1 bit
    end

    def emphasis
      return @emphasis if defined?(@emphasis)
      @emphasis = header[3] & 0x03 # 2 bits
    end

    def valid_emphasis?
      emphasis < 2
    end

    def bitrate
      BITRATES[major_mpeg_version][mpeg_layer][bitrate_index] * 1000
    end

    def sample_rate
      SAMPLE_RATES[mpeg_version][sample_rate_index]
    end

    def sample_count
      # Number of samples in the frame; we need this to determine the frame size
      SAMPLES_PER_FRAME[major_mpeg_version][mpeg_layer]
    end

    def padding
      # If the padding bit is set we add an extra 'slot' to the frame length.
      # A layer I slot is 4 bytes long; layer II and III slots are 1 byte long.
      return 0 unless padded?
      mpeg_layer == MPEG_LAYER_I ? 4 : 1
    end

    def length
      # From mp3lib:
      #   Calculate the frame length in bytes. There's a lot of confusion online
      #   about how to do this and definitive documentation is hard to find. The
      #   basic formula seems to boil down to:
      #
      #       bytes_per_sample = (bit_rate / sampling_rate) / 8
      #       frame_length = sample_count * bytes_per_sample + padding
      #
      #   In practice we need to rearrange this formula to avoid rounding errors.
      #
      #   I can't find any definitive statement on whether this length is
      #   supposed to include the 4-byte header and the optional 2-byte CRC.
      #   Experimentation on mp3 files captured from the wild indicates that it
      #   includes the header at least.
      (sample_count / 8) * bitrate / sample_rate + padding
    end

    def side_information_size
      return unless mpeg_layer == MPEG_LAYER_III
      return channel_mode == CHANNEL_MODE_MONO ? 17 : 32 if mpeg_version == MPEG_VERSION_1
      channel_mode == CHANNEL_MODE_MONO ? 9 : 17
    end

    def xing_header?
      # The Xing header begins directly after the side information block. We
      # also need to allow 4 bytes for the frame header
      offset = 4 + side_information_size
      identifier = data.unpack("C#{offset + 4}")[-4, 4].pack("C4")
      identifier == "Xing" || identifier == "Info"
    end

    def vbri_header?
      # The VBRI header begins after a fixed 32-byte offset. We also need to
      # allow 4 bytes for the frame header
      data.unpack("C40")[-4, 4].pack("C4") == "VBRI"
    end

  end
end
