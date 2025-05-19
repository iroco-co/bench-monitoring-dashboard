#!/bin/bash

BASE_TIME=$(date -d "2025-03-12 00:00:00" +%s) # Date de base pour la collecte de données et la génération de graphiques

# Initialisation des variables
DURATION=10 # sec                       # Echantillon de temps pour l'utilisation de l'outil de monitoring
STEP=1 # sec                            # Pas de temps pour la collecte de données
CONFIG_DIR=./config                     # Répertoire de configuration de l'outil de monitoring
NETWORK_INTERFACE=wlp2s0                # Interface réseau à surveiller
BENCHED_TOOLS="zabbix grafana nagios" # Liste des outils de monitoring à benchmarker
# Analyse des options de ligne de commande
if [ -n "$1" ]; then
  DURATION=$1
fi

TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

nb_sec_collect=$(($DURATION + $TIME_BEFORE + $TIME_AFTER))
nb_total_sec=$nb_sec_collect

DESTINATION=$PWD/tir_     # Répertoire de destination du tir de benchmark
for tool in $BENCHED_TOOLS; do
  DESTINATION="${DESTINATION}_${tool}"
  nb_total_sec=$(($nb_total_sec + $nb_sec_collect))
done
DESTINATION="${DESTINATION}_${DURATION}sec_$(date +%Y-%m-%d_%H-%M-%S)"

cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
}

config_collectd_graphite() {
  echo "Configuration de Collectd pour Graphite..."
  /bin/bash src/collectd_graphite.sh --network-interface $NETWORK_INTERFACE --time-interval $STEP > /dev/null #2>&1 &
}

config_collectd_grafana() {
  echo "Configuration de Collectd pour Graphana..."
  /bin/bash src/collectd_graphite.sh --network-interface $NETWORK_INTERFACE --time-interval $STEP > /dev/null #2>&1 &
}

config_collectd_nagios() {
  echo "Configuration de Collectd pour Nagios..."
  sudo /bin/bash src/collectd_nagios.sh --network-interface $NETWORK_INTERFACE --time-interval $STEP > /dev/null #2>&1 &
}

config_collectd_zabbix() {
  echo "Configuration de Collectd pour Zabbix..."
  sudo /bin/bash src/collectd_zabbix.sh --network-interface $NETWORK_INTERFACE --time-interval $STEP > /dev/null #2>&1 &
}

# Création du répertoire de destination du tir
create_dir() {
  if [ -d ${DESTINATION} ]; then
    echo "Le répertoire ${DESTINATION} existe déjà. Suppression en cours..."
    cleanup
  fi
  echo "Création du répertoire $DESTINATION"
  mkdir -p ${DESTINATION}
  touch ${DESTINATION}/vars
  echo "NB_SECONDS=$nb_sec_collect" > "$DESTINATION/vars"
  echo "BASE_TIME=$BASE_TIME" >> "$DESTINATION/vars"
  echo "Variables enregistrées dans $DESTINATION/vars"
}

stop_collectd() {
  if pgrep -x "collectd" > /dev/null; then
    echo "Une instance de Collectd tourne déjà. Arrêt en cours..."
    sudo kill $(pgrep -x "collectd")
    echo "Arrêt de Collectd"
  fi
}

start_collectd() {
  echo "Démarage Collectd $1 pour $DURATION secondes"
  collectd -C $CONFIG_DIR/collectd_$1.conf -f > /dev/null 2>&1 &
}

start_graphite() {
  start_collectd
  sleep 1
  echo "Démarage Graphite..."
  docker start graphite
}

start_grafana() {
  start_collectd graphite
  sleep 1
  echo "Démarage grafana..."
  docker compose --project-name 'bench-monitoring-dashboard' start
}

start_nagios() {
  start_collectd nagios
  sleep 1
  echo "Démarage Nagios..."
  docker start nagios4
}

start_zabbix() {
  start_collectd zabbix
  sleep 1
  echo "Démarage Zabbix..."
  docker compose --project-name 'zabbix-docker' start 
}

stop_graphite() {
  if docker ps -q --filter "name=graphite" > /dev/null; then
    echo "Arrêt de Graphite..."
    docker stop graphite
  fi
  stop_collectd
  echo "Arrêt de Graphite..."
}

stop_grafana() {
  docker compose --project-name 'bench-monitoring-dashboard' stop
  stop_collectd
  echo "Arrêt de grafana..."
}

stop_nagios() {
  if docker ps -q --filter "name=nagios4" > /dev/null; then
    echo "Arrêt de Nagios..."
    docker stop nagios4
  fi
  stop_collectd
  echo "Arrêt de Nagios..."
}

stop_zabbix() {
  docker compose --project-name 'zabbix-docker' stop
  stop_collectd
  echo "Arrêt de zabbix..."
}

start_collect_data() {
  echo "Démarrage de la collecte de données pour $1... durée: $nb_sec_collect secondes"
  exec ./src/collect_data.sh --base-time $BASE_TIME --nb-seconds $nb_sec_collect --step $STEP $DESTINATION/$1 > /dev/null 2>&1 &
}

generate_graphs() {
  echo "Generation des graphiques..."
  /bin/bash src/agregate_graph.sh $DESTINATION > /dev/null #2>&1
}

# Lancer un benchmark à vide
bench_empty() {
  echo "Benchmark à vide en cours..."
  start_collect_data empty
  sleep $TIME_BEFORE
  sleep $DURATION
  sleep $TIME_AFTER
  echo "Benchmark à vide terminé."
}

bench_tool() {
  echo "Benchmark $1 en cours..."
  start_collect_data $1
  sleep $TIME_BEFORE
  "start_$1"
  sleep $DURATION
  "stop_$1"
  sleep $TIME_AFTER
  echo "Benchmark $1 terminé."
}

# Main
stop_collectd
stop_grafana
stop_graphite
stop_nagios
stop_zabbix

cleanup


create_dir

for tool in $BENCHED_TOOLS; do
  "config_collectd_$tool"
done

echo "Démarrage du benchmark pour $nb_total_sec seconds..."

for tool in $BENCHED_TOOLS; do
  bench_tool $tool 2>&1 &
done

bench_empty

sleep 1
generate_graphs
echo "Benchmark terminé."

