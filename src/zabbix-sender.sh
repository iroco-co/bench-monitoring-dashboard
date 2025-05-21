#!/bin/bash
# -----------------------------------------------------------------------------
# Parcourt le log de collectd, envoie chaque métrique à Zabbix, puis vide le log
# -----------------------------------------------------------------------------

# --- Variables ---
UNIX_SOCKET="$1"
DESTINATION_SERVER="$2"
DESTINATION_PORT="$3"
ZBX_SERVER="$DESTINATION_SERVER:$DESTINATION_PORT"

# --- Fonction d'envoi de métriques à Zabbix ---
send_to_zabbix() {
  local host="$1"
  local key="$2"
  local ts="$3"
  local value="$4"

  # Envoi de la métrique à Zabbix
  echo "$host  $key $ts $value" | \
  zabbix_sender -z "$ZBX_SERVER" -T -i - \
      >> /dev/null 2>&1
}

send_value_from_key() {
  local host="$1"
  local key="$2"
  local ts="$3"
  local value="$4"
  
  local nb_values=$(echo "$values" | sed -n '1p' | awk '{print $1}')

  if [ "$nb_values" -eq 1 ]; then
    value=$(echo "$values" | sed -n '2p' | cut -d'=' -f2)
    send_to_zabbix "$host" "$key" "$ts" "$value"
  else
    for i in $(seq 2 $(($nb_values + 1))); do
      value=$(echo "$values" | sed -n "${i}p" | cut -d'=' -f2)
      new_key=${key}.$(echo "$values" | sed -n "${i}p" | cut -d'=' -f1)
      send_to_zabbix "$host" "$new_key" "$ts" "$value"
    done
  fi
}

# --- Lecture du socket unix collectd et envoi des métriques ---

listval=$(echo "LISTVAL" | socat - UNIX-CONNECT:$UNIX_SOCKET)
# supprimer la première ligne
listval=$(echo "$listval" | sed '1d')
while read -r line; do
  # Extraction des valeurs
  ts=$(echo "$line" | awk '{print $1}' | cut -d'.' -f1)
  item=$(echo "$line" | awk '{print $2}')
  host=$(echo "$item" | cut -d'/' -f1)
  key=$(echo "$item" | cut -d'/' -f2- | tr '/' .)
  values=$(echo GETVAL "$item" | socat - UNIX-CONNECT:$UNIX_SOCKET)

  send_value_from_key "$host" "$key" "$ts" "$values" &

  # Envoi de la métrique à Zabbix
done <<< "$listval"

