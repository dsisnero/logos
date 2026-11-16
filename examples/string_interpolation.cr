# String interpolation example using Logos.
#
# Usage:
#   crystal run examples/string_interpolation.cr

require "../src/logos"

alias SymbolTable = Hash(String, String)

Logos.define VariableDefinitionContext do
  extras SymbolTable
  error_type Nil
  skip_regex "\\s+", :Whitespace

  regex "[[:alpha:]][[:alnum:]]*", :Id do |lex|
    id = lex.slice
    lookahead = lex.clone
    next_token = lookahead.next
    if next_token.is_a?(Iterator::Stop)
      false
    elsif !(next_result = next_token.as(Logos::Result(VariableDefinitionContext, Nil))).ok? ||
          next_result.unwrap != VariableDefinitionContext::Equals
      false
    else
      next_token = lookahead.next
      if next_token.is_a?(Iterator::Stop)
        false
      elsif !(next_result = next_token.as(Logos::Result(VariableDefinitionContext, Nil))).ok? ||
            next_result.unwrap != VariableDefinitionContext::Quote
        false
      else
        string_lex = lookahead.morph(StringContext)
        value = get_string_content(string_lex)
        delta = string_lex.span.end - lex.span.end
        lex.bump(delta)
        lex.extras[id] = value
        Logos::Filter::Emit.new({id, value})
      end
    end
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
        io << result.payload_for!(StringContext::InterpolationStart, String)
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
        io << result.payload_for!(StringInterpolationContext::Id, String)
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

lex = VariableDefinitionContext.lexer(
  "name = 'Mark'\n" +
  "greeting = 'Hi ${name}!'\n" +
  "surname = 'Scott'\n" +
  "greeting2 = 'Hi ${name ' ' surname}!'\n" +
  "greeting3 = 'Hi ${name ' ${surname}!'}!'\n"
)

lex.each do |result|
  name, value = result.payload_for!(VariableDefinitionContext::Id, Tuple(String, String))
  puts "#{name} = #{value}"
end
