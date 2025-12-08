#!/bin/bash
set -e
CONF_DIR="/home/bitcoinuser/.bitcoin"
mkdir -p "$CONF_DIR"
RPC_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr -d '=+/')
cat > "$CONF_DIR/bitcoin.conf" <<EOF
rpcuser=bitcoinrpc
rpcpassword=$RPC_PASSWORD
EOF
echo "Generated RPC password: $RPC_PASSWORD"
