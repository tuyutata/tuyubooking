#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"

files="
host/database/tuyu_core.sql
"

for file in $files; do
    test -s "$file"
    rg -q '^BEGIN;$' "$file"
    rg -q '^COMMIT;$' "$file"
    rg -q 'uuid PRIMARY KEY' "$file"
    rg -q 'timestamptz' "$file"
    rg -q 'version bigint NOT NULL DEFAULT 1 CHECK [(]version > 0[)]' "$file"

    duplicates=$(sed -nE 's/^CREATE TABLE ([a-z_]+[.][a-z_]+).*/\1/p' "$file" | sort | uniq -d)
    if [ -n "$duplicates" ]; then
        echo "Duplicate table declarations in $file: $duplicates" >&2
        exit 1
    fi
done

rg -q 'CREATE TABLE tuyu_core.local_system_administrator' host/database/tuyu_core.sql
rg -q 'public_key bytea NOT NULL CHECK [(]octet_length[(]public_key[)] = 32[)]' host/database/tuyu_core.sql
rg -q 'initialized_at timestamptz' host/database/tuyu_core.sql
rg -qF "CHECK (status IN ('active', 'disabled'))" host/database/tuyu_core.sql
rg -q 'local_system_administrator_identity_immutable' host/database/tuyu_core.sql
if rg -q "'revoked'" host/database/tuyu_core.sql; then
    echo "Revoked administrator status is forbidden; use disabled or physical deletion" >&2
    exit 1
fi
rg -q 'CREATE TABLE IF NOT EXISTS tuyu_core.administrator_assertion' host/database/tuyu_core.sql
if rg -q 'external_administrator_cache|verified_signer_session' host/database/tuyu_core.sql; then
    echo "Legacy remote administrator cache is forbidden" >&2
    exit 1
fi

for forbidden in private_key mnemonic seed_phrase; do
    if rg -n -i "$forbidden" $files >/dev/null; then
        echo "Forbidden secret field in schema: $forbidden" >&2
        exit 1
    fi
done

plain_http=$(printf 'http:\057\057')
if rg -n -F "$plain_http" $files test/specifications/behavior/validate_schema.sh >/dev/null; then
    echo "Plain HTTP is forbidden" >&2
    exit 1
fi

table_count=$(sed -nE 's/^CREATE TABLE .*/x/p' $files | wc -l | tr -d ' ')
if [ "$table_count" -ne 17 ]; then
    echo "Expected exactly 17 tuyu_core tables, found $table_count" >&2
    exit 1
fi

echo "TuyuBooking native PostgreSQL baseline: PASS ($table_count tuyu_core tables)"
