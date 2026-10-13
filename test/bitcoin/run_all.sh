#!/usr/bin/env bash
# Прогон проверок патчей lib/bitcoin (signet + OpenSSL 3).
#
#   bash test/bitcoin/run_all.sh                 # ruby из PATH
#   bash test/bitcoin/run_all.sh /usr/bin/ruby   # другой Ruby
#
# Проверяет: векторы BIP32/BIP39/BIP84 + подписи (openssl3_check.rb)
# и подписи реальных транзакций signet (verify_real_signet_tx.rb).
# Отдельно есть test/bitcoin/gem_spec_matrix.sh — прогон родного спека
# bitcoin-ruby с патчем и без.
set -uo pipefail

RUBY="${1:-ruby}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================================="
echo "Ruby:    $("$RUBY" -v)"
echo "OpenSSL: $("$RUBY" -ropenssl -e 'print OpenSSL::OPENSSL_VERSION')"
echo "gems:    bitcoin-ruby $("$RUBY" -e 'require "bitcoin/version"; print Bitcoin::VERSION' 2>/dev/null)"
echo "=============================================================="

fail=0

run() {
  local name="$1"; shift
  printf '\n### %s\n' "$name"
  if "$@"; then printf '### %s: OK\n' "$name"; else printf '### %s: FAIL\n' "$name"; fail=1; fi
}

check_vectors() {
  "$RUBY" "$HERE/openssl3_check.rb" | grep -q "Готово" &&
    [ "$("$RUBY" "$HERE/openssl3_check.rb" | grep -c '^OK')" -eq 15 ]
}

check_network() {
  "$RUBY" "$HERE/verify_real_signet_tx.rb" | grep -q "Все проверенные транзакции signet валидны"
}

run "openssl3_check.rb — 15 векторов и подписей" check_vectors
run "verify_real_signet_tx.rb — подписи реальных транзакций signet" check_network

echo
[ "$fail" -eq 0 ] && echo "ИТОГ: всё зелёное." || echo "ИТОГ: есть падения (см. выше)."
exit "$fail"
