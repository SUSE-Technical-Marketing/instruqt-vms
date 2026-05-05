#!/bin/bash

wait_for_kubernetes() {
  echo "Waiting for Kubernetes API to be available..."
  RETRIES=30
  COUNT=0
  until kubectl version --request-timeout=5s &> /dev/null
  do
    sleep 5
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $RETRIES ]; then
      echo "Kubernetes API is not available after $RETRIES attempts."
      return 1
    fi
  done
}