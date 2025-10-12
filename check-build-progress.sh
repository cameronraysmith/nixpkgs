#!/usr/bin/env bash

review_dir="$HOME/.cache/nixpkgs-review/rev-f5e58da373f3d72e22f21336da8a1c5aef886099"

echo "=== Build Progress at $(date '+%H:%M:%S') ==="
echo ""

if [ -d "$review_dir/results" ]; then
  success_count=$(ls -1 "$review_dir/results" 2>/dev/null | wc -l | tr -d ' ')
  echo "Successful builds: $success_count"
else
  echo "No successful builds yet"
fi

echo ""

if [ -d "$review_dir/failed_results" ]; then
  failure_count=$(ls -1 "$review_dir/failed_results" 2>/dev/null | wc -l | tr -d ' ')
  echo "Failed builds: $failure_count"
  if [ "$failure_count" -gt 0 ]; then
    echo ""
    echo "Failed packages:"
    ls -1 "$review_dir/failed_results" 2>/dev/null
  fi
else
  echo "No failed builds yet"
fi

echo ""
echo "Total packages to build: 665"
