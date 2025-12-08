# TL;DR; How to run

## interactively

```bash
docker run --entrypoint /bin/bash --network host -it ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.7_SLES16
init.sh
bitcoind &
#ctrl-c to stop looking at log
tail -f ~/.bitcoin/debug.log
bitcoind getinfo
```

## in background

```bash
docker run -d \
  --name btc27 \
  -v btc27_data:/home/bitcoinuser/.bitcoin \
  ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.7_SLES16
docker logs -f btc27
docker exec -it btc27 sh -c "tail -f /home/bitcoinuser/.bitcoin/debug.log"
```

## docker compose

docker-compose.yml

```yml
version: "3.9"

services:
  bitcoin27:
    image: ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.7_SLES16
    container_name: bitcoin27
    user: "10001:10001"
    volumes:
      - btc27_data:/home/bitcoinuser/.bitcoin
    restart: unless-stopped
    entrypoint: ["/usr/local/bin/entrypoint.sh"]

volumes:
  btc27_data:

```

commands: 
```bash
docker compose up -d
docker compose exec bitcoin27 sh -c "tail -f /home/bitcoinuser/.bitcoin/debug.log"
```
