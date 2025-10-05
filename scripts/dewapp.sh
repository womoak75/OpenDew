#!/bin/sh

MQTTHOST="localhost"
MQTTPORT="1883"
MQTTUSER=""
MQTTPASS=""
MQTTTOPICBASE="app/dewpoint"
MQTTTOPICOUT="$MQTTTOPICBASE/out"
MQTTTOPICCONTROL="$MQTTTOPICBASE/control"

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

calcdew() {
    temp_out=$(get_outsensors_avg "temp")
    #temp_in=$(get_sensor_temp $SENSOR_IN)
    temp_in=$(get_insensors_avg "temp")
    #dew_in=$(get_sensor_dew $SENSOR_IN)
    dew_in=$(get_insensors_avg "dew")
    dew_out=$(get_outsensors_avg "dew")
    #hum_in=$(get_sensor_hum $SENSOR_IN)
    hum_in=$(get_insensors_avg "hum")
    hum_out=$(get_outsensors_avg "hum")
    tempingttempmin=$(awk -v tempin="$temp_in" -v tempinmin="$ROOM_TEMP_MIN" -v dewin="$dew_in" -v dewout="$dew_out" -v dewmin="$DEW_DIFF_MIN" -v dewmax="$DEW_DIFF_MAX" 'BEGIN { if (tempin > tempinmin) { print "1";} else {print "0";} }')
    dewdelta=$(awk -v tempin="$temp_in" -v dewin="$dew_in" -v dewout="$dew_out" -v dewmin="$DEW_DIFF_MIN" -v dewmax="$DEW_DIFF_MAX" 'BEGIN { o = dewin - dewout; print o; }')
    dewwithin=$(awk -v awkdewdelta="$dewdelta" -v dewin="$dew_in" -v dewout="$dew_out" -v dewmin="$DEW_DIFF_MIN" -v dewmax="$DEW_DIFF_MAX" 'BEGIN { if (awkdewdelta > dewmin) { print "1";} else {print "0";} }')
    echo "temp_out=$temp_out ,temp_in=$temp_in , dew_in=$dew_in , hum_in=$hum_in"
    if [ "$temp_out" != "" -a "$temp_in" != "" -a "$dew_in" != "" ]; then
        echo "temp_out: $temp_out , temp_in: $temp_in , dew_in: $dew_in"
        fan=0
        if [ "$tempingttempmin" = "1" ]; then
            if [ "$dewwithin" = "1" ]; then
                echo "luefter on"
                fan=1
            else
                echo "dew_delta $dewdelta < DEW_DIFF_MIN $DEW_DIFF_MIN"
                echo "luefter off"
            fi
        else
            echo "act room temp $temp_in < room temp min $ROOM_TEMP_MIN"
            echo "luefter off"
        fi
        ts=$(get_timestamp_string)
        allin=$(all_insensors_array)
        allout=$(all_outsensors_array)
        JSONDEW="\"dew_avg\":{\"delta\":$dewdelta,\"indoor\":$dew_in,\"outdoor\":$dew_out}"
        JSONTEMP="\"temperature_avg\":{\"indoor\":$temp_in,\"outdoor\":$temp_out}"
        JSONHUM="\"humidity_avg\":{\"indoor\":$hum_in,\"outdoor\":$hum_out}"
        JSONSENSORS="\"sensors\":{\"indoor\":$allin,\"outdoor\":$allout}"
        JSONAPP="\"app\":{\"dew_diff_min\":$DEW_DIFF_MIN,\"dew_diff_max\":$DEW_DIFF_MAX,\"room_temperature_min\":$ROOM_TEMP_MIN,\"shouldVent\":$fan}"
        JSONOUT="{\"ts\":\"$ts\",$JSONDEW,$JSONTEMP,$JSONHUM,$JSONSENSORS,$JSONAPP}"
        mosquitto_pub -h "$MQTTHOST" -p "$MQTTPORT" -u "$MQTTUSER" -P "$MQTTPASS" -t "$MQTTTOPICOUT" -m "$JSONOUT"
    else
        echo "not initialized"
    fi
    
}

process() {
    json="$1"
    dewdelta=$(echo "$json" | jq '.dew_avg.delta')
    dewdeltamin=$(echo "$json" | jq '.app.dew_diff_min')
    roomtemperaturemin=$(echo "$json" | jq '.app.room_temperature_min')
    shouldvent=$(echo "$json" | jq '.app.shouldVent')
    temperaturein=$(echo "$json" | jq '.temperature_avg.indoor')

    roomtemperatureRange=$(awk -v tempin="$temperaturein" -v tempinmin="$roomtemperaturemin" 'BEGIN { if (tempin > tempinmin) { print "1";} else {print "0";} }')
    dewwithinRange=$(awk -v awkdewdelta="$dewdelta" -v dewmin="$dewdeltamin" 'BEGIN { if (awkdewdelta > dewmin) { print "1";} else {print "0";} }')
    ts=$(get_timestamp_string)
    fan=0
    if [ "$roomtemperatureRange" = "1" ]; then
        if [ "$dewwithinRange" = "1" ]; then
            logger "dewapp: luefter on"
            fan=1
        else
            logger "dewapp: dew_delta $dewdelta < DEW_DIFF_MIN $dewdeltamin -> luefter off"
        fi
    else
        echo "dewapp: act room temp $temperaturein < room temp min $roomtemperaturemin -> luefter off"
    fi
    jsonout="{\"ts\":\"$ts\",\"type\":\"control\",\"fan\":$fan}"
    mosquitto_pub -h "$MQTTHOST" -p "$MQTTPORT" -t "$MQTTTOPICCONTROL" -u "$MQTTUSER" -P "$MQTTPASS" -m "$jsonout"

}

mainfunc() {
    while true
    do
        mosquitto_sub -h "$MQTTHOST" -p "$MQTTPORT" -t "$MQTTTOPICOUT" -u "$MQTTUSER" -P "$MQTTPASS" | ( IFS='' ; while read line ; 
        do 
            check_main_process
            process $line
        done ; 
        )
        
    done
}

mainfunc