#!/bin/bash

SOCK="/opt/collectd/var/run/collectd-unixsock"
HOST="arthurb-Latitude-7490"
STATUS=0
OUTPUT=""

for METRIC in interrupt nice softirq steal system user wait
do
    VALUE=$(/usr/bin/collectd-nagios -s "$SOCK" -n cpu/percent-$METRIC -H "$HOST" -g none)
    CODE=$?
    OUTPUT="$OUTPUT $METRIC: $VALUE;"
    if [ $CODE -gt $STATUS ]; then
        STATUS=$CODE
    fi
done

echo "Combined CPU Stats -$OUTPUT"
exit $STATUS
