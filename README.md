# sBTC Wallet

Минималистичный консольный bitcoin-кошелёк для сети **signet**.

Генерирует и хранит приватный ключ в `storage/wallet.key`, показывает баланс
адреса и отправляет указанную сумму на другой адрес. Перед отправкой проверяет,
хватает ли средств с учётом комиссии майнерам (0.00001 sBTC).

## Требования

- Ruby >= 3.2

## Использование

```bash
bundle install            # установка зависимостей

./bin/cli                 # интерактивный режим (REPL)
./bin/cli [-a] --account  # : адрес и баланс
./bin/cli [-s] --send <address> <amount>  # : отправить <amount> BTC на <address>
./bin/cli [-h] --help     # : помощь
```

## Docker

```bash
docker build -t sbtc-wallet .

# интерактивный режим (REPL)
docker run --rm -it -v ./storage:/app/storage sbtc-wallet

# адрес и баланс
docker run --rm -v ./storage:/app/storage sbtc-wallet -a

# отправить <amount> BTC на <address>
docker run --rm -v ./storage:/app/storage sbtc-wallet -s <address> <amount>
```

Каталог `storage/` исключён из образа (`.dockerignore`), ключ
`storage/wallet.key` генерируется при первом запуске — монтируйте
`-v ./storage:/app/storage`, чтобы ключ не терялся вместе с контейнером.
