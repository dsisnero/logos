# Simple calculator using Logos.
#
# Usage:
#   crystal run examples/calculator.cr -- "1 + 7 * (3 - 4) / 2"

require "logos"

Logos.define Token do
  error_type Nil
  skip_regex "[ \t\n]+", :Whitespace

  token "+", :Plus
  token "-", :Minus
  token "*", :Multiply
  token "/", :Divide
  token "(", :LParen
  token ")", :RParen

  regex "[0-9]+", :Integer do |lex|
    Logos::Filter::Emit.new(lex.slice.to_i64)
  end
end

struct TokenEntry
  getter token : Token
  getter value : Int64?

  def initialize(@token : Token, @value : Int64?)
  end
end

abstract class Expr
  abstract def eval : Int64
end

class IntExpr < Expr
  def initialize(@value : Int64)
  end

  def eval : Int64
    @value
  end

  def to_s(io : IO) : Nil
    io << @value
  end
end

class NegExpr < Expr
  def initialize(@rhs : Expr)
  end

  def eval : Int64
    -@rhs.eval
  end

  def to_s(io : IO) : Nil
    io << "(-" << @rhs << ")"
  end
end

class BinExpr < Expr
  def initialize(@op : Symbol, @lhs : Expr, @rhs : Expr)
  end

  def eval : Int64
    case @op
    when :add
      @lhs.eval + @rhs.eval
    when :sub
      @lhs.eval - @rhs.eval
    when :mul
      @lhs.eval * @rhs.eval
    when :div
      @lhs.eval // @rhs.eval
    else
      raise "unknown op"
    end
  end

  def to_s(io : IO) : Nil
    op_str = case @op
             when :add
               "+"
             when :sub
               "-"
             when :mul
               "*"
             when :div
               "/"
             else
               "?"
             end
    io << "(" << @lhs << " " << op_str << " " << @rhs << ")"
  end
end

class Parser
  def initialize(@tokens : Array(TokenEntry))
    @index = 0
  end

  def parse : Expr
    expr = parse_add_sub
    if current
      raise "unexpected token: #{current.not_nil!.token}"
    end
    expr
  end

  private def parse_add_sub : Expr
    lhs = parse_mul_div
    loop do
      if match?(Token::Plus)
        rhs = parse_mul_div
        lhs = BinExpr.new(:add, lhs, rhs)
      elsif match?(Token::Minus)
        rhs = parse_mul_div
        lhs = BinExpr.new(:sub, lhs, rhs)
      else
        break
      end
    end
    lhs
  end

  private def parse_mul_div : Expr
    lhs = parse_unary
    loop do
      if match?(Token::Multiply)
        rhs = parse_unary
        lhs = BinExpr.new(:mul, lhs, rhs)
      elsif match?(Token::Divide)
        rhs = parse_unary
        lhs = BinExpr.new(:div, lhs, rhs)
      else
        break
      end
    end
    lhs
  end

  private def parse_unary : Expr
    if match?(Token::Minus)
      NegExpr.new(parse_unary)
    else
      parse_atom
    end
  end

  private def parse_atom : Expr
    if match?(Token::LParen)
      expr = parse_add_sub
      expect(Token::RParen)
      return expr
    end

    entry = advance
    raise "expected integer" if entry.nil?

    if entry.token == Token::Integer
      IntExpr.new(entry.value.not_nil!)
    else
      raise "expected integer"
    end
  end

  private def match?(token : Token) : Bool
    if current.try(&.token) == token
      @index += 1
      true
    else
      false
    end
  end

  private def expect(token : Token) : Nil
    unless match?(token)
      raise "expected #{token}"
    end
  end

  private def current : TokenEntry?
    @tokens[@index]?
  end

  private def advance : TokenEntry?
    entry = current
    @index += 1
    entry
  end
end

if ARGV.empty?
  abort "Expected expression argument"
end

input = ARGV.first
lexer = Token.lexer(input)
entries = [] of TokenEntry

while token = lexer.next
  break if token.is_a?(Iterator::Stop)
  result = token.as(Logos::Result(Token, Nil))
  if result.ok?
    value = lexer.callback_value_as(Int64)
    entries << TokenEntry.new(result.unwrap, value)
  else
    raise "lexer error at #{lexer.span}"
  end
end

parser = Parser.new(entries)
expr = parser.parse
puts "[AST]\n#{expr}"
puts "\n[result]\n#{expr.eval}"
