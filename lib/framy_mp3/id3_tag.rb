module FramyMP3
  class ID3Tag
    attr_reader :version, :data

    def initialize(version, data)
      raise ArgumentError, "version must be either 1 or 2" unless [ 1, 2 ].include?(version)
      @version = version
      @data = data
    end

    def tag?
      true
    end

    def frame?
      false
    end

    def version_1?
      version == 1
    end
    alias v1? version_1?

    def version_2?
      version == 2
    end
    alias v2? version_2?

  end
end
