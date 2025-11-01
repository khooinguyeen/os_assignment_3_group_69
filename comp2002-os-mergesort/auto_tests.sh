#!/usr/bin/env bash

# Lightweight harness for ad-hoc testing of test-mergesort.
# Prerequisites: make all to build test-mersort.o for testing 
# Usage examples:
#   ./auto_tests.sh integration
#   ./auto_tests.sh correctness
#   ./auto_tests.sh performance
#   ./auto_tests.sh stress
#   ./auto_tests.sh all
#   ./auto_tests.sh integration ./build/test-mergesort

set -euo pipefail

MODE="${1:-}"
BIN="${2:-./test-mergesort}"

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <mode> [path-to-test-mergesort]"
  echo "Modes: integration | correctness | performance | stress | all"
  exit 1
fi

if [[ ! -x "$BIN" ]]; then
  echo "Error: $BIN is not executable: $BIN"
  exit 2
fi

echo "Using tester: $BIN"
echo "Selected mode: $MODE"

RESULT_ROOT="${RESULT_ROOT:-auto_test_outputs}"
# start fresh each run to avoid mixing old CSVs
rm -rf "$RESULT_ROOT"
mkdir -p "$RESULT_ROOT"

# --------------------------------------------------------------
# Shared helper for running an individual test command
# --------------------------------------------------------------
log_run() {
  local label="$1"
  local n="$2"
  local cutoff="$3"
  local seed="$4"
  local outfile="$5"
  local mode="${6:-}"
  local output status time
  local cmd=("$BIN" "$n" "$cutoff" "$seed")

  # optional mode argument if provided
  if [[ -n "$mode" ]]; then
    cmd+=("$mode")
  fi

  # log the command so long-running stages show progress
  echo "${label} (n=${n}, cutoff=${cutoff}, seed=${seed})"
  [[ -n "$mode" ]] && echo "   mode=${mode}"

  # capture exit status (success 0) and stdout/stderr
  if output=$("${cmd[@]}" 2>&1); then
    status="PASS"
  else
    status="FAIL"
  fi

  # echo raw output for debugging context
  printf "%s\n" "$output"

  # parse the time from the tester's message if present
  time=$(printf "%s\n" "$output" | awk '/Sorting/{print $(NF-1)}')
  [[ -z "$time" ]] && time="N/A"

  printf "%s,%s,%s,%s,%s,%s,%s\n" "$label" "$n" "$cutoff" "$seed" "$mode" "$time" "$status" >> "$outfile"

  [[ "$status" == "FAIL" ]] && return 1 || return 0
}

# --------------------------------------------------------------
# Integration smoke tests (fixed + randomised run)
# --------------------------------------------------------------
integration_testing() {
  local result_file="$RESULT_ROOT/integration_results.csv"
  printf "TestType,InputSize,Cutoff,Seed,Mode,Time,Status\n" > "$result_file"

  echo "Running Integration Tests..."

  log_run "integration-fixed" 5000 0 1234 "$result_file"

  # pick size in [10000, 20000]
  local n=$(( (RANDOM % 10001) + 10000 ))
  # pick cutoff in [1, 3]
  local cutoff=$(( (RANDOM % 3) + 1 ))
  local seed=$RANDOM
  log_run "integration-random" "$n" "$cutoff" "$seed" "$result_file"
}

# --------------------------------------------------------------
# Correctness sweep (size/cutoff/seeds + edge arrays)
# --------------------------------------------------------------
correctness_testing() {
  local result_file="$RESULT_ROOT/correctness_results.csv"
  printf "TestType,InputSize,Cutoff,Seed,Mode,Time,Status\n" > "$result_file"

  local seeds=(69 1234 99999)
  local sizes=(10 100 1000 10000 100000 1000000 10000000)
  local cutoffs=(1 2 3)

  echo "Running Correctness Tests..."

  # sweep every size/cutoff/seed triple
  for n in "${sizes[@]}"; do
    for cutoff in "${cutoffs[@]}"; do
      for seed in "${seeds[@]}"; do
        log_run "correctness" "$n" "$cutoff" "$seed" "$result_file"
      done
    done
  done

  # Focused boundary scenarios
  log_run "correctness-n2level0" 2 0 99 "$result_file"
  log_run "correctness-n2level1" 2 1 999 "$result_file"
  log_run "correctness-cutoff0" 1000 0 2025 "$result_file"
  log_run "correctness-sorted" 1000000 2 999 "$result_file" "sorted"
  log_run "correctness-descending" 1000000 2 999 "$result_file" "descending"
  log_run "correctness-equal" 1000000 2 999 "$result_file" "equal"
}

