#!/bin/bash
# Compiles the pure ordering logic with its checks and runs them.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc Sources/OptSwitch/Order.swift Tests/OrderTests/main.swift -o .build/order-tests
.build/order-tests
