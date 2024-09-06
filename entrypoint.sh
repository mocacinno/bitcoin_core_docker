#!/bin/bash

bitcoind -daemon

sleep 10

tail -f /dev/null
