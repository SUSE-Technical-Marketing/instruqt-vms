#!/bin/bash
# Collection of functions to make user actions

#######################################
# Log in Rancher with username and password
# Globals:
#   LOGIN_TOKEN
# Arguments:
#   Rancher URL
#   Username
#   Password
# Examples:
#   rancher_login_withpassword rancher.random_string.geek admin somepassword
#######################################
rancher_login_withpassword() {
  local rancherUrl=$1
  local username=$2
  local password=$3
  local max_retries=5
  local retry_count=0
  local http_code
  local response_body

  while [ $retry_count -lt $max_retries ]; do
    # Use -w to capture HTTP status code separately from response body
    response=$(curl -s -k -w "\n%{http_code}" "$rancherUrl/v3-public/localProviders/local?action=login" \
      -H 'Content-Type: application/json' \
      --data-binary "{
        \"username\": \"$username\",
        \"password\": \"$password\"
      }")
    
    # Split response: last line is http_code, rest is body
    response_body=$(echo "$response" | sed '$d')
    http_code=$(echo "$response" | tail -n1)
    
    # Check if HTTP status code is in 2xx range
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
      echo "$response_body" | jq -r '.token'
      return 0
    fi
    
    retry_count=$((retry_count + 1))
    if [ $retry_count -lt $max_retries ]; then
      echo "Login attempt $retry_count failed with HTTP $http_code, retrying..." >&2
      sleep 2
    fi
  done
  
  echo "Failed to login after $max_retries attempts (last HTTP code: $http_code)" >&2
  return 1
}

#######################################
# Update user password for Rancher
# Arguments:
#   Rancher URL
#   token
#   current password
#   new password
# Examples:
#   rancher_update_userpwd rancher.random_string.geek xxxxx currentpwd newpwd
#######################################
rancher_update_password() {
  local rancherUrl=$1
  local token=$2
  local currentPassword=$3
  local newPassword=$4

  echo 'Updates Rancher user password...'
  curl -s -k -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d '{
      "currentPassword": "'"$currentPassword"'",
      "newPassword": "'"$newPassword"'"
    }' \
    "$rancherUrl/v3/users?action=changepassword"
}

#######################################
# Create an API key Rancher
# Globals:
#   API_TOKEN
# Arguments:
#   Rancher URL
#   token
#   key description
# Examples:
#   rancher_create_apikey rancher.random_string.geek xxxxx 'Automation API Key'
#######################################
rancher_create_apikey() {
  local rancherUrl=$1
  local token=$2
  local description=$3

  API_KEY_RESPONSE=$(curl -s -k "$rancherUrl/v3/tokens" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token" \
    --data-binary '{
      "type": "token",
      "description": "'"$description"'",
      "ttl": 0
    }')
  echo $API_KEY_RESPONSE | jq -r '.token'
}
