require "../spec_helper"
require "regex-automata"

module Logos::Spec::Callbacks
  module ReturnResultSkip
    struct LexerError
      def ==(other : self) : Bool
        true
      end
    end

    Logos.define Token do
      error_type LexerError
      extras Logos::NoExtras

      regex "[ \\t\\n\\f]+", :Whitespace do
        Logos::Skip.new
      end

      regex "<[a-zA-Z0-9-]+>", :Tag do |lex|
        lex.slice[1..-2]
      end

      token "<!--", :Comment do |lex|
        if offset = lex.remainder.index("-->")
          lex.bump(offset + 3)
          Logos::Result(Logos::Skip, LexerError).ok(Logos::Skip.new)
        else
          Logos::Result(Logos::Skip, LexerError).error(LexerError.new)
        end
      end
    end
  end

  module SkipCallbackFunction
    Logos.define Token do
      error_type Nil
      extras Logos::NoExtras

      regex "[ \\t\\n\\f]+", :Whitespace do
        Logos::Skip.new
      end

      regex "<[a-zA-Z0-9-]+>", :Tag do |lex|
        lex.slice[1..-2]
      end

      token "<!--", :Comment do |lex|
        if offset = lex.remainder.index("-->")
          lex.bump(offset + 3)
          Logos::Skip.new
        else
          false
        end
      end
    end
  end

  describe "callback returning Result<Skip, E>" do
    it "skips matching comments and errors on unterminated ones" do
      lexer = Logos::Lexer(ReturnResultSkip::Token, String, Logos::NoExtras, ReturnResultSkip::LexerError).new("<foo> <!-- comment --> <bar>")
      result = lexer.next
      result = result.as(Logos::Result(ReturnResultSkip::Token, ReturnResultSkip::LexerError))
      result.unwrap.should eq(ReturnResultSkip::Token::Tag)
      lexer.slice.should eq("<foo>")

      result = lexer.next
      result = result.as(Logos::Result(ReturnResultSkip::Token, ReturnResultSkip::LexerError))
      result.unwrap.should eq(ReturnResultSkip::Token::Tag)
      lexer.slice.should eq("<bar>")

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "errors on unterminated comment" do
      lexer = Logos::Lexer(ReturnResultSkip::Token, String, Logos::NoExtras, ReturnResultSkip::LexerError).new("<foo> <!-- unterminated")
      result = lexer.next
      result = result.as(Logos::Result(ReturnResultSkip::Token, ReturnResultSkip::LexerError))
      result.unwrap.should eq(ReturnResultSkip::Token::Tag)
      lexer.slice.should eq("<foo>")

      result = lexer.next
      result = result.as(Logos::Result(ReturnResultSkip::Token, ReturnResultSkip::LexerError))
      result.error?.should be_true
    end
  end

  describe "skip callback function" do
    it "skips comments by bumping lexer past the closing delimiter" do
      lexer = Logos::Lexer(SkipCallbackFunction::Token, String, Logos::NoExtras, Nil).new("<foo> <!-- comment --> <bar>")
      result = lexer.next
      result = result.as(Logos::Result(SkipCallbackFunction::Token, Nil))
      result.unwrap.should eq(SkipCallbackFunction::Token::Tag)
      lexer.slice.should eq("<foo>")

      result = lexer.next
      result = result.as(Logos::Result(SkipCallbackFunction::Token, Nil))
      result.unwrap.should eq(SkipCallbackFunction::Token::Tag)
      lexer.slice.should eq("<bar>")

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end

    it "returns default error for unterminated comment" do
      lexer = Logos::Lexer(SkipCallbackFunction::Token, String, Logos::NoExtras, Nil).new("<foo> <!-- unterminated")
      result = lexer.next
      result = result.as(Logos::Result(SkipCallbackFunction::Token, Nil))
      result.unwrap.should eq(SkipCallbackFunction::Token::Tag)
      lexer.slice.should eq("<foo>")

      result = lexer.next
      result = result.as(Logos::Result(SkipCallbackFunction::Token, Nil))
      result.error?.should be_true
    end
  end

  module SkipAllCallbackTypes
    def self.labelled_callback(lex)
      lex.extras << "labelled_callback"
    end

    def self.labelled_skip_callback(lex)
      lex.extras << "labelled_skip_callback"
      Logos::Skip.new
    end

    def self.labelled_result_callback(lex)
      lex.extras << "labelled_result_callback"
      case lex.slice
      when "e" then Logos::Skip.new
      when "f" then Logos::FilterResult::Error.new("f")
      else          Logos::Skip.new
      end
    end

    def self.labelled_skip_result_callback(lex)
      lex.extras << "labelled_skip_result_callback"
      case lex.slice
      when "g" then Logos::Skip.new
      when "h" then Logos::FilterResult::Error.new("h")
      else          Logos::Skip.new
      end
    end

    Logos.define Token do
      error_type String
      extras Array(String)

      skip_regex "a", :SkipA
      skip_regex "b", :SkipB do |lex|
        lex.extras << "inline_callback"
        Logos::Skip.new
      end
      skip_regex "c", :SkipC do |lex|
        Logos::Spec::Callbacks::SkipAllCallbackTypes.labelled_callback(lex)
        Logos::Skip.new
      end
      skip_regex "d", :SkipD do |lex|
        Logos::Spec::Callbacks::SkipAllCallbackTypes.labelled_skip_callback(lex)
      end
      skip_regex "e|f", :SkipEF do |lex|
        Logos::Spec::Callbacks::SkipAllCallbackTypes.labelled_result_callback(lex)
      end
      skip_regex "g|h", :SkipGH do |lex|
        Logos::Spec::Callbacks::SkipAllCallbackTypes.labelled_skip_result_callback(lex)
      end
    end
  end

  describe "skip all callback types" do
    it "handles all skip callback patterns matching upstream" do
      lexer = Logos::Lexer(SkipAllCallbackTypes::Token, String, Array(String), String).new("abcdefghhgfedcba")

      errors = [] of String
      lexer.each do |result|
        case result
        when Logos::Result(SkipAllCallbackTypes::Token, String)
          if result.error?
            errors << result.unwrap_error
          end
        end
      end

      errors.should eq(["f", "h", "h", "f"])
    end

    it "calls callbacks in the expected order" do
      lexer = Logos::Lexer(SkipAllCallbackTypes::Token, String, Array(String), String).new("abcdefghhgfedcba")
      lexer.each { |_| }
      lexer.extras.should eq([
        "inline_callback",
        "labelled_callback",
        "labelled_skip_callback",
        "labelled_result_callback",
        "labelled_result_callback",
        "labelled_skip_result_callback",
        "labelled_skip_result_callback",
        "labelled_skip_result_callback",
        "labelled_skip_result_callback",
        "labelled_result_callback",
        "labelled_result_callback",
        "labelled_skip_callback",
        "labelled_callback",
        "inline_callback",
      ])
    end
  end

  module CallbackValues
    Logos.define Token do
      error_type Nil

      # Skip whitespace
      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Integer do |lex|
        value = lex.slice.to_i64
        Logos::Filter::Emit.new(value)
      end

      regex "[0-9]+\\.[0-9]+", :Float do |lex|
        value = lex.slice.to_f64
        Logos::Filter::Emit.new(value)
      end

      token "+", :Plus
    end
  end

  module RepetitionPatterns
    Logos.define Token do
      error_type Nil

      # Whitespace skip
      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "a{2,5}", :TwoToFiveA
      regex "a{2}", :TwoA
      regex "a{2,}", :TwoOrMoreA
      regex "a{0,3}", :UpToThreeA
    end
  end

  describe "callback returning values (token variants with associated data)" do
    it "parses numbers with callbacks returning values" do
      lexer = Logos::Lexer(CallbackValues::Token, String, Logos::NoExtras, Nil).new("42 3.14 +")

      # First token: Integer with value 42
      result = lexer.next
      result.should_not be_nil
      result.should be_a(Logos::Result(CallbackValues::Token, Nil))
      result = result.as(Logos::Result(CallbackValues::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(CallbackValues::Token::Integer)
      lexer.int_value.should eq(42)
      lexer.slice.should eq("42")

      # Second token: Float with value 3.14
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(CallbackValues::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(CallbackValues::Token::Float)
      lexer.float_value.should eq(3.14)
      lexer.slice.should eq("3.14")

      # Third token: Plus without value
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(CallbackValues::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(CallbackValues::Token::Plus)
      lexer.int_value.should be_nil
      lexer.float_value.should be_nil
      lexer.slice.should eq("+")

      # End of input
      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  module BoolCallbacks
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[a-z]+", :Word do |lex|
        lex.slice != "skip"
      end
    end
  end

  module RawStringCallbacks
    def self.parse_raw_string(lexer : Logos::Lexer(Token, String, Logos::NoExtras, Nil)) : Bool
      q_hashes = "\"##############################"
      closing = q_hashes[0, lexer.slice.bytesize - 1]

      if offset = lexer.remainder.byte_index(closing)
        lexer.bump(offset + closing.bytesize)
        true
      else
        false
      end
    end

    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\f]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[a-zA-Z_][a-zA-Z0-9_]*", :Ident

      regex "r#*\"", :RawString do |lex|
        Logos::Spec::Callbacks::RawStringCallbacks.parse_raw_string(lex)
      end
    end
  end

  module FilterResultCallbacks
    struct CustomError
      getter message : String

      def initialize(@message : String = "")
      end

      def ==(other : self) : Bool
        @message == other.message
      end
    end

    Logos.define Token do
      error_type CustomError

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Number do |lex|
        value = lex.slice.to_i
        if value == 0
          Logos::FilterResult::Skip.new
        elsif value > 10
          Logos::FilterResult::Error.new(CustomError.new("too big"))
        else
          true
        end
      end
    end
  end

  describe "callback returning bool (filter callbacks)" do
    it "treats false as a lexing error instead of skipping" do
      lexer = Logos::Lexer(BoolCallbacks::Token, String, Logos::NoExtras, Nil).new("keep skip keep")

      result = lexer.next
      result = result.as(Logos::Result(BoolCallbacks::Token, Nil))
      result.unwrap.should eq(BoolCallbacks::Token::Word)
      lexer.slice.should eq("keep")
      lexer.span.should eq(0...4)

      result = lexer.next
      result = result.as(Logos::Result(BoolCallbacks::Token, Nil))
      result.error?.should be_true
      lexer.slice.should eq("skip")
      lexer.span.should eq(5...9)

      result = lexer.next
      result = result.as(Logos::Result(BoolCallbacks::Token, Nil))
      result.unwrap.should eq(BoolCallbacks::Token::Word)
      lexer.slice.should eq("keep")
      lexer.span.should eq(10...14)

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "bool callbacks with lexer.bump side effects" do
    it "matches closed raw strings and errors on unterminated ones" do
      lexer = Logos::Lexer(RawStringCallbacks::Token, String, Logos::NoExtras, Nil).new(%( r"foo" r#"bar"# r#####"baz"##### r###"error"## ))

      expected = [
        {:ok, RawStringCallbacks::Token::RawString, %(r"foo"), 1...7},
        {:ok, RawStringCallbacks::Token::RawString, %(r#"bar"#), 8...16},
        {:ok, RawStringCallbacks::Token::RawString, %(r#####"baz"#####), 17...33},
        {:error, nil, %(r###"), 34...39},
        {:ok, RawStringCallbacks::Token::Ident, "error", 39...44},
        {:error, nil, %("), 44...45},
        {:error, nil, "#", 45...46},
        {:error, nil, "#", 46...47},
      ]

      expected.each do |kind, expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(RawStringCallbacks::Token, Nil))
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)

        case kind
        when :ok
          result.unwrap.should eq(expected_token)
        when :error
          result.error?.should be_true
        else
          raise "unreachable"
        end
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "callback returning Result<(), E> or Skip" do
    it "handles callbacks returning Result or Skip" do
      lexer = Logos::Lexer(FilterResultCallbacks::Token, String, Logos::NoExtras, FilterResultCallbacks::CustomError).new("1 0 20")

      result = lexer.next
      result = result.as(Logos::Result(FilterResultCallbacks::Token, FilterResultCallbacks::CustomError))
      result.unwrap.should eq(FilterResultCallbacks::Token::Number)
      lexer.slice.should eq("1")

      result = lexer.next
      result = result.as(Logos::Result(FilterResultCallbacks::Token, FilterResultCallbacks::CustomError))
      result.error?.should be_true
      result.unwrap_error.should eq(FilterResultCallbacks::CustomError.new("too big"))
    end
  end

  module ResultCallbacks
    Logos.define Token do
      error_type String

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Number do |lex|
        value = lex.slice.to_i
        if value > 10
          Logos::Result(Int32, String).error("too big")
        else
          Logos::Result(Int32, String).ok(value)
        end
      end
    end
  end

  describe "callback returning Logos::Result" do
    it "emits values or errors" do
      lexer = Logos::Lexer(ResultCallbacks::Token, String, Logos::NoExtras, String).new("5 20")

      result = lexer.next
      result = result.as(Logos::Result(ResultCallbacks::Token, String))
      result.ok?.should be_true
      result.unwrap.should eq(ResultCallbacks::Token::Number)
      lexer.callback_value_as(Int32).should eq(5)

      result = lexer.next
      result = result.as(Logos::Result(ResultCallbacks::Token, String))
      result.error?.should be_true
      result.unwrap_error.should eq("too big")
    end
  end

  module OptionCallbacks
    Logos.define Token do
      error_type String

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Number do |lex|
        value = lex.slice.to_i
        Logos::Option(Int32).new(value > 0 ? value : nil)
      end
    end
  end

  describe "callback returning Logos::Option" do
    it "treats nil as error and some as value" do
      lexer = Logos::Lexer(OptionCallbacks::Token, String, Logos::NoExtras, String).new("1 0")

      result = lexer.next
      result = result.as(Logos::Result(OptionCallbacks::Token, String))
      result.ok?.should be_true
      result.unwrap.should eq(OptionCallbacks::Token::Number)
      lexer.callback_value_as(Int32).should eq(1)

      result = lexer.next
      result = result.as(Logos::Result(OptionCallbacks::Token, String))
      result.error?.should be_true
      result.unwrap_error.should eq("")
    end
  end

  module LifetimeCallbacks
    Logos.define Token do
      error_type Nil

      regex "[ \\t\\n\\r]+", :Whitespace do
        Logos::Skip.new
      end

      regex "[0-9]+", :Integer do |lex|
        Logos::Filter::Emit.new({lex.slice, lex.slice.to_u64})
      end

      regex "[a-z]+", :Text do |lex|
        Logos::Filter::Emit.new(lex.slice)
      end
    end
  end

  describe "callback with lifetime annotations" do
    it "supports callbacks with nested tuple and string values" do
      lexer = Logos::Lexer(LifetimeCallbacks::Token, String, Logos::NoExtras, Nil).new("123 abc")

      result = lexer.next
      result = result.as(Logos::Result(LifetimeCallbacks::Token, Nil))
      result.unwrap.should eq(LifetimeCallbacks::Token::Integer)
      lexer.callback_value_as(Tuple(String, UInt64)).should eq({"123", 123_u64})

      result = lexer.next
      result = result.as(Logos::Result(LifetimeCallbacks::Token, Nil))
      result.unwrap.should eq(LifetimeCallbacks::Token::Text)
      lexer.callback_value_as(String).should eq("abc")
    end
  end

  describe "callback returning a token variant" do
    it "emits the token returned by the callback" do
      lexer = Logos::Lexer(AnyTokenCallbacksToken, String, Logos::NoExtras, Nil).new("Hello 1 42 -100 pi 3.14 -77.77")

      expected = [
        {AnyTokenCallbacksToken::Text, "Hello", 0...5},
        {AnyTokenCallbacksToken::Integer, "1", 6...7},
        {AnyTokenCallbacksToken::Integer, "42", 8...10},
        {AnyTokenCallbacksToken::Integer, "-100", 11...15},
        {AnyTokenCallbacksToken::Text, "pi", 16...18},
        {AnyTokenCallbacksToken::Float, "3.14", 19...23},
        {AnyTokenCallbacksToken::Float, "-77.77", 24...30},
      ]

      expected.each do |expected_token, expected_slice, expected_range|
        result = lexer.next
        result.should_not be_nil
        result = result.as(Logos::Result(AnyTokenCallbacksToken, Nil))
        result.unwrap.should eq(expected_token)
        lexer.slice.should eq(expected_slice)
        lexer.span.should eq(expected_range)
      end

      lexer.next.should eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "regex repetition ranges" do
    it "matches a{2,5} with exactly 5 a's" do
      lexer = Logos::Lexer(RepetitionPatterns::Token, String, Logos::NoExtras, Nil).new("aaaaa")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(RepetitionPatterns::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(RepetitionPatterns::Token::TwoToFiveA)
      lexer.slice.should eq("aaaaa")
    end

    it "matches a{2,} with 6 a's" do
      lexer = Logos::Lexer(RepetitionPatterns::Token, String, Logos::NoExtras, Nil).new("aaaaaa")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(RepetitionPatterns::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(RepetitionPatterns::Token::TwoOrMoreA)
      lexer.slice.should eq("aaaaaa")
    end

    it "matches a{0,3} with 1 a" do
      lexer = Logos::Lexer(RepetitionPatterns::Token, String, Logos::NoExtras, Nil).new("a")
      result = lexer.next
      result.should_not be_nil
      result = result.as(Logos::Result(RepetitionPatterns::Token, Nil))
      result.ok?.should be_true
      result.unwrap.should eq(RepetitionPatterns::Token::UpToThreeA)
      lexer.slice.should eq("a")
    end
  end
end

@[Logos::Options(error_type: Nil)]
@[Logos::Regex("[ \\t\\n\\r]+", variant: :Whitespace, callback: -> { Logos::Skip.new })]
@[Logos::Regex("[a-zA-Z]+", variant: :Text, callback: -> { Logos::Spec::Callbacks::AnyTokenCallbacksToken::Text })]
@[Logos::Regex("-?[0-9]+", variant: :Text, callback: -> { Logos::Spec::Callbacks::AnyTokenCallbacksToken::Integer })]
@[Logos::Regex("-?[0-9]+\\.[0-9]+", variant: :Text, callback: -> { Logos::Spec::Callbacks::AnyTokenCallbacksToken::Float })]
enum Logos::Spec::Callbacks::AnyTokenCallbacksToken
  Whitespace
  Text
  Integer
  Float
end

logos_derive(Logos::Spec::Callbacks::AnyTokenCallbacksToken)
