#!/bin/bash

# Script to generate JWKS from a Kubernetes TLS secret using openssl only

set -e

# Configuration
SECRET_NAME="device-lobby-client-cert"
NAMESPACE="demonstrations"
OUTPUT_DIR="./jwks"
KID_SOURCE="tls.crt"  # used to compute kid from cert fingerprint

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Generating JWKS from ${SECRET_NAME} in namespace ${NAMESPACE}${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Secret ${SECRET_NAME} not found in namespace ${NAMESPACE}${NC}"
    exit 1
fi

echo -e "${YELLOW}Extracting certificate and private key...${NC}"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$OUTPUT_DIR/tls.crt"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > "$OUTPUT_DIR/tls.key"

# Helper: base64url encode from raw bytes
b64url() {
  base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

# Extract public key from certificate
PUB_PEM="$OUTPUT_DIR/tls.pub.pem"
openssl x509 -in "$OUTPUT_DIR/tls.crt" -pubkey -noout > "$PUB_PEM"

# Parse modulus (n) and exponent (e) from public key using openssl text output
PUB_TXT="$OUTPUT_DIR/tls.pub.txt"
openssl rsa -pubin -in "$PUB_PEM" -text -noout > "$PUB_TXT"

# Extract modulus hex (concatenate lines between 'Modulus:' and 'Exponent:')
MOD_HEX="$(awk '/Modulus:/,/Exponent:/' "$PUB_TXT" \
  | sed -n '2,/Exponent:/p' \
  | sed 's/://g;s/ //g' \
  | tr -d '\n')"

# Extract exponent value (usually 65537). Openssl prints: "Exponent: 65537 (0x10001)"
EXP_DEC="$(awk '/Exponent:/{print $2}' "$PUB_TXT")"

# Convert exponent decimal to hex (no leading 0x), then to raw bytes
# Handle common 65537 fast-path; otherwise use printf for generic conversion.
if [ "$EXP_DEC" = "65537" ]; then
  EXP_HEX="010001"
else
  # decimal to hex
  EXP_HEX="$(printf '%x\n' "$EXP_DEC")"
  # ensure even-length hex
  if [ $(( ${#EXP_HEX} % 2 )) -ne 0 ]; then EXP_HEX="0${EXP_HEX}"; fi
fi

# Hex -> raw bytes -> base64url
N_B64URL="$(echo "$MOD_HEX" | xxd -r -p | b64url)"
E_B64URL="$(echo "$EXP_HEX" | xxd -r -p | b64url)"

# Compute kid from cert fingerprint (SHA-256, base64url)
KID="$(openssl x509 -in "$OUTPUT_DIR/$KID_SOURCE" -noout -fingerprint -sha256 \
  | cut -d'=' -f2 | tr -d ':' \
  | xxd -r -p | b64url)"

# Optionally derive alg from key type; we assume RSA with RS256 here
ALG="RS256"
KTY="RSA"
USE="sig"

# Assemble JWKS
JWKS_PATH="$OUTPUT_DIR/jwks.json"
{
  echo '{ "keys": ['
  echo '  {'
  echo "    \"kty\": \"$KTY\","
  echo "    \"kid\": \"$KID\","
  echo "    \"alg\": \"$ALG\","
  echo "    \"use\": \"$USE\","
  echo "    \"n\": \"$N_B64URL\","
  echo "    \"e\": \"$E_B64URL\""
  echo '  }'
  echo '] }'
} > "$JWKS_PATH"

echo -e "${GREEN}✓ JWKS saved to ${JWKS_PATH}${NC}"

# Display JWKS information
echo -e "\n${YELLOW}JWKS Content:${NC}"
cat "$JWKS_PATH"

echo -e "\n${GREEN}Done! JWKS generated in ${OUTPUT_DIR}/${NC}"
