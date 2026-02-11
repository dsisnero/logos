# Brainfuck interpreter written in Crystal, using Logos.
#
# Usage:
#   crystal run examples/brainfuck.cr -- <path/to/file>
#
# Example:
#   crystal run examples/brainfuck.cr -- examples/hello_world.bf

require "logos"

# Each Op variant is a single character.
Logos.define Op do
  # Skip all non-op characters (lowest priority).
  skip_regex ".|\n", :Skip, priority: 0

  token ">", :IncPointer
  token "<", :DecPointer
  token "+", :IncData
  token "-", :DecData
  token ".", :OutData
  token ",", :InpData
  token "[", :CondJumpForward
  token "]", :CondJumpBackward
end

private def print_byte(byte : UInt8)
  print byte.chr
end

private def read_byte : UInt8
  STDIN.read_byte || 0_u8
end

# Execute Brainfuck code from a string.
private def execute(code : String)
  lexer = Op.lexer(code)
  operations = [] of Op
  while token = lexer.next
    break if token.is_a?(Iterator::Stop)
    result = token.as(Logos::Result(Op, Nil))
    operations << result.unwrap if result.ok?
  end

  data = Array(UInt8).new(30_000, 0_u8)
  pointer = 0

  # Pre-process matching jump commands.
  stack = [] of Int32
  pairs = {} of Int32 => Int32
  pairs_reverse = {} of Int32 => Int32

  operations.each_with_index do |op, idx|
    case op
    when Op::CondJumpForward
      stack << idx
    when Op::CondJumpBackward
      if start = stack.pop?
        pairs[start] = idx
        pairs_reverse[idx] = start
      else
        raise "Unexpected ']' at position #{idx}"
      end
    else
      # no-op
    end
  end

  unless stack.empty?
    raise "Unmatched '[' at positions #{stack.inspect}"
  end

  i = 0
  while i < operations.size
    case operations[i]
    when Op::IncPointer
      pointer += 1
    when Op::DecPointer
      pointer -= 1
    when Op::IncData
      data[pointer] = data[pointer] &+ 1_u8
    when Op::DecData
      data[pointer] = data[pointer] &- 1_u8
    when Op::OutData
      print_byte(data[pointer])
    when Op::InpData
      data[pointer] = read_byte
    when Op::CondJumpForward
      if data[pointer] == 0_u8
        i = pairs[i]
      end
    when Op::CondJumpBackward
      if data[pointer] != 0_u8
        i = pairs_reverse[i]
      end
    end
    i += 1
  end
end

if ARGV.empty?
  abort "Expected file argument"
end

source = File.read(ARGV.first)
execute(source)
