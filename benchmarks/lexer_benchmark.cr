require "benchmark"
require "../src/logos"

Logos.define BenchmarkToken do
  skip_regex "[ \\t\\r\\n]+", :Whitespace
  token "let", :Let
  token "=", :Equals
  token ";", :Semicolon
  regex "[A-Za-z_][A-Za-z0-9_]*", :Identifier
  regex "[0-9]+", :Integer
end

SOURCE = ("let variable = 12345;\n" * 1_000)

def lex_all : Int32
  lexer = BenchmarkToken.lexer(SOURCE)
  count = 0
  while token = lexer.next
    break if token.is_a?(Iterator::Stop)
    count += 1
  end
  count
end

elapsed = Time.measure { lex_all }
puts "first_use_ms=#{elapsed.total_milliseconds.round(2)}"

Benchmark.ips do |x|
  x.report("lex 1,000 lines") { lex_all }
end
