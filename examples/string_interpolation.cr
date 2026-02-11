# String interpolation example using Logos.
#
# Usage:
#   crystal run examples/string_interpolation.cr

require "logos"

alias SymbolTable = Hash(String, String)

Logos.define VariableDefinitionContext do
  extras SymbolTable
  error_type Nil
  skip_regex "\\s+", :Whitespace

  regex "[[:alpha:]][[:alnum:]]*", :Id do |lex|
    id = lex.slice

    # Use a clone to parse the rest without disturbing the original lexer.
    lookahead = lex.clone

    next_token = lookahead.next
    return false if next_token.is_a?(Iterator::Stop)
    next_result = next_token.as(Logos::Result(VariableDefinitionContext, Nil))
    return false unless next_result.ok? && next_result.unwrap == VariableDefinitionContext::Equals

    next_token = lookahead.next
    return false if next_token.is_a?(Iterator::Stop)
    next_result = next_token.as(Logos::Result(VariableDefinitionContext, Nil))
    return false unless next_result.ok? && next_result.unwrap == VariableDefinitionContext::Quote

    string_lex = lookahead.morph(StringContext)
    value = get_string_content(string_lex)

    # Advance original lexer to the end of the parsed string.
    delta = string_lex.span.end - lex.span.end
    lex.bump(delta)

    lex.extras[id] = value
    Logos::Filter::Emit.new({id, value})
  end

  token "=", :Equals
  token "'", :Quote
end

Logos.define StringContext do
  extras SymbolTable
  error_type Nil

  token "'", :Quote
  regex "[^'$]+", :Content

  token "${", :InterpolationStart do |lex|
    evaluate_interpolation(lex)
  end

  token "$", :DollarSign
end

Logos.define StringInterpolationContext do
  extras SymbolTable
  error_type Nil
  skip_regex "\\s+", :Whitespace

  regex "[[:alpha:]][[:alnum:]]*", :Id do |lex|
    value = lex.extras[lex.slice]?
    Logos::Filter::Emit.new(value || "")
  end

  token "'", :Quote
  token "}", :InterpolationEnd
end

private def get_string_content(lex : Logos::Lexer(StringContext, String, SymbolTable, Nil)) : String
  String.build do |io|
    while token = lex.next
      break if token.is_a?(Iterator::Stop)
      result = token.as(Logos::Result(StringContext, Nil))
      next unless result.ok?

      case result.unwrap
      when StringContext::Content
        io << lex.slice
      when StringContext::DollarSign
        io << "$"
      when StringContext::InterpolationStart
        value = lex.callback_value_as(String)
        io << value if value
      when StringContext::Quote
        break
      end
    end
  end
end

private def evaluate_interpolation(lex : Logos::Lexer(StringContext, String, SymbolTable, Nil))
  inter = lex.clone.morph(StringInterpolationContext)
  buffer = String.build do |io|
    while token = inter.next
      break if token.is_a?(Iterator::Stop)
      result = token.as(Logos::Result(StringInterpolationContext, Nil))
      next unless result.ok?

      case result.unwrap
      when StringInterpolationContext::Id
        value = inter.callback_value_as(String)
        io << value if value
      when StringInterpolationContext::Quote
        string_lex = inter.clone.morph(StringContext)
        nested = get_string_content(string_lex)
        delta = string_lex.span.end - inter.span.end
        inter.bump(delta)
        io << nested
      when StringInterpolationContext::InterpolationEnd
        break
      end
    end
  end

  # Advance original lexer past the interpolation.
  delta = inter.span.end - lex.span.end
  lex.bump(delta)

  Logos::Filter::Emit.new(buffer)
end

private def expect_definition(token, &)
  if token.is_a?(Iterator::Stop)
    raise "expected definition"
  end

  result = token.as(Logos::Result(VariableDefinitionContext, Nil))
  unless result.ok? && result.unwrap == VariableDefinitionContext::Id
    raise "expected definition"
  end

  value = yield
  value
end

lex = VariableDefinitionContext.lexer(
  "name = 'Mark'\n" +
  "greeting = 'Hi ${name}!'\n" +
  "surname = 'Scott'\n" +
  "greeting2 = 'Hi ${name ' ' surname}!'\n" +
  "greeting3 = 'Hi ${name ' ${surname}!'}!'\n"
)

expect_definition(lex.next) do
  tuple = lex.callback_value_as(Tuple(String, String)).not_nil!
  puts "#{tuple[0]} = #{tuple[1]}"
end

expect_definition(lex.next) do
  tuple = lex.callback_value_as(Tuple(String, String)).not_nil!
  puts "#{tuple[0]} = #{tuple[1]}"
end

expect_definition(lex.next) do
  tuple = lex.callback_value_as(Tuple(String, String)).not_nil!
  puts "#{tuple[0]} = #{tuple[1]}"
end

expect_definition(lex.next) do
  tuple = lex.callback_value_as(Tuple(String, String)).not_nil!
  puts "#{tuple[0]} = #{tuple[1]}"
end

expect_definition(lex.next) do
  tuple = lex.callback_value_as(Tuple(String, String)).not_nil!
  puts "#{tuple[0]} = #{tuple[1]}"
end
