#!/usr/bin/env bash
set -euo pipefail

contract=$1
crystal=$2
rust=$3
matcher_only=$4

# Exercise keyword priority, UTF-8 errors, skipped input and EOF.
IFS= read -r benchmark_line < benchmarks/lexer_compare_input.txt
cases=("$benchmark_line"$'\n' 'letter let let1 _a 0;' 'é = ? 99' '' $' \n\t')
"$contract" --spans "${cases[@]}" > temp/benchmark-crystal.spans
"$rust" --spans "${cases[@]}" > temp/benchmark-rust.spans
diff -u temp/benchmark-rust.spans temp/benchmark-crystal.spans

for binary in "$crystal" "$rust" "$matcher_only"; do
  count=$(LOGOS_BENCH_ROUNDS=1 "$binary")
  if [[ $count != 5000 ]]; then
    printf '%s emitted %s tokens, expected 5000\n' "$binary" "$count" >&2
    exit 1
  fi
done
printf 'Release token, span, EOF and count contract passed\n'
