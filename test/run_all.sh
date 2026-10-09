#!/usr/bin/env bash
# Прогон всего набора проверок на заданном Ruby.
#
#   bash test/run_all.sh                 # ruby из PATH
#   bash test/run_all.sh /usr/local/bin/ruby
#   bash test/run_all.sh /usr/bin/ruby   # Ruby 3.3.8
#
# Проверяет: векторы BIP32/BIP39/BIP84 + подписи, адреса signet,
# сборку/подпись транзакций, независимую проверку подписей через embit
# и подписи реальных транзакций из сети signet.
set -uo pipefail

RUBY="${1:-ruby}"
PYTHON="${PYTHON:-$(command -v python3)}"   # нужен интерпретатор с установленным embit
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
cd "$ROOT"

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

check_vectors() { "$RUBY" test/openssl3_check.rb | grep -q "Готово" && [ "$("$RUBY" test/openssl3_check.rb | grep -c '^OK')" -eq 15 ]; }
check_addresses() { "$RUBY" examples/01_addresses.rb | grep -q "OK: signet-адреса"; }
check_spends() {  # rubocop:disable Lint/UnusedMethodArgument
  "$RUBY" examples/02_build_spend.rb | grep -q "Все транзакции подписаны" &&
  "$PYTHON" test/crosscheck_embit.py | grep -q "9/9"
}
check_network() { "$RUBY" test/verify_real_signet_tx.rb | grep -q "Все проверенные транзакции signet валидны"; }

run "test/openssl3_check.rb — 15 векторов и подписей" check_vectors
run "examples/01_addresses.rb — адреса signet" check_addresses
run "examples/02_build_spend.rb + crosscheck_embit.py — сборка, подпись, независимая проверка" check_spends
run "test/verify_real_signet_tx.rb — подписи реальных транзакций signet" check_network

echo
[ "$fail" -eq 0 ] && echo "ИТОГ: всё зелёное." || echo "ИТОГ: есть падения (см. выше)."
exit "$fail"
