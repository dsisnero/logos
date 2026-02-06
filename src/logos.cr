# Logos - Create ridiculously fast Lexers
#
# See https://logos.maciej.codes/ for documentation and examples.
module Logos
  VERSION = "0.1.0"

  # Core types
  alias Span = Range(Int32, Int32)

  # Simple Result type similar to Rust's Result
  struct Result(T, E)
    @value : T | E
    @is_ok : Bool

    def initialize(value : T, @is_ok = true)
      @value = value
    end

    def initialize(error : E, @is_ok = false)
      @value = error
    end

    def ok? : Bool
      @is_ok
    end

    def error? : Bool
      !@is_ok
    end

    def unwrap : T
      if @is_ok
        @value.as(T)
      else
        raise "Called unwrap on an Err value"
      end
    end

    def unwrap_error : E
      if @is_ok
        raise "Called unwrap_error on an Ok value"
      else
        @value.as(E)
      end
    end

    def self.ok(value : T) : self
      new(value, true)
    end

    def self.error(error : E) : self
      new(error, false)
    end
  end

  # Type that can be returned from a callback, informing the `Lexer`, to skip
  # current token match.
  struct Skip
  end

  # Type that can be returned from a callback, either producing a field
  # for a token, or skipping it.
  module Filter
    struct Emit(T)
      getter value : T

      def initialize(@value : T)
      end
    end

    struct Skip
    end
  end

  # Type that can be returned from a callback, either producing a field
  # for a token, skipping it, or emitting an error.
  module FilterResult
    struct Emit(T)
      getter value : T

      def initialize(@value : T)
      end
    end

    struct Skip
    end

    struct Error(E)
      getter error : E

      def initialize(@error : E)
      end
    end
  end

  # Predefined callback that will inform the `Lexer` to skip a definition.
  def self.skip(lexer : Lexer) : Skip
    Skip.new
  end
end

require "./logos/source"
