# frozen_string_literal: true
require_rel 'header'

module Gzip
  extend IOUtils

  class InvalidGzipStreamError < StandardError; end

  class << self
    def compress(input_filename, input)
      input.binmode
      output = compress_target(input_filename)

      Gzip::Header.for(input_filename, input).write(output)

      bytes_compressed, crc32 = Deflate::Deflate.deflate(input.each_byte) do |compressed_byte|
        output.write([compressed_byte].pack('C'))
      end

      isize = bytes_compressed % 2 ** 32

      write_32_bit_le(output, crc32)
      write_32_bit_le(output, isize)
    end

    def decompress(input_filename, input)
      header = Gzip::Header.parse(input)

      output = decompress_target(input_filename, header.optional_fields)

      byte_count, crc32 = Deflate::Inflate.inflate(input) do |decompressed_byte|
        output.write([decompressed_byte].pack('C'))
      end

      isize = byte_count % 2 ** 32

      expected_crc32 = read_32_bit_le(input)
      expected_isize = read_32_bit_le(input)

      return if crc32 == expected_crc32 && byte_count % 2 ** 32 == expected_isize

      raise(
        InvalidGzipStreamError,
        "invalid stream, expected: #{[expected_isize, expected_crc32]}, got: #{[isize, crc32]}"
      )
    end

    private

    def compress_target(input_filename)
      if input_filename != '-'
        File.open("#{input_filename}.gz", 'w')
      else
        STDOUT
      end
    end

    def decompress_target(input_filename, optional_fields)
      if optional_fields.key?(:FNAME)
        File.open(optional_fields[:FNAME], 'w')
      elsif input_filename != '-'
        File.open(input_filename.sub(/.gz$/, ''), 'w')
      else
        STDOUT
      end
    end
  end
end
