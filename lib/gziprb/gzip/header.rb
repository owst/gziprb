# frozen_string_literal: true
module Gzip
  Header = Struct.new(:compression, :flags, :mtime, :optional_fields, :xfl, :os) do
    include IOUtils
    extend IOUtils

    MAGIC = [0x1f, 0x8b].freeze

    COMPRESSION_TYPES = [DEFLATE_COMPRESSION = 0x8].freeze

    FLAGS = %i(
      FTEXT
      FHCRC
      FEXTRA
      FNAME
      FCOMMENT
      FRESERVED1
      FRESERVED2
      FRESERVED3
    ).freeze

    EMPTY_FLAGS = FLAGS.map { |f| [f, false] }.to_h

    UNIX_OS = 3

    def write(io)
      io.write(MAGIC.pack('CC'))
      write_byte(io, compression)
      write_byte(io, flags.values.map { |b| b ? 1 : 0 }.reverse.join.to_i(2))
      write_32_bit_le(io, mtime)
      write_byte(io, xfl)
      write_byte(io, os)

      if flags[:FEXTRA]
        write_16_bit_le(io, optional_fields[:FEXTRA].length)
        io.write(optional_fields[:FEXTRA])
      end

      write_zero_terminated_string(io, optional_fields[:FNAME]) if flags[:FNAME]
      write_zero_terminated_string(io, optional_fields[:FCOMMENT]) if flags[:FCOMMENT]
      write_16_bit_le(io, optional_fields[:FHCRC]) if flags[:FHCRC]
    end

    class << self
      def parse(io)
        magic = io.read(2).unpack('CC')
        raise "Couldn't find magic bytes" unless magic == MAGIC

        compression = read_byte(io)

        unless compression == DEFLATE_COMPRESSION
          raise 'Only deflate compression method is supported!'
        end

        flags = parse_flags(io)

        mtime = Time.at(read_32_bit_le(io))

        xfl = read_byte(io)
        os = read_byte(io)

        new(compression, flags, mtime, parse_optional_fields(flags, io), xfl, os)
      end

      def parse_flags(io)
        flag_bits = format('%08b', read_byte(io)).chars.reverse.map(&:to_i)

        flag_bits.zip(FLAGS).each_with_object({}) do |(c, flag), fs|
          fs[flag] = c == 1
        end
      end

      def parse_optional_fields(flags, io)
        {}.tap do |optional_fields|
          optional_fields[:FEXTRA] = io.read(io.read(2).unpack('v')[0]) if flags[:FEXTRA]
          optional_fields[:FNAME] = read_zero_terminated_string(io) if flags[:FNAME]
          optional_fields[:FCOMMENT] = read_zero_terminated_string(io) if flags[:FCOMMENT]
          optional_fields[:FHCRC] = io.read(2).unpack('v')[0] if flags[:FHCRC]
        end
      end

      def for(input_filename, input)
        input_stat = input_filename != '-' ? input.stat : nil

        flags = EMPTY_FLAGS
        optional_fields = {}
        if input_filename != '-'
          flags[:FNAME] = true
          optional_fields[:FNAME] = input_filename
        end

        mtime = input_stat ? input_stat.mtime.to_i : 0

        # We could implement proper OS detection, but gzip on mac seems to report Unix anyway.
        new(DEFLATE_COMPRESSION, flags, mtime, optional_fields, 0, UNIX_OS)
      end
    end
  end
end
