#!/bin/sh

MQTTHOST="localhost"
MQTTPORT="1883"
MQTTUSER=""
MQTTPASS=""
MQTTTOPICBASE="app/dewpoint"
MQTTTOPICIN="$MQTTTOPICBASE/in"
MQTTREADER_OUTTOPIC="app/dewpoint/sensor/in"
SENSORMASTERCONFIG="[{\"name\":\"id3-116\",\"id\":\"keller1\"},{\"name\":\"id1-231\",\"id\":\"aussen1stock\"}]"

if [ -f "/etc/opendew/opendew.cfg" ]; then
    . "/etc/opendew/opendew.cfg"
fi

if [ -f "/etc/opendew/lib.sh" ]; then
    . "/etc/opendew/lib.sh"
fi

if [ -f "$HOME/.opendew/opendew.cfg" ]; then
    . "$HOME/.opendew/opendew.cfg"
fi

SCRIPT_DIR=$(dirname -- "$0")

if [ -f "$SCRIPT_DIR/lib.sh" ]; then
    . "$SCRIPT_DIR/lib.sh"
fi

get_sensor_name() {
    KEY="$1"
    NAME=$(echo "$SENSORMASTERCONFIG" | jq -r --argjson k "$KEY" '.[] | select(.name==$k).id')
    if [ "$NAME" = "null" ]; then
        echo ""
    else
        echo "$NAME"
    fi
}

read_sensor_in() {
    #echo "in: $1"
    N=$(echo "$1" | jq '.name')
    echo ".name = $N"
    T=$(echo "$1" | jq -r '.temperature_C')
    H=$(echo "$1" | jq -r '.humidity')
    ID=$(get_sensor_name "$N")
    D=$(calcdew "$T" "$H")
    ts=$(get_timestamp_string)
    MSG="{\"ts\":\"$ts\",\"name\":\"$ID\",\"temperature_C\":$T,\"humidity\":$H,\"dew\":$D}"
    mosquitto_pub -h "$MQTTHOST" -p "$MQTTPORT" -t "$MQTTTOPICIN" -u "$MQTTUSER" -P "$MQTTPASS" -m "$MSG"
}

calcdew() {
#fH = (log10(fFeuchteAussen) - 2) / 0.4343 + (17.62 * fTempAussen) / (243.12 + fTempAussen);
#fTPktAussen = 243.12 * fH / (17.62 - fH);
THUM=$2
TTEMPC=$1
    if [ "$(type -t "custom_sensor_calcdew")" = 'custom_sensor_calcdew' ]; then
        DEWTEMP=$(custom_sensor_calcdew "$THUM" "$TTEMPC")
        echo "$DEWTEMP"
    else
        DEWTEMP=$(awk -v HUM="$THUM" -v TEMPC="$TTEMPC" 'BEGIN { fh = (log(HUM)/log(10)-2)/0.4343 + (17.62 * TEMPC) / (243.12 + TEMPC); dew = 243.12 * fh / (17.62 - fh); print dew }')
        echo "$DEWTEMP"
    fi
}

mainfunc() {
    while true
    do
        mosquitto_sub -h "$MQTTHOST" -p "$MQTTPORT" -u "$MQTTUSER" -P "$MQTTPASS" -t "$MQTTREADER_OUTTOPIC" | ( IFS='' ; while read line ; 
        do 
            check_main_process
            out=$(read_sensor_in $line)
            echo "$out"
        done ; 
        )
        
    done
}

mainfunc

echo "sensormaster exiting"