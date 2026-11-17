require "./benchmark_token"
require "../temp/generated_benchmark_token"

source = {{ read_file(__DIR__ + "/lexer_compare_input.txt") }} * 1_000
bytes = source.to_slice
matcher = Logos.generated_matcher?("BenchmarkToken") || raise "generated benchmark matcher missing"
manifest = JSON.parse(String.build { |io| BenchmarkToken.write_prebuild_manifest(io) })
whitespace = manifest["patterns"].as_a.index(&.["skip"].as_bool) || raise "benchmark skip rule missing"
rounds = ENV.fetch("LOGOS_BENCH_ROUNDS", "10").to_i

count = 0
rounds.times do
  offset = 0
  while offset < bytes.size
    case result = matcher.call(bytes, offset)
    when Tuple
      width, id = result
      raise "expected a positive-length single winner" unless width > 0 && id.is_a?(Regex::Automata::PatternID)
      offset += width
      count += 1 unless id.to_i == whitespace
    else
      raise "unexpected unmatched input"
    end
  end
end
puts count
