# frozen_string_literal: true
require 'io/console'

module IOUtils
  NULL_CHAR = "\0"

  def read_byte(io)
    io.read(1).unpack('C')[0]
  end

  def write_zero_terminated_string(io, string)
    io.write(string)
    io.write(NULL_CHAR)
  end

  def read_zero_terminated_string(io)
    bytes = []
    loop do
      byte = io.read(1)
      break if byte == NULL_CHAR
      bytes << byte
    end

    bytes.join
  end

  def read_32_bit_le(io)
    io.read(4).unpack('V')[0]
  end

  def write_32_bit_le(io, num)
    write_num(io, num, 'V')
  end

  def write_16_bit_le(io, num)
    write_num(io, num, 'v')
  end

  def write_byte(io, num)
    write_num(io, num, 'C')
  end

  private

  def write_num(io, num, fmt)
    io.write([num].pack(fmt))
  end
end
