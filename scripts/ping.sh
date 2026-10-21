#!/usr/bin/env bash
# Reads SUPABASE_PROJECTS (one project per line):
#   <project-url> <publishable-or-anon-key> <table-name>
# e.g.
#   https://abcd1234.supabase.co eyJhbGciOi... profiles
# Runs a one-row select on that table. Even if RLS returns no rows,
# the query still hits the database, which counts as activity.
set -uo pipefail

if [ -z "${SUPABASE_PROJECTS:-}" ]; then
  echo "SUPABASE_PROJECTS secret is empty — add it in Settings > Secrets and variables > Actions."
  exit 1
fi

failed=0
n=0
while read -r url key table; do
  [ -z "${url:-}" ] && continue
  case "$url" in \#*) continue ;; esac
  n=$((n + 1))
  ref=$(echo "$url" | sed -E 's#https?://([^.]+)\..*#\1#')
  # New sb_publishable_ keys go in the apikey header only; legacy eyJ... keys also need Authorization.
  auth=()
  case "$key" in eyJ*) auth=(-H "Authorization: Bearer ${key}") ;; esac
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    "${url%/}/rest/v1/${table}?select=*&limit=1" \
    -H "apikey: ${key}" "${auth[@]}")
  if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
    echo "✓ ${ref} (${table}) — HTTP ${code}"
  else
    echo "✗ ${ref} (${table}) — HTTP ${code} (paused, wrong key, or table name wrong)"
    failed=1
  fi
done <<< "$SUPABASE_PROJECTS"

echo "Pinged ${n} project(s)."
exit $failed
