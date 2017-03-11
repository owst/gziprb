# frozen_string_literal: true
class DeflateOutputBuffer
  def initialize(&on_byte)
    raise 'Must be given a block to yield each packed byte to' unless block_given?
    @on_byte = on_byte
    @byte_value = 0
    @offset = 0
  end

  def zero_pad_current_byte
    push_bit(0) until @offset.zero?
  end

  # Use finalize to ensure all bits that have been packed are yielded. If the current byte is
  # non-full, it is padded with zero bits before being yielded.
  alias finalize zero_pad_current_byte

  def push_bit(bit)
    @byte_value |= (bit << @offset)
    @offset += 1

    return unless @offset == 8

    @on_byte.call(@byte_value)
    @byte_value = 0
    @offset = 0
  end

  def push_bit_string(bit_string, first_bit: :lsb)
    push_bits(bit_string.chars.map { |c| c == '1' ? 1 : 0 }, first_bit: first_bit)
  end

  def push_bits(bits, first_bit: :lsb)
    bits = bits.reverse if first_bit == :lsb

    bits.each { |b| push_bit(b) }
  end

  def push_raw_byte(byte)
    raise 'Can only push raw bytes when packing is byte-aligned' unless @offset.zero?

    @on_byte.call(byte)
  end

  def push_raw_bytes(bytes)
    bytes.each { |b| push_raw_byte(b) }
  end
end
