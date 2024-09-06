#!/bin/bash

mkdir -p /root/.bitcoin/

echo "rpcuser=bitcoinrpc" > /root/.bitcoin/bitcoin.conf
echo "rpcpassword=changeme" >> /root/.bitcoin/bitcoin.conf

bitcoind -daemon

sleep 10

tail -f /dev/null
