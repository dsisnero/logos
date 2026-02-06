module Logos
  # Trait for types the `Lexer` can read from.
  #
  # Most notably this is implemented for `String` and `Bytes`. It is unlikely you will
  # ever want to use this Trait yourself, unless implementing a new `Source`
  # the `Lexer` can use.
  #
  # The correctness of unsafe operations depends on the correct
  # implementation of the `length` and `find_boundary` functions so generated code does not request
  # out-of-bounds access.
  module Source(T)
    # Length of the source
    abstract def length : Int32

    # Read a single byte at `offset`. Returns `nil` when reading
    # out of bounds would occur.
    #
    # This is very useful for matching fixed-size byte arrays, and tends
    # to be very fast at it too, since the compiler knows the byte length.
    abstract def read_u8(offset : Int32) : UInt8?

    # Read `bytes` bytes starting at `offset`. Returns `nil` when reading
    # out of bounds would occur.
    abstract def read_bytes(bytes : Int32, offset : Int32) : Bytes?

    # Get a slice of the source at given range. This is analogous to
    # `slice[range]?`.
    #
    # ```
    # foo = "It was the year when they finally immanentized the Eschaton."
    # foo.byte_slice?(51, 8) # => "Eschaton"
    # ```
    abstract def slice(range : Range(Int32, Int32)) : T?

    # Get a slice of the source at given range. This is analogous to
    # `slice[range]` without bounds checking.
    #
    # **Unsafe**: Range should not exceed bounds.
    #
    # ```
    # foo = "It was the year when they finally immanentized the Eschaton."
    #
    # unsafe do
    #   foo.slice_unchecked(51..59) # => "Eschaton"
    # end
    # ```
    abstract def slice_unchecked(range : Range(Int32, Int32)) : T

    # For `String` sources attempts to find the closest `Char` boundary at which source
    # can be sliced, starting from `index`.
    #
    # For binary sources (`Bytes`) this should just return `index` back.
    def find_boundary(index : Int32) : Int32
      index
    end

    # Check if `index` is valid for this `Source`, that is:
    #
    # - It's not larger than the byte length of the `Source`.
    # - (`String` only) It doesn't land in the middle of a UTF-8 code point.
    abstract def is_boundary(index : Int32) : Bool
  end
end

# Implement Source for String
class String
  include Logos::Source(String)

  def length : Int32
    bytesize
  end

  def read_u8(offset : Int32) : UInt8?
    return if offset < 0 || offset >= bytesize
    to_unsafe[offset]
  end

  def read_bytes(bytes : Int32, offset : Int32) : Bytes?
    return if offset < 0 || offset + bytes > bytesize
    to_slice[offset, bytes]
  end

  def slice(range : Range(Int32, Int32)) : String?
    # Crystal ranges can be inclusive (..) or exclusive (...)
    # We treat both as exclusive to match Rust's Range<usize>
    start = range.begin
    exclusive_end = range.exclusive? ? range.end : range.end + 1
    byte_slice?(start, exclusive_end - start)
  end

  def slice_unchecked(range : Range(Int32, Int32)) : String
    start = range.begin
    exclusive_end = range.exclusive? ? range.end : range.end + 1
    count = exclusive_end - start
    raise "BUG: slice_unchecked called with out of bounds range" unless start >= 0 && exclusive_end <= bytesize
    to_unsafe_byte_slice(start, count).to_s
  end

  def is_boundary(index : Int32) : Bool
    return false if index < 0 || index > bytesize
    return true if index == 0 || index == bytesize

    # Check if index is at a character boundary
    # This is similar to Rust's str.is_char_boundary()
    # We check if we can decode a character starting at this index
    bytes = to_slice
    return false if index >= bytes.size

    # Simple UTF-8 boundary check
    # If byte at index is not a continuation byte (0x80-0xBF), it's a boundary
    byte = bytes[index]
    (byte & 0xC0) != 0x80
  end

  def find_boundary(index : Int32) : Int32
    index = index.clamp(0, bytesize)
    while index < bytesize && !is_boundary(index)
      index += 1
    end
    index
  end
end

# Implement Source for Slice(UInt8)
struct Slice(T)
  include Logos::Source(Slice(T))

  def length : Int32
    size
  end

  def read_u8(offset : Int32) : UInt8?
    return if offset < 0 || offset >= size
    self[offset]
  end

  def read_bytes(bytes : Int32, offset : Int32) : Slice(UInt8)?
    return if offset < 0 || offset + bytes > size
    self[offset, bytes]
  end

  def slice(range : Range(Int32, Int32)) : Slice(T)?
    start = range.begin
    exclusive_end = range.exclusive? ? range.end : range.end + 1
    return if start < 0 || exclusive_end > size
    self[start, exclusive_end - start]
  end

  def slice_unchecked(range : Range(Int32, Int32)) : Slice(T)
    start = range.begin
    exclusive_end = range.exclusive? ? range.end : range.end + 1
    count = exclusive_end - start
    raise "BUG: slice_unchecked called with out of bounds range" unless start >= 0 && exclusive_end <= size
    self[start, count]
  end

  def is_boundary(index : Int32) : Bool
    index >= 0 && index <= size
  end
end
