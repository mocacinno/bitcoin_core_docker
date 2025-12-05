#!/bin/bash
set -e
CONF_DIR="/home/bitcoinuser/.bitcoin"
mkdir -p "$CONF_DIR"
RPC_PASSWORD=$(openssl rand -hex 16)
cat > "$CONF_DIR/bitcoin.conf" <<EOF
rpcuser=bitcoinrpc
rpcpassword=$RPC_PASSWORD
EOF
echo "Generated RPC password: $RPC_PASSWORD"
