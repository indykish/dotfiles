#!/usr/bin/env bash
# Pull Zoho Desk tickets year-by-year: 2021 through 2026.
# Safe for Enterprise plan (985k credits/day); total ~80k credits (~8% of budget).
#
# Output: zoho-desk-export/<YYYY>/<MM>/<DDHHMMSS>_<ticket#>.txt
#
# Usage: bash scripts/pull-all-years.sh

set -euo pipefail

SCRIPT=".config/e2e/agent-profiles/zoho-desk.mjs"
CONCURRENCY=10
MIN_DELAY_MS=100
CREDIT_BUFFER=10000

years=(2021 2022 2023 2024 2025 2026)

for year in "${years[@]}"; do
  echo "=== Pulling $year ==="
  bun "$SCRIPT" pull \
    --since "${year}-01-01" \
    --until "${year}-12-31" \
    --output "./zoho-desk-export" \
    --concurrency "$CONCURRENCY" \
    --min-delay-ms "$MIN_DELAY_MS" \
    --credit-buffer "$CREDIT_BUFFER"
  echo ""
done

echo ""
echo "All years complete."
