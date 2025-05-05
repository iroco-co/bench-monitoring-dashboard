#!/bin/bash

# Initialisation des variables
DESTINATION="$PWD/tir_@test"

# Récupération des variables
if [ -n "$1" ]; then
	DESTINATION="$1"
fi


# Constantes
WIDTH=$(echo "800 * 1.5" | bc)
HEIGHT=$(echo "300 * 1.5" | bc)

load_variables() {
	if [ -f "$DESTINATION/vars" ]; then
		source "$DESTINATION/vars"
	else
		echo "Fichier de variables introuvable."
	fi
}

load_variables

echo "Nombre de secondes: $NB_SECONDS"
echo "Temps de base: $BASE_TIME"
echo "Destination: $DESTINATION"

network_graph() {
	rrdtool graph $DESTINATION/network_usage.png \
	--width $WIDTH --height $HEIGHT \
	--title "Utilisation réseau sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Kilobits par seconde" \
	--start $BASE_TIME  --end $BASE_TIME+$NB_SECONDS\
	DEF:tx=$DESTINATION/network.rrd:tx:AVERAGE \
	VDEF:average=tx,AVERAGE \
	AREA:tx#0000FF:"Upload" \
	COMMENT:"\n" \
	LINE1:average#000000:"Average usage\: " GPRINT:average:"%.2lf kb/s" \
	COMMENT:"\n"
}

cpu_graph() {

	rrdtool graph $DESTINATION/cpu_usage.png \
	--width $WIDTH --height $HEIGHT \
	--title "Utilisation CPU sur les $NB_SECONDS dernières secondes" \
	--vertical-label "CPU usage" \
	--start $BASE_TIME  --end $BASE_TIME+$NB_SECONDS\
	DEF:user=$DESTINATION/cpu.rrd:user:AVERAGE \
	DEF:nice=$DESTINATION/cpu.rrd:nice:AVERAGE \
	DEF:system=$DESTINATION/cpu.rrd:system:AVERAGE \
	DEF:iowait=$DESTINATION/cpu.rrd:iowait:AVERAGE \
	DEF:irq=$DESTINATION/cpu.rrd:irq:AVERAGE \
	DEF:softirq=$DESTINATION/cpu.rrd:softirq:AVERAGE \
	CDEF:total=user,nice,system,iowait,irq,softirq,+,+,+,+,+ \
	VDEF:average=total,AVERAGE \
	AREA:user#FF0000:"User" \
	STACK:nice#00FF00:"Nice" \
	STACK:system#0000FF:"System" \
	STACK:iowait#FFFF00:"I/O Wait" \
	STACK:irq#00FFFF:"IRQ" \
	STACK:softirq#FF00FF:"Soft IRQ" \
	COMMENT:"\n" \
	LINE1:average#000000:"Average usage\: " GPRINT:average:"%.2lf %%" \
	COMMENT:"\n"
}


memory_graph() {
	rrdtool graph $DESTINATION/memory_usage.png \
	--width $WIDTH --height $HEIGHT \
	--title "Utilisation mémoire sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Pourcentage" \
	--start $BASE_TIME  --end $BASE_TIME+$NB_SECONDS\
	DEF:used=$DESTINATION/memory.rrd:used:AVERAGE \
	DEF:free=$DESTINATION/memory.rrd:free:AVERAGE \
	DEF:available=$DESTINATION/memory.rrd:available:AVERAGE \
	CDEF:total=used,free,+,available,+ \
	CDEF:used_pct=used,total,/,100,* \
	VDEF:average=used_pct,AVERAGE \
	AREA:used_pct#FF0000:"Used" \
	COMMENT:"\n" \
	LINE1:average#000000:"Average usage\: " GPRINT:average:"%.2lf %%" \
	COMMENT:"\n"
}

# Génération des graphiques
network_graph
cpu_graph
memory_graph