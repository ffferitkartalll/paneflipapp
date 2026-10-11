#!/bin/zsh
# Creates a self-signed code-signing certificate in the login keychain, once.
#
# Why: debug builds signed ad-hoc ("-") get a different identity on every build, so macOS asks for the
# Accessibility permission again each time. Signing every build with the same certificate keeps the
# permission. The certificate is local to this Mac; it is not an Apple developer account.
set -euo pipefail

NAME="${1:-PaneFlip Local Development}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
OPENSSL=/usr/bin/openssl   # LibreSSL: writes a .p12 that `security import` reads

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
    echo "Signing identity \"$NAME\" already exists."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<CNF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/cert.cnf" \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

PASS="$("$OPENSSL" rand -hex 16)"
"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$NAME" -out "$WORK/identity.p12" -passout "pass:$PASS"

# -x: the private key cannot be exported. Only codesign may use it without a prompt.
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASS" -x -T /usr/bin/codesign

# Trust it for code signing (macOS asks for your password once).
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

echo "Created signing identity \"$NAME\"."
security find-identity -v -p codesigning | grep "\"$NAME\"" || true
