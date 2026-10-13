#!/usr/bin/env bash
# Прогон тестов lib/wallet (все офлайн: сеть подменена, ключи локальные).
#
#   bash test/wallet/run_all.sh                 # ruby из PATH
#   bash test/wallet/run_all.sh /usr/bin/ruby   # другой Ruby
#   mise run test                               # через задачу mise
set -uo pipefail

RUBY="${1:-ruby}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================================="
echo "Ruby:    $("$RUBY" -v)"
echo "OpenSSL: $("$RUBY" -ropenssl -e 'print OpenSSL::OPENSSL_VERSION')"
echo "=============================================================="

fail=0

run() {
  local name="$1"; shift
  printf '\n### %s\n' "$name"
  if "$@"; then printf '### %s: OK\n' "$name"; else printf '### %s: FAIL\n' "$name"; fail=1; fi
}

for t in dto mappers network http_client mempool_client api_client \
         private_key account transaction arguments presenter cli repl; do
  run "test/wallet/${t}_test.rb" "$RUBY" "$HERE/${t}_test.rb"
done

echo
[ "$fail" -eq 0 ] && echo "ИТОГ: всё зелёное." || echo "ИТОГ: есть падения (см. выше)."
exit "$fail"
