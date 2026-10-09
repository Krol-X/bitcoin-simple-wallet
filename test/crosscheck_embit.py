#!/usr/bin/env python3
# encoding: utf-8
"""Независимая проверка транзакций, собранных bitcoin-ruby (build/spends.json).

Считаем BIP143/legacy sighash и проверяем ECDSA-подписи через python-embit —
другой реализацией, никак не связанной с гемом.

    pip install embit
    python3 test/crosscheck_embit.py
"""
import hashlib
import json
import os
import sys

from embit.transaction import Transaction
from embit.script import Script
from embit.ec import PublicKey, Signature

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "..", "build", "spends.json")


def parse_pushes(data: bytes):
    """Разбор scriptSig из каноничных push-инструкций."""
    pushes, i = [], 0
    while i < len(data):
        op = data[i]
        i += 1
        if op == 0:
            pushes.append(b"")
        elif 1 <= op <= 75:
            pushes.append(data[i:i + op]); i += op
        elif op == 0x4C:
            n = data[i]; i += 1
            pushes.append(data[i:i + n]); i += n
        elif op == 0x4D:
            n = int.from_bytes(data[i:i + 2], "little"); i += 2
            pushes.append(data[i:i + n]); i += n
        else:
            pushes.append(bytes([op]))
    return pushes


def p2pkh_script_code(h160: bytes) -> Script:
    """scriptCode для BIP143 при трате P2WPKH — это P2PKH-скрипт этого хеша."""
    return Script(b"\x76\xa9\x14" + h160 + b"\x88\xac")


def main():
    if not os.path.exists(PATH):
        sys.exit(f"нет файла {PATH}; сначала запустите: ruby examples/02_build_spend.rb")
    data = json.load(open(PATH))
    total = passed = 0

    for spend in data["spends"]:
        raw = bytes.fromhex(spend["hex"])
        tx = Transaction.parse(raw)
        print(f"{spend['name']}")

        # 1) txid: embit считает его по «старому» формату (без witness)
        real_txid = tx.txid().hex()
        same = real_txid == spend["txid"]
        print(f"   txid {real_txid} — {'совпадает' if same else 'НЕ совпадает'} с bitcoin-ruby")
        passed += same; total += 1

        # 2) подписи
        for i, inp in enumerate(spend["inputs"]):
            spk_hex = inp["spk"]
            vin = tx.vin[i]
            if spk_hex.startswith("0014"):              # P2WPKH
                sig, pub = vin.witness.items[0], vin.witness.items[1]
                sighash = tx.sighash_segwit(i, p2pkh_script_code(bytes.fromhex(spk_hex)[2:]), inp["value"])
            elif spk_hex.startswith("a914"):            # P2SH-P2WPKH
                redeem = parse_pushes(vin.script_sig.data)[0]
                sig, pub = vin.witness.items[0], vin.witness.items[1]
                assert redeem[:2] == b"\x00\x14", "redeem script не p2wpkh"
                sighash = tx.sighash_segwit(i, p2pkh_script_code(redeem[2:]), inp["value"])
            elif spk_hex.startswith("76a914"):          # P2PKH
                pushes = parse_pushes(vin.script_sig.data)
                sig, pub = pushes[0], pushes[1]
                sighash = tx.sighash_legacy(i, Script(bytes.fromhex(spk_hex)))
            else:
                print(f"   [{i}] неизвестный тип {spk_hex[:8]}")
                continue

            sig_der, hashtype = sig[:-1], sig[-1]
            ok = PublicKey.parse(pub).verify(Signature.parse(sig_der), sighash)
            print(f"   [{i}] sighash {sighash.hex()[:16]}… hashtype {hashtype} "
                  f"подпись {'ВЕРНА' if ok else 'НЕВЕРНА'}")
            passed += ok; total += 1

    print()
    print(f"Итог: {passed}/{total} проверок пройдено независимой реализацией (embit).")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
