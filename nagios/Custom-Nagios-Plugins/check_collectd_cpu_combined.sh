#!/bin/bash

SOCK="/opt/collectd/var/run/collectd-unixsock"
HOST="arthurb-Latitude-7490"
STATUS=0
OUTPUT=""


regex='^[^:]+:[[:space:]]*([0-9]+)[[:space:]]critical,[[:space:]]*([0-9]+)[[:space:]]warning,[[:space:]]*([0-9]+)[[:space:]]okay[[:space:]]\|[[:space:]]value=([0-9]+\.[0-9]+)'

nb_critical=0
nb_warning=0
nb_okay=0

for METRIC in interrupt nice softirq steal system user wait
do
    output=$(/usr/bin/collectd-nagios -s "$SOCK" -n cpu/percent-$METRIC -H "$HOST" -g none)
    CODE=$?
    
    if [[ $output =~ $regex ]]; then
      critical=${BASH_REMATCH[1]}
      warning=${BASH_REMATCH[2]}
      okay=${BASH_REMATCH[3]}
      value=${BASH_REMATCH[4]}
    else
      echo "Le format de sortie n'est pas reconnu : $output"
      exit 3  # UNKNOWN si parsing impossible
    fi

    OUTPUT="$OUTPUT $METRIC=$value;;;;"

    nb_critical=$((nb_critical + critical))
    nb_warning=$((nb_warning + warning))
    nb_okay=$((nb_okay + okay))

    if [ $CODE -gt $STATUS ]; then
        STATUS=$CODE
    fi

done

echo "OKAY: $nb_critical critical, $nb_warning warning, $nb_okay okay |$OUTPUT"
exit $STATUS
