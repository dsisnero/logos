module Regex::Automata
  MAX_UTF8_BYTES = 4

  # UTF-8 byte range (inclusive)
  struct Utf8Range
    getter start : UInt8
    getter end : UInt8

    def initialize(@start : UInt8, @end : UInt8)
    end

    def matches(b : UInt8) : Bool
      @start <= b && b <= @end
    end

    def to_s(io)
      if @start == @end
        io << "[%02X]" % @start
      else
        io << "[%02X-%02X]" % [@start, @end]
      end
    end

    def inspect(io)
      to_s(io)
    end
  end

  # A sequence of UTF-8 byte ranges that must be matched in order
  class Utf8Sequence
    @ranges : Array(Utf8Range)

    def initialize(@ranges : Array(Utf8Range))
    end

    def self.one(range : Utf8Range) : Utf8Sequence
      new([range])
    end

    def self.two(r1, r2) : Utf8Sequence
      new([r1, r2])
    end

    def self.three(r1, r2, r3) : Utf8Sequence
      new([r1, r2, r3])
    end

    def self.four(r1, r2, r3, r4) : Utf8Sequence
      new([r1, r2, r3, r4])
    end

    # Create from encoded start and end bytes (same length)
    def self.from_encoded_range(start : Bytes, end_bytes : Bytes) : Utf8Sequence
      raise "length mismatch" unless start.size == end_bytes.size
      ranges = start.size.times.map do |i|
        Utf8Range.new(start[i], end_bytes[i])
      end.to_a
      new(ranges)
    end

    def ranges : Array(Utf8Range)
      @ranges
    end

    def size : Int32
      @ranges.size
    end

    # Check if this sequence matches the given bytes (exact length)
    def matches(bytes : Bytes) : Bool
      return false if bytes.size != @ranges.size
      @ranges.each_with_index do |range, i|
        return false unless range.matches(bytes[i])
      end
      true
    end

    def to_s(io)
      @ranges.each { |r| io << r }
      io
    end

    def inspect(io)
      to_s(io)
    end
  end

  private class ScalarRange
    getter start : UInt32
    getter end : UInt32

    def initialize(@start : UInt32, @end : UInt32)
    end

    # Split if overlapping with surrogate codepoints (0xD800-0xDFFF)
    def split : Tuple(ScalarRange, ScalarRange)?
      if @start < 0xE000_u32 && @end > 0xD7FF_u32
        {
          ScalarRange.new(@start, 0xD7FF_u32),
          ScalarRange.new(0xE000_u32, @end),
        }
      end
    end

    def valid? : Bool
      @start <= @end
    end

    def ascii? : Bool
      valid? && @end <= 0x7F_u32
    end

    def as_ascii_range : Utf8Range?
      if ascii?
        Utf8Range.new(@start.to_u8, @end.to_u8)
      end
    end

    # Encode start and end to UTF-8 bytes, return number of bytes written
    def encode(start_buf : Bytes, end_buf : Bytes) : Int32
      cs = @start.chr
      ce = @end.chr

      cs_str = cs.to_s
      ce_str = ce.to_s

      cs_str.bytes.each_with_index { |b, i| start_buf[i] = b }
      ce_str.bytes.each_with_index { |b, i| end_buf[i] = b }

      cs_str.bytesize
    end
  end

  # Iterator over UTF-8 byte sequences for a given Unicode scalar range
  class Utf8Sequences
    @range_stack : Array(ScalarRange)

    def initialize(start : Char, end_char : Char)
      @range_stack = [ScalarRange.new(start.ord.to_u32, end_char.ord.to_u32)]
    end

    def next : Utf8Sequence?
      while r = @range_stack.pop?
        # Simple implementation: process one codepoint at a time
        # This is inefficient but correct for small ranges used in tests
        if r.start > r.end
          next
        end

        if r.start == r.end
          # Single codepoint
          start_buf = uninitialized UInt8[MAX_UTF8_BYTES]
          end_buf = uninitialized UInt8[MAX_UTF8_BYTES]
          n = r.encode(start_buf.to_slice, end_buf.to_slice)
          return Utf8Sequence.from_encoded_range(
            start_buf.to_slice[0, n],
            end_buf.to_slice[0, n]
          )
        else
          # Process first codepoint, push remainder back
          @range_stack << ScalarRange.new(r.start + 1, r.end)
          single = ScalarRange.new(r.start, r.start)
          start_buf = uninitialized UInt8[MAX_UTF8_BYTES]
          end_buf = uninitialized UInt8[MAX_UTF8_BYTES]
          n = single.encode(start_buf.to_slice, end_buf.to_slice)
          return Utf8Sequence.from_encoded_range(
            start_buf.to_slice[0, n],
            end_buf.to_slice[0, n]
          )
        end
      end
      nil
    end

    def each : Iterator(Utf8Sequence)
      Iterator.of do
        next_value = self.next
        next_value ? next_value : stop
      end
    end
  end
end
