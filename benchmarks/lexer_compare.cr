require "./benchmark_token"

{% if flag?(:precompiled) %}
  require "../temp/generated_benchmark_token"
{% end %}

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
