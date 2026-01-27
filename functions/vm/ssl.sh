download_gcp_certificate() {
  local certFile=${1:-sandbox.crt}
  local keyFile=${2:-sandbox.key}

  echo "Downloading SSL certificate and key from instance metadata"
  curl -s -o $certFile -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate"
  curl -s -o $keyFile -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate-key"

  if ! openssl x509 -in $certFile -noout &>/dev/null; then
    echo "Error: Downloaded certificate is not valid"
    exit 1
  fi

}