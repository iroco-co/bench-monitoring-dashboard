#!/bin/bash

# Initialisation des variables
TIME_INTERVAL=1                     # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="localhost"      # Adresse IP ou nom DNS du serveur Collectd
NETWORK_INTERFACE="wlp2s0"          # Interface réseau à surveiller
CONFIG_DIR="./config"               # Répertoire de configuration
DESTINATION_PORT=2003              # Port UDP Collectd par défaut

usage() {
  echo "Usage: $0 --destination-server <destination-server> --destination-port <destination-port> --network-interface <network-interface> --time-interval <time-interval> <conf-dir>"
  exit 1
}

# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --destination-server) DESTINATION_SERVER="$2"; shift ;;
    --destination-port) DESTINATION_PORT="$2"; shift ;;
    --network-interface) NETWORK_INTERFACE="$2"; shift ;;
    --time-interval) TIME_INTERVAL="$2"; shift ;;
    --help) usage ;;
    *) CONFIG_DIR="$1" ;;
  esac
  shift
done


# Chemins de configuration et logs
collectd_conf="$CONFIG_DIR/collectd_influxdb.conf"

mkdir -p $CONFIG_DIR

rm -f $collectd_conf

# Installation de collectd-core si nécessaire
if ! dpkg -l | grep -q "collectd-core"; then
    echo "⚠️  Le paquet collectd-core est manquant. Installation en cours..."
    apt-get update && apt-get install -y collectd-core    
fi

# Création du fichier de configuration temporaire pour Collectd
cat > $collectd_conf <<EOL
PIDFile "$collectd_pid"
Interval $TIME_INTERVAL

LoadPlugin cpu
LoadPlugin memory
LoadPlugin interface
LoadPlugin df
LoadPlugin network
LoadPlugin write_log

<Plugin "cpu">
  ReportByCpu false
  ReportByState true
</Plugin>

<Plugin "memory">
  ValuesPercentage true
</Plugin>

<Plugin "interface">
  Interface "$NETWORK_INTERFACE"
  IgnoreSelected false
</Plugin>

<Plugin df>
  MountPoint "/"
  ValuesPercentage true
</Plugin>

<Plugin network>
  Server "127.0.0.1" "25827"
</Plugin>
EOL

timeout 1 collectd -C $collectd_conf -f > /dev/null 2>&1
echo "✅ Configuration Collectd générée :"
cat $collectd_conf