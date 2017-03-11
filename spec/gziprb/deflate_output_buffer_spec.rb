# frozen_string_literal: true
require 'spec_helper'

describe DeflateOutputBuffer do
  let(:arr) { [] }
  let(:packer) { DeflateOutputBuffer.new { |b| arr << b } }

  it 'is correct when pushing individual bits' do
    [1, 1, 1, 1, 0, 0, 0, 0, 1, 0].each do |bit|
      packer.push_bit(bit)
    end
    packer.finalize

    expect(arr).to eq([0x0F, 0x01])
  end

  it 'is correct when pushing multiple bits in lsb-first order' do
    packer.push_bits([1, 0, 1, 1], first_bit: :lsb)
    packer.finalize

    expect(arr).to eq [11]
  end

  it 'is correct when pushing multiple bits in msb-first order' do
    packer.push_bits([1, 0, 1, 1], first_bit: :msb)
    packer.finalize

    expect(arr).to eq [13]
  end

  it 'is correct when pushing a bit string in lsb-first order' do
    packer.push_bit_string(0b10101100.to_s(2), first_bit: :lsb)
    packer.finalize

    expect(arr).to eq [0b10101100]
  end

  it 'is correct when pushing a bit string in msb-first order' do
    packer.push_bit_string(0b10101100.to_s(2), first_bit: :msb)
    packer.finalize

    expect(arr).to eq [0b00110101]
  end

  it 'is correct if a non-byte aligned input is pushed' do
    packer.push_bits([1] * 11)
    packer.finalize

    expect(arr).to eq [255, 7]
  end
end
