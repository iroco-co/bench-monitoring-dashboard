#!/usr/bin/env bash

SOCK="/opt/collectd/var/run/collectd-unixsock.sock"
HOST="arthurb-Latitude-7490"
PLUGIN="/usr/bin/collectd-nagios"

EXIT_STATUS=0

# Regex pour extraire critical, warning, okay et value
regex='^[^:]+:[[:space:]]*([0-9]+)[[:space:]]critical,[[:space:]]*([0-9]+)[[:space:]]warning,[[:space:]]*([0-9]+)[[:space:]]okay[[:space:]]\|[[:space:]]value=([0-9]+\.[0-9]+)'

nb_critical=0
nb_warning=0
nb_okay=0
OUTPUT_METRICS=""

# Boucle sur chaque état CPU
for METRIC in $METRICS; do
  # 1) Appel unique du plugin par état
  output="$($PLUGIN -s "$SOCK" -n $METRIC -H "$HOST" -g none)"
  code=$?
  # 2) Mappage du code de sortie (>3 → 3)
  (( code > 3 )) && code=3
  # 3) Agrégation du code le plus sévère
  (( code > EXIT_STATUS )) && EXIT_STATUS=$code
  # 4) Parsing de la sortie
  if [[ $output =~ $regex ]]; then
    crit=${BASH_REMATCH[1]}
    warn=${BASH_REMATCH[2]}
    ok=${BASH_REMATCH[3]}
    val=${BASH_REMATCH[4]}
  else
    echo "UNKNOWN: format inattendu → $output"
    exit 3
  fi
  # 5) Accumulation des compteurs
  nb_critical=$(( nb_critical + $crit ))
  nb_warning=$(( nb_warning + $warn ))
  nb_okay=$(( nb_okay + $ok ))
  OUTPUT_METRICS+=" $METRIC=$val;;;;"
done

# 6) Sortie finale
echo "OKAY: $nb_critical critical, $nb_warning warning, $nb_okay okay |$OUTPUT_METRICS"
exit $EXIT_STATUS
