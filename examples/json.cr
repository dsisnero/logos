# JSON parser written in Crystal, using Logos.
#
# Usage:
#   crystal run examples/json.cr -- <path/to/file>
#
# Example:
#   crystal run examples/json.cr -- examples/example.json

require "logos"

alias JsonValue = Nil | Bool | Float64 | String | Array(JsonValue) | Hash(String, JsonValue)

class JsonParseError < Exception
  getter span : Logos::Span

  def initialize(message : String, @span : Logos::Span)
    super(message)
  end
end

Logos.define Token do
  error_type Nil
  skip_regex "[ \t\r\n\f]+", :Whitespace

  token "false", :Bool do |_lex|
    Logos::Filter::Emit.new(false)
  end

  token "true", :Bool do |_lex|
    Logos::Filter::Emit.new(true)
  end

  token "{", :BraceOpen
  token "}", :BraceClose
  token "[", :BracketOpen
  token "]", :BracketClose
  token ":", :Colon
  token ",", :Comma
  token "null", :Null

  regex "-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?", :Number do |lex|
    Logos::Filter::Emit.new(lex.slice.to_f64)
  end

  regex %q("([^"\\\x00-\x1F]|\\(["\\bnfrt/]|u[a-fA-F0-9]{4}))*"), :String do |lex|
    Logos::Filter::Emit.new(lex.slice)
  end
end

private def next_token(lexer)
  token = lexer.next
  return nil if token.is_a?(Iterator::Stop)
  token.as(Logos::Result(Token, Nil))
end

private def parse_value(lexer) : JsonValue
  result = next_token(lexer)
  raise JsonParseError.new("empty values are not allowed", lexer.span) if result.nil?

  if result.ok?
    case result.unwrap
    when Token::Bool
      lexer.callback_value_as(Bool).not_nil!
    when Token::BraceOpen
      parse_object(lexer)
    when Token::BracketOpen
      parse_array(lexer)
    when Token::Null
      nil
    when Token::Number
      lexer.callback_value_as(Float64).not_nil!
    when Token::String
      lexer.callback_value_as(String).not_nil!
    else
      raise JsonParseError.new("unexpected token here (context: value)", lexer.span)
    end
  else
    raise JsonParseError.new("unexpected token here (context: value)", lexer.span)
  end
end

private def parse_array(lexer) : JsonValue
  array = [] of JsonValue
  start_span = lexer.span
  awaits_comma = false
  awaits_value = false

  while (result = next_token(lexer))
    if result.ok?
      case result.unwrap
      when Token::Bool
        if awaits_comma
          raise JsonParseError.new("unexpected token here (context: array)", lexer.span)
        end
        array << lexer.callback_value_as(Bool).not_nil!
        awaits_value = false
      when Token::BraceOpen
        raise JsonParseError.new("unexpected token here (context: array)", lexer.span) if awaits_comma
        array << parse_object(lexer)
        awaits_value = false
      when Token::BracketOpen
        raise JsonParseError.new("unexpected token here (context: array)", lexer.span) if awaits_comma
        array << parse_array(lexer)
        awaits_value = false
      when Token::BracketClose
        return array unless awaits_value
      when Token::Comma
        awaits_value = true if awaits_comma
      when Token::Null
        if awaits_comma
          raise JsonParseError.new("unexpected token here (context: array)", lexer.span)
        end
        array << nil
        awaits_value = false
      when Token::Number
        raise JsonParseError.new("unexpected token here (context: array)", lexer.span) if awaits_comma
        array << lexer.callback_value_as(Float64).not_nil!
        awaits_value = false
      when Token::String
        raise JsonParseError.new("unexpected token here (context: array)", lexer.span) if awaits_comma
        array << lexer.callback_value_as(String).not_nil!
        awaits_value = false
      else
        raise JsonParseError.new("unexpected token here (context: array)", lexer.span)
      end
    else
      raise JsonParseError.new("unexpected token here (context: array)", lexer.span)
    end
    awaits_comma = !awaits_value
  end

  raise JsonParseError.new("unmatched opening bracket defined here", start_span)
end

private def parse_object(lexer) : JsonValue
  map = {} of String => JsonValue
  start_span = lexer.span
  awaits_comma = false
  awaits_key = false

  while (result = next_token(lexer))
    if result.ok?
      case result.unwrap
      when Token::BraceClose
        return map unless awaits_key
      when Token::Comma
        awaits_key = true if awaits_comma
      when Token::String
        if awaits_comma
          raise JsonParseError.new("unexpected token here (context: object)", lexer.span)
        end
        key = lexer.callback_value_as(String).not_nil!
        next_colon = next_token(lexer)
        if next_colon.nil? || !next_colon.ok? || next_colon.unwrap != Token::Colon
          raise JsonParseError.new("unexpected token here, expecting ':'", lexer.span)
        end
        map[key] = parse_value(lexer)
        awaits_key = false
      else
        raise JsonParseError.new("unexpected token here (context: object)", lexer.span)
      end
    else
      raise JsonParseError.new("unexpected token here (context: object)", lexer.span)
    end
    awaits_comma = !awaits_key
  end

  raise JsonParseError.new("unmatched opening brace defined here", start_span)
end

if ARGV.empty?
  abort "Expected file argument"
end

filename = ARGV.first
source = File.read(filename)
lexer = Token.lexer(source)

begin
  value = parse_value(lexer)
  pp value
rescue ex : JsonParseError
  STDERR.puts "Invalid JSON at #{ex.span}: #{ex.message}"
end
