module Logos
  # `Lexer` is the main struct that allows you to read through a
  # `Source` and produce tokens for enums implementing the `Logos` trait.
  class Lexer(Token, Source, Extras, Error)
    @source : Source
    @source_bytes : Bytes
    @token_start : Int32
    @token_end : Int32
    @extras : Extras
    @callback_value : CallbackValueBase? = nil

    # Create a new `Lexer`.
    #
    # Due to type inference, it might be more ergonomic to construct
    # it by calling `Token.lexer` on any `Token` with derived `Logos`.
    def self.new(source : Source) : self
      Lexer(Token, Source, Extras, Error).new(source, Extras.new)
    end

    # Create a new `Lexer` with the provided `Extras`.
    #
    # Due to type inference, it might be more ergonomic to construct
    # it by calling `Token.lexer_with_extras` on any `Token` with derived `Logos`.
    def initialize(@source : Source, extras : Extras = Extras.new)
      @source_bytes = @source.to_slice
      @token_start = 0
      @token_end = 0
      @extras = extras
    end

    # Extras associated with the `Token`.
    property extras : Extras

    # Last callback return value (for tokens with associated data)
    property callback_value : CallbackValueBase?

    # Get callback value as a specific type.
    def callback_value_as(type : T.class) : T? forall T
      @callback_value.as?(CallbackValue(T)).try(&.value)
    end

    # Get callback value as Int64
    def int_value : Int64?
      callback_value_as(Int64)
    end

    # Get callback value as Float64
    def float_value : Float64?
      callback_value_as(Float64)
    end

    # Get callback value as String
    def string_value : String?
      callback_value_as(String)
    end

    # Return a typed callback payload when the result is the expected token variant.
    def payload_for(result : Result(Token, Error), expected_token : Token, type : T.class) : T? forall T
      result.payload_for(expected_token, type)
    end

    # Same as `payload_for`, but raises if the token doesn't match or payload type is missing.
    def payload_for!(result : Result(Token, Error), expected_token : Token, type : T.class) : T forall T
      result.payload_for!(expected_token, type)
    end

    # Clear callback value
    def clear_callback_value : Nil
      @callback_value = nil
    end

    # Source from which this Lexer is reading tokens.
    def source : Source
      @source
    end

    # Immutable byte view used by source-generated matchers. Keeping it on the
    # lexer avoids recreating a String slice for each token.
    def source_bytes : Bytes
      @source_bytes
    end

    # Wrap this lexer in an iterator of token results and their byte spans.
    # Advancing the iterator also advances this lexer.
    def spanned : SpannedIter(Token, Source, Extras, Error)
      SpannedIter(Token, Source, Extras, Error).new(self)
    end

    # Get the range for the current token in `Source`.
    def span : Span
      @token_start...@token_end
    end

    # Get a string slice of the current token.
    def slice : Source
      # In bounds if `@token_start` and `@token_end` are in bounds.
      # * `@token_start` is initially zero and is set to `@token_end` in `next`, so
      #   it remains in bounds as long as `@token_end` remains in bounds.
      # * `@token_end` is initially zero and is only incremented in `bump`. `bump`
      #   will panic if `Source#is_boundary` is false.
      # * Thus safety is contingent on the correct implementation of the `is_boundary`
      #   method.
      @source.slice_unchecked(span)
    end

    # Get a slice of remaining source, starting at the end of current token.
    def remainder : Source
      @source.slice_unchecked(@token_end...@source.length)
    end

    # Byte offset where the next token match begins. Generated matchers use
    # this with `source.to_slice` to avoid allocating the remaining input.
    def offset : Int32
      @token_end
    end

    # Bumps the end of currently lexed token by `n` bytes.
    #
    # Raises if the new end precedes the current token, exceeds the source,
    # or splits a UTF-8 code point. Invalid bumps leave the span intact.
    def bump(n : Int32) : Nil
      position = source_position(n)
      unless position && position >= @token_start && @source.boundary?(position)
        raise "Invalid Lexer bump"
      end
      @token_end = position
    end

    # Read a single byte at current position of the `Lexer` plus `offset`.
    # If end of the `Source` has been reached, this will return `nil`.
    def read_u8(offset : Int32 = 0) : UInt8?
      if position = source_position(offset)
        @source.read_u8(position)
      end
    end

    # Read `bytes` bytes starting at current position of the `Lexer` plus `offset`.
    # If end of the `Source` has been reached, this will return `nil`.
    def read_bytes(bytes : Int32, offset : Int32 = 0) : Slice(UInt8)?
      if position = source_position(offset)
        @source.read_bytes(bytes, position)
      end
    end

    private def source_position(offset : Int32) : Int32?
      position = @token_end.to_i64 + offset
      return if position < 0 || position > @source_bytes.size
      position.to_i32
    end

    # Turn this lexer into a lexer for a new token type.
    #
    # The new lexer keeps the source and span and uses the destination token's
    # error type. Use the block overload to convert extras between modes.
    def morph(token_type : Token2.class) : Lexer forall Token2
      morph(token_type) { |extras| extras }
    end

    def morph(token_type : Token2.class, & : Extras -> Extras2) : Lexer forall Token2, Extras2
      converted_extras = yield @extras
      lexer = {% if Token2.class.has_method?(:lexer_with_extras) %}
                token_type.lexer_with_extras(@source, converted_extras)
              {% else %}
                Lexer(Token2, Source, Extras2, Error).new(@source, converted_extras)
              {% end %}
      lexer.set_span(@token_start, @token_end)
      lexer
    end

    # Implementation of `Iterator` for `Lexer`.
    include Iterator(Result(Token, Error))

    # Get the next token from the source.
    def next : Iterator::Stop | Result(Token, Error)
      loop do
        @token_start = @token_end
        clear_callback_value
        case result = Token.lex(self)
        when ::Logos::Result(Token, Error)
          return result
        when Nil
          # Skip token (lex returned nil) or end of input?
          # If we're at end of source, stop
          if @token_end >= @source.length
            @token_start = @token_end
            return stop
          end
          # Otherwise continue looping (skip token)
          # Update token start for next iteration
          @token_start = @token_end
        else
          # Should not happen
          return stop
        end
      end
    end

    protected def set_span(start_pos : Int32, end_pos : Int32) : Nil
      @token_start = start_pos
      @token_end = end_pos
    end

    # Copy the cursor and clone extras that implement `clone`.
    # Opaque extras and the last callback payload retain their references.
    def clone : self
      extras = @extras
      extras = extras.clone if extras.responds_to?(:clone)
      lexer = Lexer(Token, Source, Extras, Error).new(@source, extras)
      lexer.set_span(@token_start, @token_end)
      lexer.callback_value = @callback_value
      lexer
    end
  end

  # Iterator that pairs tokens with their position in the source.
  #
  # Look at `Lexer#spanned` for documentation.
  class SpannedIter(Token, Source, Extras, Error)
    include Iterator({Result(Token, Error), Span})

    # The lexer supplying this iterator's tokens and spans.
    getter lexer : Lexer(Token, Source, Extras, Error)

    def initialize(@lexer : Lexer(Token, Source, Extras, Error))
    end

    # Copy the lexer at its current position for independent iteration.
    def clone : self
      self.class.new(@lexer.clone)
    end

    def next : Iterator::Stop | {Result(Token, Error), Span}
      case token = @lexer.next
      when Iterator::Stop
        stop
      else
        {token, @lexer.span}
      end
    end
  end
end
