#!/bin/bash
# -----------------------------------------------------------------------------
# Parcourt le log de collectd, envoie chaque métrique à Zabbix, puis vide le log
# -----------------------------------------------------------------------------

# --- Variables ---
LOGFILE="$1"
DESTINATION_SERVER="$2"
DESTINATION_PORT="$3"
ZBX_SERVER="$DESTINATION_SERVER:$DESTINATION_PORT"

log_file="/home/arthurb/envs/iroco/src/bench-monitoring-dashboard/config/collectd_zabbix2.log"
# Vérifier que le fichier existe et n'est pas vide
[ -s "$LOGFILE" ] || exit 0
# Parcours ligne par ligne
while IFS= read -r line; do

  # Vérifier si la ligne est vide
  [ -z "$line" ] && continue
  # Vérifier si la ligne commence par un caractère de commentaire
  [[ "$line" =~ ^#.* ]] && continue
  # Vérifier que la ligne ne commence pas par [
  [[ "$line" =~ ^\[.* ]] && continue
  line="${line//$'\r'/}"
  read -r item value ts <<<"$line" 
  host="${item%%.*}" # Récupérer le nom d'hôte
  key="${item#*.}" # Récupérer la clé de la métrique
  echo "$host $key $ts $value" | \
  zabbix_sender -z "$ZBX_SERVER" -T -i - \
      >> /dev/null 2>&1

done < "$LOGFILE"

# Vider le fichier pour la prochaine itération
: > "$LOGFILE"
