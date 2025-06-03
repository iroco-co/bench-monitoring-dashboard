#!/bin/bash

# Initialisation des variables
NB_SECONDS=10                   # Nombre de secondes à collecter
STEP=1                          # Pas de temps
DESTINATION="$PWD/tir_@test"    # Répertoire de destination des fichiers RRD
NETWORK_INTERFACE="wlp2s0"      # Interface réseau à surveiller
BASE_TIME=$(date +%s)           # Temps de base pour les données

# Fonction pour afficher l'aide
usage() {
  echo "Usage: $0 --nb-seconds --step <seconds> --network-interface <network-interface> --base-time<base-time(seconds)> <destination>"
  exit 1
}

# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --nb-seconds) NB_SECONDS="$2"; shift ;;
    --step) STEP="$2"; shift ;;
		--network-interface) NETWORK_INTERFACE="$2"; shift ;;
		--base-time) BASE_TIME="$2"; shift ;;
    --help) usage ;;
    *) DESTINATION="$1" ;;
  esac
  shift
done


echo "Pas de temps: $STEP"
echo "Nombre total seconde: $NB_SECONDS"
echo "Interface réseau: $NETWORK_INTERFACE"
echo "Destination: $DESTINATION"
echo "Temps de base: $BASE_TIME"

cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
}

create_dir() {
  local NEW_DESTINATION=${DESTINATION}
  local cpt=2
  while [ -d ${NEW_DESTINATION} ]; do
    echo "Le répertoire ${NEW_DESTINATION} existe déjà."
    NEW_DESTINATION=${DESTINATION}_${cpt}
    cpt=$((cpt + 1))
  done
  DESTINATION=${NEW_DESTINATION}
  echo "Création du répertoire $DESTINATION"
  mkdir -p ${DESTINATION}
}

# Fonction pour enregistrer les variables nécéssaires pour les graphiques
store_variables() {
  echo "NB_SECONDS=$NB_SECONDS" > "$DESTINATION/vars"
  echo "BASE_TIME=$BASE_TIME" >> "$DESTINATION/vars"
  echo "STEP=$STEP" >> "$DESTINATION/vars"
  echo "Variables enregistrées dans $DESTINATION/vars"
}

create_dir
store_variables

# Création des bases de données RRD
rrdtool create $DESTINATION/cpu.rrd \
--start $(($BASE_TIME)) \
--step $STEP \
DS:user:COUNTER:5:0:U \
DS:nice:COUNTER:5:0:U \
DS:system:COUNTER:5:0:U \
DS:idle:COUNTER:5:0:U \
DS:iowait:COUNTER:5:0:U \
DS:irq:COUNTER:5:0:U \
DS:softirq:COUNTER:5:0:U \
RRA:AVERAGE:0.5:1:$NB_SECONDS

rrdtool create $DESTINATION/memory.rrd \
--start $(($BASE_TIME)) \
--step $STEP \
DS:used:GAUGE:5:0:U \
DS:free:GAUGE:5:0:U \
DS:available:GAUGE:5:0:U \
RRA:AVERAGE:0.5:1:$NB_SECONDS

rrdtool create $DESTINATION/network.rrd \
--start $(($BASE_TIME)) \
--step $STEP \
DS:tx:GAUGE:5:0:30 \
RRA:AVERAGE:0.5:1:$NB_SECONDS

collect_network () {
	NETWORK_DATA=$(sar -n DEV 1 $STEP | grep $NETWORK_INTERFACE | tail -n 1 | awk '{print $6}' | sed 's/,/./g')
	current_time=$(($BASE_TIME + $1))
	rrdtool update $DESTINATION/network.rrd $current_time:$NETWORK_DATA
}

collect_cpu () {
	CPU_DATA=$(awk '/^cpu  /{print $2":"$3":"$4":"$5":"$6":"$7":"$8}' /proc/stat)
	current_time=$(($BASE_TIME + $1))
	rrdtool update $DESTINATION/cpu.rrd $current_time:$CPU_DATA
	echo $CPU_DATA
}

collect_memory () {
	MEMORY_DATA=$(free | awk '/Mem/{print $3":"$4":"$7}')
	current_time=$(($BASE_TIME + $1))
	rrdtool update $DESTINATION/memory.rrd $current_time:$MEMORY_DATA
	echo $MEMORY_DATA
}

# Collecte des données

sec_counter=0
echo "Collecte des données en cours... durée: $NB_SECONDS secondes"
while [ $sec_counter -lt $(($NB_SECONDS+1)) ]; do
	collect_network $sec_counter &
	collect_cpu $sec_counter &
	collect_memory $sec_counter &
	sec_counter=$((sec_counter + 1))
	sleep 1
done
