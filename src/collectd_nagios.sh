#!/bin/bash

# Constantes
UNIX_SOCKET=/tmp/collectd-unixsock

# Initialisation des variables
TIME_INTERVAL=5                     # Intervalle de temps pour la collecte des métriques (en secondes)
NETWORK_INTERFACE="wlp2s0"          # Interface réseau à surveiller
CONFIG_DIR="./config"               # Répertoire de configuration

usage() {
  echo "Usage: $0 --network-interface <network-interface> --time-interval <time-interval> <conf-dir>"
  exit 1
}

# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --network-interface) NETWORK_INTERFACE="$2"; shift ;;
    --time-interval) TIME_INTERVAL="$2"; shift ;;
    --help) usage ;;
    *) CONFIG_DIR="$1" ;;
  esac
  shift
done

collectd_conf="$CONFIG_DIR/collectd_nagios.conf"

mkdir -p $CONFIG_DIR

rm -f $collectd_conf
rm -rf $UNIX_SOCKET

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
LoadPlugin unixsock
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

<Plugin "unixsock">
  SocketFile "$UNIX_SOCKET"
  SocketGroup "root"
  SocketPerms "0777"
</Plugin>
EOL

timeout 1 collectd -C $collectd_conf -f > /dev/null 2>&1
echo "✅ Configuration Collectd générée :"
cat $collectd_conf