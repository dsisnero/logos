module Logos
  # `Lexer` is the main struct that allows you to read through a
  # `Source` and produce tokens for enums implementing the `Logos` trait.
  class Lexer(Token, Source, Extras, Error)
    @source : Source
    @token_start : Int32
    @token_end : Int32
    @extras : Extras

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
      @token_start = 0
      @token_end = 0
      @extras = extras
    end

    # Extras associated with the `Token`.
    property extras : Extras

    # Source from which this Lexer is reading tokens.
    def source : Source
      @source
    end

    # Wrap the `Lexer` in an `Iterator` that produces tuples of `(Token, Span)`.
    #
    # ```
    # tokens = Token.lexer("42 3.14 -5 f").spanned.to_a
    # # => [{Token::Integer(42), 0..2}, {Token::Float(3.14), 3..7}, ...]
    # ```
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

    # Bumps the end of currently lexed token by `n` bytes.
    #
    # **Panics** if adding `n` to current offset would place the `Lexer` beyond the last byte,
    # or in the middle of an UTF-8 code point (does not apply when lexing raw `Slice(UInt8)`).
    def bump(n : Int32) : Nil
      @token_end += n
      raise "Invalid Lexer bump" unless @source.boundary?(@token_end)
    end

    # Read a single byte at current position of the `Lexer` plus `offset`.
    # If end of the `Source` has been reached, this will return `nil`.
    def read_u8(offset : Int32 = 0) : UInt8?
      @source.read_u8(@token_end + offset)
    end

    # Read `bytes` bytes starting at current position of the `Lexer` plus `offset`.
    # If end of the `Source` has been reached, this will return `nil`.
    def read_bytes(bytes : Int32, offset : Int32 = 0) : Slice(UInt8)?
      @source.read_bytes(bytes, @token_end + offset)
    end

    # Turn this lexer into a lexer for a new token type.
    #
    # The new lexer continues to point at the same span as the current lexer,
    # and the current token becomes the error token of the new token type.
    # TODO: Implement morph with generic type parameter
    # def morph(new_token_type : Token2.class) : Lexer(Token2)
    #   Lexer(Token2).new(@source, @extras)
    # end

    # Implementation of `Iterator` for `Lexer`.
    include Iterator(Result(Token, Error))

    # Get the next token from the source.
    def next : Iterator::Stop | Result(Token, Error)
      loop do
        @token_start = @token_end
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
  end

  # Iterator that pairs tokens with their position in the source.
  #
  # Look at `Lexer#spanned` for documentation.
  class SpannedIter(Token, Source, Extras, Error)
    include Iterator({Result(Token, Error), Span})

    def initialize(@lexer : Lexer(Token, Source, Extras, Error))
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
