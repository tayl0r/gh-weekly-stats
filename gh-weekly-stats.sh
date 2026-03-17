#!/usr/bin/env bash
set -euo pipefail

USER="${1:-tayl0r}"
SINCE="${2:-$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)}"
UNTIL="${3:-$(date +%Y-%m-%d)}"
TMPFILE="/tmp/gh-weekly-stats-$$"
trap 'rm -f "$TMPFILE"' EXIT

echo "GitHub Stats for $USER ($SINCE → $UNTIL)"
echo "============================================="
echo ""

# Paginate by weekly chunks to avoid the 100-result search API cap
prs="[]"
chunk_start="$SINCE"
while [[ "$chunk_start" < "$UNTIL" || "$chunk_start" == "$UNTIL" ]]; do
  chunk_end=$(date -j -v+6d -f %Y-%m-%d "$chunk_start" +%Y-%m-%d 2>/dev/null \
    || date -d "$chunk_start + 6 days" +%Y-%m-%d)
  if [[ "$chunk_end" > "$UNTIL" ]]; then
    chunk_end="$UNTIL"
  fi
  batch=$(gh search prs --author="$USER" --merged --merged-at="$chunk_start..$chunk_end" --json repository,title,number --limit 200)
  prs=$(echo "$prs" "$batch" | jq -s 'add | unique_by(.repository.nameWithOwner + "#" + (.number | tostring))')
  chunk_start=$(date -j -v+7d -f %Y-%m-%d "$chunk_start" +%Y-%m-%d 2>/dev/null \
    || date -d "$chunk_start + 7 days" +%Y-%m-%d)
done

count=$(echo "$prs" | jq length)

if [ "$count" -eq 0 ]; then
  echo "No merged PRs found."
  exit 0
fi

echo "Merged PRs: $count"
echo ""

printf "%-50s %6s %8s %8s %8s\n" "PR" "#" "+Lines" "-Lines" "Net"
printf "%-50s %6s %8s %8s %8s\n" "--" "-" "------" "------" "---"

echo "$prs" | jq -c '.[]' | while read -r pr; do
  repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')
  num=$(echo "$pr" | jq -r '.number')
  title=$(echo "$pr" | jq -r '.title' | cut -c1-46)

  stats=$(gh api "repos/$repo/pulls/$num" --jq '.additions, .deletions' 2>/dev/null || echo "0 0")
  added=$(echo "$stats" | head -1)
  deleted=$(echo "$stats" | tail -1)
  net=$((added - deleted))

  printf "%-50s %6s %8s %8s %8s\n" "$title" "#$num" "+$added" "-$deleted" "$net"

  echo "$added $deleted" >> "$TMPFILE"
done

echo ""
echo "---------------------------------------------"

if [ -f "$TMPFILE" ]; then
  total_added=$(awk '{s+=$1} END {print s}' "$TMPFILE")
  total_deleted=$(awk '{s+=$2} END {print s}' "$TMPFILE")
  total_net=$((total_added - total_deleted))

  printf "%-50s %6s %8s %8s %8s\n" "TOTAL" "" "+$total_added" "-$total_deleted" "$total_net"
else
  echo "No stats collected."
fi
