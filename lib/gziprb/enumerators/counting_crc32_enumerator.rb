# frozen_string_literal: true
require 'zlib'
module Enumerators
  # An Enumerator that wraps another Enumerator, maintaining a count and running CRC32 of each byte
  # read from the input Enumerator. Does _not_ enforce that each element is actually a byte.
  class CountingCrc32Enumerator
    attr_reader :enumerator

    def initialize(input)
      @summary_data = summary_data = { count: 0, crc32: Zlib.crc32 }

      @enumerator = Enumerator.new do |enum|
        input.each do |byte|
          summary_data[:count] += 1
          summary_data[:crc32] = Zlib.crc32_combine(summary_data[:crc32], Zlib.crc32(byte.chr), 1)

          enum << byte
        end
      end
    end

    def count
      @summary_data.fetch(:count)
    end

    def crc32
      @summary_data.fetch(:crc32)
    end

    def self.yield_enumerator_and_return_summary(input_enumerator)
      counting_crc32_enum = new(input_enumerator)

      yield counting_crc32_enum.enumerator

      [counting_crc32_enum.count, counting_crc32_enum.crc32]
    end
  end
end
