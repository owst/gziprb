# frozen_string_literal: true
require 'spec_helper'

module Enumerators
  describe CountingCrc32Enumerator do
    context 'with no inputs bytes' do
      it 'yields nothing and has a 0 count and empty CRC32' do
        enum = CountingCrc32Enumerator.new(StringIO.new('').each_byte)

        expect(enum.enumerator.to_a).to be_empty
        expect(enum.count).to eq 0
        expect(enum.crc32).to eq Zlib.crc32
      end
    end

    context 'with input bytes' do
      it 'yields the bytes and correctly counts and builds the correct CRC32 value' do
        str = "\x01\x02\x03"
        enum = CountingCrc32Enumerator.new(StringIO.new(str).each_byte)

        expect(enum.enumerator.to_a).to eq [1, 2, 3]
        expect(enum.count).to eq 3
        expect(enum.crc32).to eq Zlib.crc32(str)
      end
    end
  end
end
