# frozen_string_literal: true
require 'spec_helper'

describe InflateInputBuffer do
  # 0xCA is 11001010 and 0x53 is 01010011
  let(:input_buffer) { InflateInputBuffer.new(StringIO.new("\xCA\x53")) }

  it 'only reads from the underlying io on demand' do
    dummy_io = object_double(StringIO.new(''))
    allow(dummy_io).to receive(:eof?).and_return(false)
    allow(dummy_io).to receive(:read) { raise 'urk' }

    expect { InflateInputBuffer.new(dummy_io) }.to_not raise_error
  end

  describe '#eof?' do
    it 'is true if an empty StringIO is passed in' do
      expect(InflateInputBuffer.new(StringIO.new).eof?).to eq true
    end

    it 'is not true if the StringIO is not empty' do
      expect(InflateInputBuffer.new(StringIO.new("\xF0")).eof?).to eq false
    end

    it 'is true after all the bits have been read' do
      expect {
        16.times { input_buffer.read_bit }
      }.to change { input_buffer.eof? }.from(false).to(true)
    end
  end

  describe '#read_bit_string' do
    it 'is correct' do
      expect(input_buffer.read_bit_string(4)).to eq '1010'
      expect(input_buffer.read_bit_string(4)).to eq '1100'
      expect(input_buffer.read_bit_string(4)).to eq '0011'
      expect(input_buffer.read_bit_string(4)).to eq '0101'
    end

    it 'handles non-even read counts' do
      expect(input_buffer.read_bit_string(3)).to eq '010'
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 0
      expect(input_buffer.read_bit_string(6)).to eq '011110'
    end
  end

  describe '#read_number' do
    it 'is correct' do
      expect(input_buffer.read_number(4)).to eq 10
      expect(input_buffer.read_number(3)).to eq 4
      expect(input_buffer.read_number(2)).to eq 3
      expect(input_buffer.read_number(1)).to eq 1
      expect(input_buffer.read_number(6)).to eq 20
    end
  end

  describe '#read_bit_string' do
    it 'is correct' do
      expect(input_buffer.read_bit).to eq 0
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 0
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 0
      expect(input_buffer.read_bit).to eq 0
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 1
      expect(input_buffer.read_bit).to eq 0
      expect(input_buffer.read_bit).to eq 0
    end
  end

  describe '#read_raw_bytes' do
    it 'yields each byte if passed a block' do
      all = []

      input_buffer.read_raw_bytes(2) { |b| all << b }

      expect(all).to eq [0xCA, 0x53]
    end

    it 'returns an Enumerator if not passed a block' do
      raw = input_buffer.read_raw_bytes(2)

      expect(raw).to be_a(Enumerator)

      expect(raw.to_a).to eq [0xCA, 0x53]
    end

    it 'raises if the input is empty' do
      expect {
        InflateInputBuffer.new(StringIO.new('')).read_raw_bytes(10).to_a
      }.to raise_error(/eof/)
    end

    it 'raises if there are fewer bytes than demanded' do
      expect { input_buffer.read_raw_bytes(10).to_a }.to raise_error(/eof/)
    end

    it 'can be called multiple times' do
      expect(input_buffer.read_raw_bytes(1).to_a).to eq [0xCA]
      expect(input_buffer.read_raw_bytes(1).to_a).to eq [0x53]
    end
  end

  describe '#read_to_end_of_current_byte' do
    (1..7).each do |bits_read|
      it "is correct with #{bits_read} already read of the current byte" do
        bits_read.times { input_buffer.read_bit }

        input_buffer.read_to_end_of_current_byte

        expect(input_buffer.read_bit_string(8)).to eq '01010011'
      end
    end
  end
end
