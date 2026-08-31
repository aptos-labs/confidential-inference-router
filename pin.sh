#!/bin/sh
# Emit the measured -i/-u argv lines for the router CVM manifests for a release tag.
# Run AFTER the tag is pushed: the hash covers the published config.yml bytes.
# Usage: pin.sh <tag>
set -eu
tag=${1:?"usage: pin.sh <tag>"}
repo="aptos-labs/confidential-inference-router"
url="https://raw.githubusercontent.com/${repo}/${tag}/config.yml"
digest=$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')
echo "      - -i=${url}@sha256:${digest}"
echo "      - -u=${url}@sha256:${digest}"
