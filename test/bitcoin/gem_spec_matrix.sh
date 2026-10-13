#!/usr/bin/env bash
# Прогон РОДНОГО набора спек bitcoin-ruby в четырёх конфигурациях:
#   {без патча, с патчем signet+openssl3} x {текущий Ruby}
# Сравнивать удобно, запуская скрипт для каждого Ruby:
#
#   bash test/bitcoin/gem_spec_matrix.sh /usr/local/bin/ruby          # Ruby 4.0.7
#   bash test/bitcoin/gem_spec_matrix.sh /usr/bin/ruby                # Ruby 3.3.8
#
# Гем скачивается в /tmp/bitcoin-ruby-matrix (в воркспейсе не мусорим).
set -uo pipefail

RUBY="${1:-ruby}"
WORK="${WORK:-/tmp/bitcoin-ruby-matrix}"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export PATH="$(dirname "$RUBY"):$PATH"
# libsecp256k1, если он есть в системе — иначе 13 спек просто не смогут запуститься
SECP="$(ls /usr/lib/x86_64-linux-gnu/libsecp256k1.so /usr/local/lib/libsecp256k1.so 2>/dev/null | head -1 || true)"
[ -n "$SECP" ] && export SECP256K1_LIB_PATH="$SECP"

echo "Ruby: $("$RUBY" -v)"
echo "libsecp256k1: ${SECP:-не найден (13 спек BIP143/Secp256k1 упадут по неинсталлированной библиотеке)}"
echo

if [ ! -d "$WORK/.git" ]; then
  mkdir -p "$WORK"
  curl -sL https://codeload.github.com/lian/bitcoin-ruby/tar.gz/refs/heads/master \
    | tar xz -C "$WORK" --strip-components=1
fi
cd "$WORK" || exit 1

# зависимости для спек
gem list rspec  | grep -q rspec      || gem install rspec --no-document    >/dev/null
gem list simplecov | grep -q simplecov || gem install simplecov --no-document >/dev/null
gem list pry | grep -q pry          || gem install pry --no-document      >/dev/null

cat > spec/matrix_helper.rb <<RB
require_relative '../lib/bitcoin'
require '$PATCH_DIR/lib/bitcoin/signet'
require '$PATCH_DIR/lib/bitcoin/openssl3'
RB

RVER="$("$RUBY" -e 'print RUBY_VERSION')"   # для имён файлов с результатами

run_suite() {   # $1 = tag, $2 = подключать ли патч
  local out
  if [ "$2" = "patch" ]; then
    out=$(timeout 1800 "$RUBY" -S rspec spec/unit --no-color -r ./spec/matrix_helper --seed 1 2>/dev/null)
  else
    out=$(timeout 1800 "$RUBY" -S rspec spec/unit --no-color --seed 1 2>/dev/null)
  fi
  local summary; summary=$(echo "$out" | grep -E "^[0-9]+ examples" | tail -1)
  echo "[$1] ${summary:-прогон не завершился}"
  echo "$out" | grep -E "^  [0-9]+\) " | sed 's/^ *[0-9]*) //' | sort > "/tmp/matrix_$1.txt"
  echo "[$1] уникальных падений: $(wc -l < /tmp/matrix_$1.txt)"
}

run_suite "без_патча_$RVER" nopatch
echo
run_suite "с_патчем_$RVER" patch
echo
echo "Списки падений: /tmp/matrix_*.txt"
