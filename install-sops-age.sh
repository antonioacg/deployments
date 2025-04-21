#!/bin/bash
set -e

# Detect OS and architecture
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
echo "Detected OS: $OS"
echo "Detected architecture: $ARCH"

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "Error: Unsupported architecture: $ARCH"; exit 1 ;;
esac
echo "Mapped architecture: $ARCH"

# Install SOPS if not present
if ! command -v sops >/dev/null 2>&1; then
    echo "Installing SOPS..."
    SOPS_VERSION="v3.7.3"
    SOPS_URL="https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.${OS}.${ARCH}"
    if command -v curl >/dev/null 2>&1; then
        curl -Lo sops $SOPS_URL
    elif command -v wget >/dev/null 2>&1; then
        wget -O sops $SOPS_URL
    else
        echo "Error: curl or wget required to install SOPS"
        exit 1
    fi
    chmod +x sops
    sudo mv sops /usr/local/bin/sops
fi

# Install Age if not present
if ! command -v age >/dev/null 2>&1; then
    echo "Installing Age..."
    AGE_VERSION="v1.1.1"
    AGE_URL="https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
    TMP_DIR=$(mktemp -d)
    if command -v curl >/dev/null 2>&1; then
        curl -L $AGE_URL -o "$TMP_DIR/age.tar.gz"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$TMP_DIR/age.tar.gz" $AGE_URL
    else
        echo "Error: curl or wget required to install Age"
        exit 1
    fi
    tar -xzf "$TMP_DIR/age.tar.gz" -C "$TMP_DIR"
    sudo mv "$TMP_DIR/age/age" /usr/local/bin/age
    sudo mv "$TMP_DIR/age/age-keygen" /usr/local/bin/age-keygen
    rm -rf "$TMP_DIR"
fi

# Setup Age key
echo "Setting up Age key..."
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
AGE_KEY_DIR="$CONFIG_HOME/sops/age"
AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"
mkdir -p "$AGE_KEY_DIR"
if [ ! -f "$AGE_KEY_FILE" ]; then
    age-keygen -o "$AGE_KEY_FILE"
fi
export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
