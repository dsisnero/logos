"""Compare two release lexers with alternating command order."""

import argparse
import json
import os
from pathlib import Path
import resource
import statistics
import subprocess
import time


def measure(binary, rounds):
    env = dict(os.environ, LOGOS_BENCH_ROUNDS=str(rounds))
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    started = time.perf_counter()
    count = subprocess.check_output([binary.resolve()], env=env, text=True)
    elapsed = time.perf_counter() - started
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    if count.strip() != str(5_000 * rounds):
        raise RuntimeError(f"{binary} emitted {count.strip()} tokens")
    cpu = (after.ru_utime - before.ru_utime) + (after.ru_stime - before.ru_stime)
    return {"wall": elapsed, "cpu": cpu}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--rounds", type=int, default=6000)
    parser.add_argument("--pairs", type=int, default=16)
    parser.add_argument("--output", type=Path, help="save individual timings as JSON")
    args = parser.parse_args()
    if args.rounds < 1 or args.pairs < 2 or args.pairs % 2:
        parser.error("use positive rounds and an even number of pairs")

    binaries = {"baseline": args.baseline, "candidate": args.candidate}
    for _ in range(2):
        for binary in binaries.values():
            measure(binary, args.rounds)

    pairs = []
    for index in range(args.pairs):
        order = binaries if index % 2 == 0 else reversed(binaries)
        pairs.append({name: measure(binaries[name], args.rounds) for name in order})

    if args.output:
        args.output.write_text(json.dumps({"rounds": args.rounds, "pairs": pairs}, indent=2) + "\n")

    for metric in ("wall", "cpu"):
        for name in binaries:
            samples = [pair[name][metric] for pair in pairs]
            print(f"{metric} {name}: {statistics.mean(samples):.3f} s mean, "
                  f"{statistics.stdev(samples):.3f} s SD")
        ratios = [pair["candidate"][metric] / pair["baseline"][metric] for pair in pairs]
        wins = sum(ratio < 1 for ratio in ratios)
        print(f"{metric}: median candidate/baseline {statistics.median(ratios):.3f}, "
              f"candidate faster in {wins}/{args.pairs} pairs")


if __name__ == "__main__":
    main()
