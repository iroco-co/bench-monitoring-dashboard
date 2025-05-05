#!/bin/bash

# Initialisation des variables
DESTINATION=$1

if [ -z "$DESTINATION" ]; then
  echo "Destination non spécifiée."
  exit 1
fi

# Constantes
WIDTH=$(echo "800 * 1.5" | bc)
HEIGHT=$(echo "300 * 1.5" | bc)
COLORS=( "#0000FF" "#FF0000" "#00FF00" "#00FFFF" "#FF00FF" "#FFFF00")


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

end_time=$(( BASE_TIME + NB_SECONDS ))

get_color() {
  local color="${COLORS[$1]}"
  if [ -z "$color" ]; then
    color="#$(printf '%06X' $(( RANDOM % 16777215 )))"
  fi
  color_index=$((color_index + 1))
  echo "$color"
}


# Initialisation des tableaux d'arguments
args_cpu=()
args_memory=()
args_network=()

color_index=0

for dir in "$DESTINATION"/*/; do
  folder=$(basename "$dir")

  # CPU
  args_cpu+=( 
    DEF:${folder}_user=$DESTINATION/${folder}/cpu.rrd:user:AVERAGE
    DEF:${folder}_nice=$DESTINATION/${folder}/cpu.rrd:nice:AVERAGE
    DEF:${folder}_system=$DESTINATION/${folder}/cpu.rrd:system:AVERAGE
    DEF:${folder}_iowait=$DESTINATION/${folder}/cpu.rrd:iowait:AVERAGE
    DEF:${folder}_irq=$DESTINATION/${folder}/cpu.rrd:irq:AVERAGE
    DEF:${folder}_softirq=$DESTINATION/${folder}/cpu.rrd:softirq:AVERAGE
    CDEF:${folder}_total=${folder}_user,${folder}_nice,${folder}_system,${folder}_iowait,${folder}_irq,${folder}_softirq,+,+,+,+,+  
    VDEF:${folder}_average=${folder}_total,AVERAGE 
    LINE1:${folder}_total$(get_color $color_index):"${folder} total cpu usage"
    LINE2:${folder}_average$(get_color $color_index):"Moyenne \:" GPRINT:${folder}_average:"%.2lf %%"
    COMMENT:"\n"
  )

  # Memory
  args_memory+=( 
    DEF:${folder}_used=$DESTINATION/${folder}/memory.rrd:used:AVERAGE
    DEF:${folder}_free=$DESTINATION/${folder}/memory.rrd:free:AVERAGE
    DEF:${folder}_available=$DESTINATION/${folder}/memory.rrd:available:AVERAGE
    CDEF:${folder}_total=${folder}_used,${folder}_free,+,${folder}_available,+
    CDEF:${folder}_used_pct=${folder}_used,${folder}_total,/,100,* 
    VDEF:${folder}_average=${folder}_used_pct,AVERAGE 
    LINE1:${folder}_used_pct$(get_color $color_index):"${folder} used memory"
    LINE2:${folder}_average$(get_color $color_index):"Moyenne \:" GPRINT:${folder}_average:"%.2lf %%"
    COMMENT:"\n"
  )

  # Network
  args_network+=( 
    DEF:${folder}_tx=$DESTINATION/${folder}/network.rrd:tx:AVERAGE \
    VDEF:${folder}_average=${folder}_tx,AVERAGE \
    LINE1:${folder}_tx$(get_color $color_index):"${folder} upload" \
    LINE2:${folder}_average$(get_color $color_index):"Moyenne \:" GPRINT:${folder}_average:"%.2lf kb/s" \
    COMMENT:"\n"
  )  

  color_index=$((color_index + 1))

  # Génération du graphique pour chaque sous-dossier
  exec src/generate_graph.sh $DESTINATION/$folder > /dev/null 2>&1 &
done

# Génération des graphiques agrégés

rrdtool graph $DESTINATION/cpu_usage.png \
  --width $WIDTH --height $HEIGHT \
  --title "Utilisation CPU sur les $NB_SECONDS dernières secondes" \
  --vertical-label "CPU usage" \
  --start $BASE_TIME  --end $end_time\
  "${args_cpu[@]}"

rrdtool graph $DESTINATION/memory_usage.png \
  --width $WIDTH --height $HEIGHT \
  --title "Utilisation mémoire sur les $NB_SECONDS dernières secondes" \
  --vertical-label "Pourcentage" \
  --start $BASE_TIME  --end $BASE_TIME+$NB_SECONDS\
  "${args_memory[@]}"

rrdtool graph "$DESTINATION/network_usage.png" \
  --width $WIDTH --height $HEIGHT \
  --title "Utilisation réseau sur les $NB_SECONDS dernières secondes" \
  --vertical-label "Kilobits par seconde" \
  --start "$BASE_TIME" --end "$end_time" \
  "${args_network[@]}"
