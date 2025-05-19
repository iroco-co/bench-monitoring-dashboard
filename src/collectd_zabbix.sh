#!/bin/bash

# Initialisation des variables
TIME_INTERVAL=1                   # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="localhost"      # Adresse IP ou nom DNS du serveur Zabbix
NETWORK_INTERFACE="wlp2s0"          # Interface réseau à surveiller
CONFIG_DIR="$PWD/config"               # Répertoire de configuration
DESTINATION_PORT=10051               # Port par défaut pour l'agent Zabbix

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
collectd_conf="$CONFIG_DIR/collectd_zabbix.conf"
log_file="$CONFIG_DIR/collectd_zabbix.log"

mkdir -p $CONFIG_DIR
touch $log_file

rm -f $collectd_conf

# Installation de collectd-core si nécessaire
if ! dpkg -l | grep -q "collectd-core"; then
    echo "⚠️  Le paquet collectd-core est manquant. Installation en cours..."
    apt-get update && apt-get install -y collectd-core
fi

if ! getent group collectd; then
  sudo groupadd collectd
  sudo usermod -aG collectd $(whoami)
  echo redémarer le terminal avant de relancer le script
  exit 1
fi

# Création du fichier de configuration temporaire pour Collectd
cat > $collectd_conf <<EOL
PIDFile "$collectd_pid"
Interval $TIME_INTERVAL

LoadPlugin cpu
LoadPlugin memory
LoadPlugin interface
LoadPlugin df
LoadPlugin exec
LoadPlugin logfile
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
  Device "/dev/nvme0n1p5"
  ValuesPercentage true
</Plugin>

<Plugin "logfile">
  LogLevel "info"
  File "$log_file"
</Plugin>

LoadPlugin exec
<Plugin exec>
  Exec "arthurb:arthurb" "$PWD/src/zabbix-sender.sh" "$log_file" "$DESTINATION_SERVER" "$DESTINATION_PORT"
</Plugin>
EOL

timeout 1 collectd -C $collectd_conf -f > /dev/null 2>&1
echo "✅ Configuration Collectd générée :"
cat $collectd_conf