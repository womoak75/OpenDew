#!/bin/sh

MQTTHOST="localhost"
MQTTPORT="1883"
MQTTUSER=""
MQTTPASS=""
MQTTTOPICBASE="app/dewpoint"
MQTTTOPICCONTROL="$MQTTTOPICBASE/control"

if [ -f "/etc/opendew/opendew.cfg" ]; then
    . "/etc/opendew/opendew.cfg"
fi

if [ -f "/etc/opendew/lib.sh" ]; then
    . "/etc/opendew/lib.sh"
fi

if [ -f "$HOME/.opendew/opendew.cfg" ]; then
    . "HOME/.opendew/opendew.cfg"
fi

SCRIPT_DIR=$(dirname -- "$0")

if [ -f "$SCRIPT_DIR/lib.sh" ]; then
    . "$SCRIPT_DIR/lib.sh"
fi

fanon() {
    echo "on"
    if [ "$(type -t "custom_fanon")" = 'custom_fanon' ]; then
        $(custom_fanon)
    fi
}

fanoff() {
    echo "off"
    if [ "$(type -t "custom_fanoff")" = 'custom_fanoff' ]; then
        $(custom_fanoff)
    fi
}

get_status() {
    echo "$(get_var "DEWCONTROLSTAT")"
}
set_status() {
    actstatus=$(get_var "DEWCONTROLSTAT")
    newstatus=$1
    $(set_var "DEWCONTROLSTAT" "$1")
    if [ "$actstatus" != "$newstatus" ]; then
        if [ "$newstatus" = "on" ] && type -t "custom_status_on" >/dev/null; then
            $(custom_status_on)
        fi
        if [ "$newstatus" = "off" ] && type -t "custom_status_off" >/dev/null; then
                $(custom_status_off)
        fi
    fi
}

set_status_on() {
     $(set_status "on")
}

set_status_off() {
     $(set_status "off")
}

set_status_init() {
     $(set_status "init")
}

status_change() {
    s="$1"
    if [ "$s" = "on" & "$(type -t "custom_status_on")" = 'custom_status_on' ]; then
        $(custom_status_on)
    else
        if [ "$s" = "off" & "$(type -t "custom_status_off")" = 'custom_status_off' ]; then
            $(custom_status_off)
        fi
    fi
}

process() {
    json=$1
    type=$(echo "$json" | jq -r '.type')
    fan=$(echo "$json" | jq -r '.fan')
    if [ "$type" = "control" ]; then
        if [ "$fan" = "1" ]; then
            logger "dewcontrol.sh: status: $(get_var "DEWCONTROLSTAT") ; command -> fan on"
            set_status_on
            fanon
        else
            logger "dewcontrol.sh: status: $(get_var "DEWCONTROLSTAT") ; command -> fan off"
            set_status_off
            fanoff
        fi
    else 
        logger "dewcontrol.sh: unknown type: $type"
    fi
}

mainfunc() {
    while true
    do
        mosquitto_sub -h "$MQTTHOST" -p "$MQTTPORT" -t "$MQTTTOPICCONTROL" -u "$MQTTUSER" -P "$MQTTPASS" | ( IFS='' ; while read line ; 
        do 
            check_main_process
            process $line
        done ; 
        )
        
    done
}

set_status_init
mainfunc