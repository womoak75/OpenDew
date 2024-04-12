#!/bin/sh

DEW_DIFF_MAX=2.3 #Taupunktschwelle, ist die maximale Differenz zwischen TPunkt innen und aussen
DEW_DIFF_MIN=1.0 #festlegen der Taupunktschwelle, ist die minimale Differenz zwischen TPunkt innen und aussen
ROOM_TEMP_MIN=10.0 # Raum Temperatur welche nicht unterschritten werden darf
MQTTHOST="localhost"
MQTTPORT="1883"
MQTTUSER=""
MQTTPASS=""
MQTTTOPICBASE="app/dewpoint"
MQTTTOPICIN="$MQTTTOPICBASE/in"
MQTTTOPICOUT="$MQTTTOPICBASE/out"
MQTTTOPICSTATUS="$MQTTTOPICBASE/status"
SENSOR_DIR=/tmp/sensors
SENSORCONFIG="{\"insensors\":[\"keller1\"],\"outsensors\":[\"aussen1stock\"]}"

APPSTATUS_INIT="init"
APPSTATUS_RUNNING="running"

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

save_sensor() {
    NAME=$(echo "$1" | jq -r '.name')
    echo "$1" > "$SENSOR_DIR/$NAME"
    echo "save_sensor $1 to $SENSOR_DIR/$NAME"
}

get_sensor() {
    if [ ! -e $SENSOR_DIR/$1 ]; then
        echo ""
    else
        JSON=$(cat $SENSOR_DIR/$1)
        echo "$JSON"
    fi
}

get_sensors_avg() {
    sensortype="$1"
    prop="$2"

    set_var "SENSORSUM" "0"
    set_var "SENSORCOUNT" "0"
    echo "$SENSORCONFIG" | jq -r "$sensortype" | while read -r sensor; 
    do 
        stemp=$(get_sensor_temp $sensor)
        if [ "$prop" = "hum" ]; then
            stemp=$(get_sensor_hum $sensor)
        fi
        if [ "$prop" = "dew" ]; then
            stemp=$(get_sensor_dew $sensor)
        fi
        aktsum=$(get_var "SENSORSUM")
        aktcount=$(get_var "SENSORCOUNT")
        aktsum=$(awk -v tempin="$stemp" -v sum="$aktsum"  'BEGIN { sum = sum + tempin ; print sum; }')
        aktcount=$(awk -v invar="$aktcount" 'BEGIN { invar = invar + 1 ; print invar; }')
        set_var "SENSORSUM" "$aktsum"
        set_var "SENSORCOUNT" "$aktcount"
    done
    aktsum=$(get_var "SENSORSUM")
    aktcount=$(get_var "SENSORCOUNT")
    sensorsum=$(awk -v count="$aktcount" -v sum="$aktsum"  'BEGIN { sum = sum / count ; print sum; }')
    echo "$sensorsum"
}

get_insensors_avg() {
    prop="$1"
    isinit=$(all_insensors_available)
    if [ "$isinit" = "1" ]; then
       out=$(get_sensors_avg ".insensors[]" "$prop")
       echo "$out"
    else
        echo ""
    fi
}

get_outsensors_avg() {
    prop="$1"
    isinit=$(all_outsensors_available)
    if [ "$isinit" = "1" ]; then
       out=$(get_sensors_avg ".outsensors[]" "$prop")
       echo "$out"
    else
        echo ""
    fi
}

all_outsensors_available() {
    set_var "OUTSENSORINIT" "1"
    echo "$SENSORCONFIG" | jq -r '.outsensors[]' | while read -r sensor; 
    do 
        tmpvar=$(get_var "OUTSENSORINIT")
        if [ "$tmpvar" = "1" ]; then
            stemp=$(get_sensor $sensor)
            if [ "$stemp" = "" ]; then
                set_var "OUTSENSORINIT" "0"
            fi
        fi
    done ;
    var=$(get_var "OUTSENSORINIT")
    echo "$var"
}

all_insensors_available() {
    set_var "SENSORINIT" "1"
    echo "$SENSORCONFIG" | jq -r '.insensors[]' | while read -r sensor; 
    do 
        tmpvar=$(get_var "SENSORINIT")
        if [ "$tmpvar" = "1" ]; then
            stemp=$(get_sensor $sensor)
            if [ "$stemp" = "" ]; then
                set_var "SENSORINIT" "0"
            fi
        fi
    done ;
    var=$(get_var "SENSORINIT")
    echo "$var"
}

all_insensors_array() {
    set_var "SENSOROUTARRAY" ""
    echo "$SENSORCONFIG" | jq -r '.insensors[]' | while read -r sensor; 
    do 
        tmpvar=$(get_var "SENSOROUTARRAY")
        stemp=$(get_sensor $sensor)
        if [ "$stemp" != "" ]; then
                set_var "SENSOROUTARRAY" "$tmpvar$stemp,"
        fi
    done ;
    var=$(get_var "SENSOROUTARRAY")
    var=${var%?}
    echo "[$var]"
}

