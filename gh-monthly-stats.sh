#!/usr/bin/env bash
exec "$(dirname "$0")/gh-weekly-stats.sh" "${1:-tayl0r}" "$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)"
