#!/bin/bash
set -euxo pipefail

git clone https://github.com/smnorris/fwapg.git
cd fwapg
make
