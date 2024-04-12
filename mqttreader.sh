#!/bin/sh

MQTTREADER_INTOPIC="rtl_433/+/events"
MQTTREADER_OUTTOPIC="app/dewpoint/sensor/in"
MQTTHOST="localhost"
MQTTPORT="1883"
MQTTUSER=""
MQTTPASS=""

if [ -f "/etc/opendew/opendew.cfg" ]; then
    . "/etc/opendew/opendew.cfg"
fi

if [ -f "/etc/opendew/lib.sh" ]; then
    . "/etc/opendew/lib.sh"
fi

if [ -f "$HOME/.opendew/.dewreaderconfig" ]; then
    . "$HOME/.opendew/.dewreaderconfig"
fi

SCRIPT_DIR=$(dirname -- "$0")

if [ -f "$SCRIPT_DIR/lib.sh" ]; then
    . "$SCRIPT_DIR/lib.sh"
fi

to_sensor_in_string() {
    IN="$1"
    sensortemp=$(echo "$IN" | jq -r '.temperature_C')
    sensorhum=$(echo "$IN" | jq -r '.humidity')
    sensorid=$(echo "$IN" | jq -r '.id')
    sensorchannel=$(echo "$IN" | jq -r '.channel')
    sensorname=$(echo "id$sensorchannel-$sensorid")
    echo "{\"name\":\"$sensorname\",\"temperature_C\":$sensortemp,\"humidity\":$sensorhum}"
}

while true
do
    mosquitto_sub -h "$MQTTHOST" -p "$MQTTPORT" -u "$MQTTUSER" -P "$MQTTPASS" -t "$MQTTREADER_INTOPIC" | ( IFS='' ; while read line ; 
    do 
        check_main_process
        sensorstring=$(to_sensor_in_string "$line") ;
        #echo "$sensorstring" >>$queue ;
        mosquitto_pub -h "$MQTTHOST" -p "$MQTTPORT" -u "$MQTTUSER" -P "$MQTTPASS" -t "$MQTTREADER_OUTTOPIC" -m "$sensorstring"
        #echo "$sensorstring" ; 
    done ; 
    )
    
done