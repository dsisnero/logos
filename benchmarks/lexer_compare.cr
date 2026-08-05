require "../src/logos"

{% if flag?(:precompiled) %}
  require "../temp/generated_benchmark_token"
{% end %}

Logos.define BenchmarkToken do
  skip_regex "[ \t\r\n]+", :Whitespace
  token "let", :Let
  token "=", :Equals
  token ";", :Semicolon
  regex "[A-Za-z_][A-Za-z0-9_]*", :Identifier
  regex "[0-9]+", :Integer
end

SOURCE = ("let variable = 12345;\n" * 1_000)
ROUNDS = ENV.fetch("LOGOS_BENCH_ROUNDS", "10").to_i

count = 0
ROUNDS.times do
  lexer = BenchmarkToken.lexer(SOURCE)
  while token = lexer.next
    break if token.is_a?(Iterator::Stop)
    count += 1
  end
end
puts count
