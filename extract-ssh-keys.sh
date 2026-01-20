#!/bin/bash

# Script to extract SSH keys from device-lobby-client-cert Kubernetes secret
# This converts the TLS certificate and private key to SSH format

set -e

# Configuration
SECRET_NAME="device-lobby-client-cert"
NAMESPACE="demonstrations"
OUTPUT_DIR="./ssh-keys"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Extracting SSH keys from ${SECRET_NAME} in namespace ${NAMESPACE}${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Secret ${SECRET_NAME} not found in namespace ${NAMESPACE}${NC}"
    exit 1
fi

echo -e "${YELLOW}Extracting certificate and private key...${NC}"

# Extract the private key from the secret
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > "$OUTPUT_DIR/tls.key"
chmod 600 "$OUTPUT_DIR/tls.key"

# Extract the certificate from the secret
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$OUTPUT_DIR/tls.crt"

# Extract the CA certificate if it exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}' &>/dev/null; then
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}' | base64 -d > "$OUTPUT_DIR/ca.crt"
    echo -e "${GREEN}✓ CA certificate saved to ${OUTPUT_DIR}/ca.crt${NC}"
fi

echo -e "${YELLOW}Converting to SSH format...${NC}"

# Convert private key to SSH format (OpenSSH format)
ssh-keygen -f "$OUTPUT_DIR/tls.key" -y > "$OUTPUT_DIR/id_rsa.pub"

# Copy the private key in OpenSSH format
cp "$OUTPUT_DIR/tls.key" "$OUTPUT_DIR/id_rsa"
chmod 600 "$OUTPUT_DIR/id_rsa"

# Convert certificate to SSH certificate format (if needed)
# Note: SSH doesn't directly use X.509 certificates, but we can extract the public key
echo -e "${GREEN}✓ Private key saved to ${OUTPUT_DIR}/id_rsa${NC}"
echo -e "${GREEN}✓ Public key saved to ${OUTPUT_DIR}/id_rsa.pub${NC}"
echo -e "${GREEN}✓ TLS certificate saved to ${OUTPUT_DIR}/tls.crt${NC}"
echo -e "${GREEN}✓ TLS private key saved to ${OUTPUT_DIR}/tls.key${NC}"

# Display key information
echo -e "\n${YELLOW}Key Information:${NC}"
echo "Certificate Subject:"
openssl x509 -in "$OUTPUT_DIR/tls.crt" -noout -subject -nameopt multiline

echo -e "\nCertificate Validity:"
openssl x509 -in "$OUTPUT_DIR/tls.crt" -noout -dates

echo -e "\nSSH Public Key Fingerprint:"
ssh-keygen -lf "$OUTPUT_DIR/id_rsa.pub"

echo -e "\n${GREEN}Done! Keys extracted to ${OUTPUT_DIR}/${NC}"
echo -e "${YELLOW}Note: The private key has been set to mode 600 (read/write for owner only)${NC}"
