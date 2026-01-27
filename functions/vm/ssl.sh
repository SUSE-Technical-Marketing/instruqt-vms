download_gcp_certificate() {
  echo "Downloading SSL certificate and key from instance metadata"
  curl -s -o sandbox.crt -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate"
  curl -s -o sandbox.key -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate-key"
}