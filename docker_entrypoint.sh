#!/bin/bash

set -ea

_term() { 
  echo "Caught TERM signal!" 
  kill -TERM "$redis_process" 2>/dev/null
  kill -TERM "$searxng_process" 2>/dev/null
}

# Configuring SearXNG
echo 'Configuring SearXNG...'
export TOR_ONLY="false"
export SEARXNG_HOSTNAME=$(yq e '.public-host' /root/start9/config.yaml)
export LAN_ADDRESS=$(yq e '.lan-address' /root/start9/config.yaml)
export TOR_ADDRESS=$(yq e '.tor-address' /root/start9/config.yaml)
export LETSENCRYPT_EMAIL=$(yq e '.email-address' /root/start9/config.yaml)
export ENABLE_METRICS=$(yq e '.autocomplete' /root/start9/config.yaml)
export ULTRA_SECRET_KEY=$(openssl rand -hex 32)
export INSTANCE_NAME=$(yq e '.instance-name' /root/start9/config.yaml)
if [ "$SEARXNG_HOSTNAME" = "null" ]; then 
  SEARXNG_HOSTNAME=$LAN_ADDRESS
fi
export SEARXNG_HOSTNAME=${SEARXNG_HOSTNAME:-https://$LAN_ADDRESS}
export SEARXNG_BASE_URL=https://${SEARXNG_HOSTNAME:-$LAN_ADDRESS}/
if $TOR_ONLY; then  
  export SEARXNG_HOSTNAME=http://$TOR_ADDRESS
  export SEARXNG_BASE_URL=http://$TOR_ADDRESS/
fi
export SEARXNG_TLS=${LETSENCRYPT_EMAIL:-internal}
sed -i "s|# SEARXNG_HOSTNAME=<host>|SEARXNG_HOSTNAME=$SEARXNG_HOSTNAME|g" .env
sed -i "s|# LETSENCRYPT_EMAIL=<email>|LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL|" .env
sed -i "s|ultrasecretkey|$ULTRA_SECRET_KEY|g" searxng/settings.yml
sed -i "s|instance_name: .*|instance_name: $INSTANCE_NAME|g" searxng/settings.yml
if $ENABLE_METRICS; then 
  sed -i 's|enable_metrics: false|enable_metrics: true|g' searxng/settings.yml
fi
touch /root/start9/stats.yaml
echo 'version: 2' > /root/start9/stats.yaml
echo 'data:' >> /root/start9/stats.yaml
# Initializing Database
echo 'Starting Redis...'
redis-server --save "" --appendonly "no" &
redis_process=$!

# Starting SearXNG
sh /usr/local/searxng/dockerfiles/docker-entrypoint.sh &
searxng_process=$!

trap _term TERM
wait $redis_process $searxng_process