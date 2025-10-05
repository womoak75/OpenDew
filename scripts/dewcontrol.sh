#!/bin/sh

MQTTHOST="localhost"
MQTTPORT="1883"
MQTTUSER=""
MQTTPASS=""
MQTTTOPICBASE="app/dewpoint"
MQTTTOPICCONTROL="$MQTTTOPICBASE/control"

DEWCONTROL_PROCESSONSTATUSCHANGE="1"

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
    done="1"
    if [ "$(type -t "custom_fanon")" = 'custom_fanon' ]; then
        done=$(custom_fanon)
    fi
    if [ "$done" != "0" ]; then
        echo "1"
    else
        echo "0"
    fi
}

fanoff() {
    echo "off"
    done="1"
    if [ "$(type -t "custom_fanoff")" = 'custom_fanoff' ]; then
        done=$(custom_fanoff)
    fi
    if [ "$done" != "0" ]; then
        echo "1"
    else
        echo "0"
    fi
}

get_status() {
    echo "$(get_var "DEWCONTROLSTAT")"
}

is_status_change() {
    actstatus=$(get_var "DEWCONTROLSTAT")
    newstatus=$1
    if [ "$actstatus" != "$newstatus" ]; then
        echo "1"
    else
        echo "0"
    fi
}

set_status() {
    statuschange=$(is_status_change "$1")
    doset="1"
    if [ "$statuschange" = "1" ]; then
        if [ "$newstatus" = "on" ] && type -t "custom_status_on" >/dev/null; then
            doset=$(custom_status_on)
        fi
        if [ "$newstatus" = "off" ] && type -t "custom_status_off" >/dev/null; then
            doset=$(custom_status_off)
        fi
    fi
    if [ "$doset" != "0" ]; then
        $(set_var "DEWCONTROLSTAT" "$1")
    fi
    echo "$doset"
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
    success="0"
    if [ "$s" = "on" & "$(type -t "custom_status_on")" = 'custom_status_on' ]; then
        success=$(custom_status_on)
    else
        if [ "$s" = "off" & "$(type -t "custom_status_off")" = 'custom_status_off' ]; then
            success=$(custom_status_off)
        fi
    fi
    echo "$success"
}

get_fan_status() {
    fan=$(echo "$1" | jq -r '.fan')
    if [ "$fan" = "1" ]; then
        echo "on"
    else 
        echo "off"
    fi
}

process_control_status_change() {
    status=$(get_fan_status "$1")
    statuschange=$(is_status_change "$status")
    if [ "$statuschange" = "1" ]; then
        $(process_control_msg "$1")
    fi
}

process_control() {
    $(process_control_msg "$1")
}

process_control_msg() {
    json=$1
    fan=$(echo "$json" | jq -r '.fan')
    if [ "$fan" = "1" ]; then
        logger "dewcontrol.sh: status: $(get_var "DEWCONTROLSTAT") ; command -> fan on"
        if [ "$(fanon)" = "1" ]; then
            set_status_on
        fi
    else
        logger "dewcontrol.sh: status: $(get_var "DEWCONTROLSTAT") ; command -> fan off"
        if [ "$(fanoff)" = "1" ]; then
            set_status_off
        fi
        
    fi
}

process() {
    json=$1
    type=$(echo "$json" | jq -r '.type')
    if [ "$type" = "control" ]; then
        if [ "$DEWCONTROL_PROCESSONSTATUSCHANGE" = "1" ]; then
            $(process_control_status_change "$1")
        else
            $(process_control "$1")
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