all_outsensors_array() {
    set_var "SENSOROUTARRAY" ""
    echo "$SENSORCONFIG" | jq -r '.outsensors[]' | while read -r sensor; 
    do 
        tmpvar=$(get_var "SENSOROUTARRAY")
        stemp=$(get_sensor $sensor)
        if [ "$stemp" != "" ]; then
                set_var "SENSOROUTARRAY" "$tmpvar$stemp,"
        fi
    done ;
    var=$(get_var "SENSOROUTARRAY")
    var=${var%?}
    echo "[$var]"
}

get_sensor_temp() {
    JSON=$(get_sensor $1)
    tmpc=$(echo "$JSON" | jq '.temperature_C')
    echo "$tmpc"
}

get_sensor_hum() {
    JSON=$(get_sensor $1)
    tmpc=$(echo "$JSON" | jq '.humidity')
    echo "$tmpc"
}

get_sensor_dew() {
    JSON=$(get_sensor $1)
    tmpc=$(echo "$JSON" | jq '.dew')
    echo "$tmpc"
}

publish_status() {
    status="$1"
    mosquitto_pub -h "$MQTTHOST" -p "$MQTTPORT" -u "$MQTTUSER" -P "$MQTTPASS" -t "$MQTTTOPICSTATUS" -m "{\"status\":\"$status\"}"
}

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
    dewdelta=$(awk -v tempin="$temp_in" -v dewin="$dew_in" -v dewout="$dew_out" -v dewmin="$DEW_DIFF_MIN" -v dewmax="$DEW_DIFF_MAX" 'BEGIN { o = dewin - dewout; print o; }')
    echo "temp_out=$temp_out ,temp_in=$temp_in , dew_in=$dew_in , hum_in=$hum_in"
    if [ "$temp_out" != "" -a "$temp_in" != "" -a "$dew_in" != "" ]; then
        echo "temp_out: $temp_out , temp_in: $temp_in , dew_in: $dew_in"
        ts=$(get_timestamp_string)
        allin=$(all_insensors_array)
        allout=$(all_outsensors_array)
        JSONDEW="\"dew_avg\":{\"delta\":$dewdelta,\"indoor\":$dew_in,\"outdoor\":$dew_out}"
        JSONTEMP="\"temperature_avg\":{\"indoor\":$temp_in,\"outdoor\":$temp_out}"
        JSONHUM="\"humidity_avg\":{\"indoor\":$hum_in,\"outdoor\":$hum_out}"
        JSONSENSORS="\"sensors\":{\"indoor\":$allin,\"outdoor\":$allout}"
        JSONAPP="\"app\":{\"dew_diff_min\":$DEW_DIFF_MIN,\"dew_diff_max\":$DEW_DIFF_MAX,\"room_temperature_min\":$ROOM_TEMP_MIN}"
        JSONOUT="{\"ts\":\"$ts\",$JSONDEW,$JSONTEMP,$JSONHUM,$JSONSENSORS,$JSONAPP}"
        mosquitto_pub -h "$MQTTHOST" -p "$MQTTPORT" -u "$MQTTUSER" -P "$MQTTPASS" -t "$MQTTTOPICOUT" -m "$JSONOUT"
    else
        echo "not initialized"
    fi
    
}

to_control_out_string() {
    IN="$1"
    sensortemp=$(echo "$IN" | jq '.temperature_C')
    sensorhum=$(echo "$IN" | jq '.humidity')
    sensorid=$(echo "$IN" | jq '.id')
    sensorchannel=$(echo "$IN" | jq '.channel')
    if [ "$sensortemp" != "" & "$sensorhum" != "" & "$sensortemp" != "" ]; then
        echo "{\"name\":\"$sensorchannel\_$sensorid\",\"temperature_C\":$sensortemp,\"humidity\":$sensorhum}"
    else
        logger "not all sensor data available yet"
    fi
}

mainfunc() {
    while true
    do
        mosquitto_sub -h "$MQTTHOST" -p "$MQTTPORT" -t "$MQTTTOPICIN" -u "$MQTTUSER" -P "$MQTTPASS" | ( IFS='' ; while read line ; 
        do 
            check_main_process
            save_sensor $line
            ininit=$(all_insensors_available)
            outinit=$(all_outsensors_available)
            if [ "$ininit" = "1" ]; then
                    if [ "$outinit" = "1" ]; then
                        publish_status "$APPSTATUS_RUNNING"
                        calcdew
                    else
                        logger "outdoor sensor data not complete yet!"
                    fi
            else
                logger "indoor sensor data not complete yet!"
            fi
        done ; 
        )
        
    done
}

publish_status "$APPSTATUS_INIT"
init_dir
mainfunc