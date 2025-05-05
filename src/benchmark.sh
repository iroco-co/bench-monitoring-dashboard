#!/bin/bash

BASE_TIME=$(date -d "2025-03-12 00:00:00" +%s) # Date de base pour la collecte de données et la génération de graphiques

# Initialisation des variables
DURATION=10 # sec                       # Echantillon de temps pour l'utilisation de l'outil de monitoring
STEP=1 # sec                            # Pas de temps pour la collecte de données
DESTINATION=$PWD/tir_${DURATION}sec     # Répertoire de destination du tir de benchmark
CONFIG_DIR=./config                     # Répertoire de configuration de l'outil de monitoring
NETWORK_INTERFACE=wlp2s0                # Interface réseau à surveiller

# Analyse des options de ligne de commande
if [ -n "$1" ]; then
  DURATION=$1
fi

TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

nb_sec_collect=$(($DURATION + $TIME_BEFORE + $TIME_AFTER))

cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
}

config_collectd_graphite() {
  echo "Configuration de Collectd pour Graphite..."
  /bin/bash src/collectd_graphite.sh > /dev/null #2>&1 &
}

config_collectd_nagios() {
  echo "Configuration de Collectd pour Nagios..."
  sudo /bin/bash src/collectd_nagios.sh > /dev/null #2>&1 &
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
    kill $(pgrep -x "collectd")
    echo "Arrêt de Collectd"
  fi
}

start_collectd() {
  echo "Démarage Collectd pour $DURATION secondes"
  collectd -C $CONFIG_DIR/collectd.conf -f > /dev/null 2>&1 &
}

start_graphite() {
  start_collectd
  sleep 1
  echo "Démarage Graphite..."
  docker start graphite
}

start_nagios() {
  start_collectd
  sleep 1
  echo "Démarage Nagios..."
  docker start nagios4
}

stop_graphite() {
  if docker ps -q --filter "name=graphite" > /dev/null; then
    echo "Arrêt de Graphite..."
    docker stop graphite
  fi
  stop_collectd
  echo "Arrêt de Graphite..."
}

stop_nagios() {
  if docker ps -q --filter "name=nagios4" > /dev/null; then
    echo "Arrêt de Nagios..."
    docker stop nagios4
  fi
  stop_collectd
  echo "Arrêt de Nagios..."
}

start_collect_data() {
  echo "Démarrage de la collecte de données pour $1... durée: $nb_sec_collect secondes"
  exec ./src/collect_data.sh --base-time $BASE_TIME --nb-seconds $nb_sec_collect --step $STEP $DESTINATION/$1 > /dev/null 2>&1 &
}

generate_graphs() {
  echo "Generation des graphiques..."
  /bin/bash src/agregate_graph.sh $DESTINATION > /dev/null #2>&1
}

# Lancer un benchmark Graphite
bench_graphite() {
  config_collectd_graphite
  echo "Benchmark Graphite en cours..."
  start_collect_data graphite
  sleep $TIME_BEFORE
  start_graphite
  sleep $DURATION
  stop_graphite
  sleep $TIME_AFTER
  echo "Benchmark Graphite terminé."
}

# Lancer un benchmark Nagios
bench_nagios() {
  config_collectd_nagios
  echo "Benchmark Nagios en cours..."
  start_collect_data nagios
  sleep $TIME_BEFORE
  start_nagios
  sleep $DURATION
  stop_nagios
  sleep $TIME_AFTER
  echo "Benchmark Collectd terminé."
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

# Main
create_dir

stop_collectd
stop_graphite
stop_nagios

bench_graphite
bench_nagios
bench_empty

sleep 1
generate_graphs
echo "Benchmark terminé."

