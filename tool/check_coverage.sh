#!/usr/bin/env bash
set -euo pipefail

coverage_file="${1:-coverage/lcov.info}"
threshold="${NEXTPLAY_COVERAGE_THRESHOLD:-15}"

if [[ ! -f "$coverage_file" ]]; then
  echo "Coverage file not found: $coverage_file" >&2
  exit 1
fi

read -r covered total < <(
  awk -F: '
    /^LH:/ { covered += $2 }
    /^LF:/ { total += $2 }
    END { printf "%d %d\n", covered, total }
  ' "$coverage_file"
)

if (( total == 0 )); then
  echo "Coverage file contains no executable lines." >&2
  exit 1
fi

percentage="$(awk -v covered="$covered" -v total="$total" 'BEGIN { printf "%.2f", covered * 100 / total }')"
echo "Line coverage: ${percentage}% (${covered}/${total}); required: ${threshold}%"

awk -v actual="$percentage" -v required="$threshold" 'BEGIN { exit !(actual + 0 >= required + 0) }' || {
  echo "Coverage is below the required threshold." >&2
  exit 1
}