# --------------------------------------------------------------
# Performance check (single size 100000000, cutoffs 0-10, log speedups)
# --------------------------------------------------------------
performance_testing() {
  local result_file="$RESULT_ROOT/performance_results.csv"
  printf "TestType,InputSize,Cutoff,Seed,Mode,Time,Status\n" > "$result_file"
  # humans-readable summary (cutoff, runtime, speedup)
  local summary_file="$RESULT_ROOT/performance_summary.txt"
  : > "$summary_file"

  local n=100000000
  local cutoffs=(0 1 2 3 4 5 6 7 8 9 10)
  local seed=9999

  echo "Running Performance Tests..."
  # holds the cutoff=0 timing for later speedup calculations
  local serial_time=""  

  # iterate across cutoffs and compute relative speedups
  for cutoff in "${cutoffs[@]}"; do
    echo "  => cutoff=${cutoff}"
    local output time status="PASS"

    # run the tester at this cutoff and capture stdout/stderr
    output=$("$BIN" "$n" "$cutoff" "$seed" 2>&1) || status="FAIL"
    printf "%s\n" "$output"

    # take the time from test-mergesort output
    time=$(printf "%s\n" "$output" | awk '/Sorting/{print $(NF-1)}')
    [[ -z "$time" ]] && time="N/A"

    if [[ "$cutoff" -eq 0 ]]; then
      serial_time="$time"
      echo "    baseline runtime = $serial_time s"
      # stash raw runtime for reference
      printf "cutoff=%s runtime=%s (baseline)\n" "$cutoff" "$time" >> "$summary_file"
    else
      if [[ "$time" != "N/A" && "$serial_time" != "N/A" ]]; then
        local speedup
        speedup=$(awk -v s="$serial_time" -v p="$time" 'BEGIN{if (p>0) printf "%.2f", s/p; else print "N/A"}')
        echo "    speedup vs cutoff=0 => $speedup"
        # log both runtime and computed speedup 
        printf "cutoff=%s runtime=%s speedup=%s\n" "$cutoff" "$time" "$speedup" >> "$summary_file"
      else
        echo "    speedup unavailable (timing missing)"
        printf "cutoff=%s runtime=%s speedup=N/A\n" "$cutoff" "$time" >> "$summary_file"
      fi
    fi

    printf "performance,%s,%s,%s,,%s,%s\n" "$n" "$cutoff" "$seed" "$time" "$status" >> "$result_file"
  done
}

# --------------------------------------------------------------
# Stress (high cutoffs + repeat load for large array size)
# --------------------------------------------------------------
stress_testing() {
  local result_file="$RESULT_ROOT/stress_results.csv"
  printf "TestType,InputSize,Cutoff,Seed,Mode,Time,Status\n" > "$result_file"

  local n=100000000
  local base_seed=676
  local cutoffs=(8 9 10 11 12 13 14)

  echo "Running primary stress sweep..."
  # push the thread creation depth aggresively higher
  for cutoff in "${cutoffs[@]}"; do
    echo "  => cutoff=${cutoff}, seed=${base_seed}"
    log_run "stress" "$n" "$cutoff" "$base_seed" "$result_file"
  done

  echo "Running repeated high-load pass (cutoff=8, varying seeds)..."
  # same heavy case, but flip seeds to check stability
  for seed in 2023 2024 2025 2026; do
    echo "  => cutoff=8, seed=${seed}"
    log_run "stress-repeat" "$n" 8 "$seed" "$result_file"
  done
}

# --------------------------------------------------------------
# Entry point dispatcher
# --------------------------------------------------------------
case "$MODE" in
  integration)
    integration_testing
    ;;
  correctness)
    correctness_testing
    ;;
  performance)
    performance_testing
    ;;
  stress)
    stress_testing
    ;;
  all)
    integration_testing
    correctness_testing
    performance_testing
    stress_testing
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 3
    ;;
esac
