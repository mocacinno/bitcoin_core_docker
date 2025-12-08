# TL;DR; How to run

## interactively

```bash
docker run --entrypoint /bin/bash --network host -it ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.7_SLES16
init.sh
bitcoin &
#ctrl-c to stop looking at log
tail -f ~/.bitcoin/debug.log
bitcoind getinfo
```

## in background

```bash
docker run -d \
  --name btc28 \
  -v btc28_data:/home/bitcoinuser/.bitcoin \
  ghcr.io/mocacinno/mocacinno/bitcoin_core_docker:v2.7_SLES16
docker logs -f btc28
```
