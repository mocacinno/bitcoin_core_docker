# TL;DR; How to run

## interactively

```bash
docker run --entrypoint /bin/bash --network host -it ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.8_SLES16
init.sh
bitcoind &
#ctrl-c to stop looking at log
tail -f ~/.bitcoin/debug.log
bitcoind getinfo
```

## in background

```bash
docker run -d \
  --name btc28 \
  -v btc28_data:/home/bitcoinuser/.bitcoin \
  ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.8_SLES16
docker logs -f btc28
```

## docker compose

docker-compose.yml

```yml
services:
  bitcoin28:
    image: ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.8_SLES16
    container_name: bitcoin28
    user: "10001:10001"
    volumes:
      - btc28_data:/home/bitcoinuser/.bitcoin
    restart: unless-stopped
    entrypoint: ["/usr/local/bin/entrypoint.sh"]

volumes:
  btc28_data:

```

commands: 
```bash
docker compose up -d
docker compose exec bitcoin28 sh -c "tail -f /home/bitcoinuser/.bitcoin/debug.log"
```
