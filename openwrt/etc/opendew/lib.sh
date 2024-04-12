#!/bin/sh

SENSOR_DIR=/tmp/sensors


MAIN_PID=$$

init_dir() {
    rm -fr $SENSOR_DIR
    mkdir $SENSOR_DIR
}

set_var() {
    NAME=$1
    V=$2
    echo "$V" > $SENSOR_DIR/$NAME
}

get_var() {
    NAME=$1
     if [ ! -e $SENSOR_DIR/$NAME ]; then
        echo ""
    else
        V=$(cat $SENSOR_DIR/$NAME)
        echo "$V"
    fi
}

get_timestamp_string() {
    echo "$(date +%Y-%m-%d_%H:%M:%S+%Z)"
}

get_last_modification_time_in_sec() {
    f=$1
    last_modified=$(date +%s -r $f)
    echo "$last_modified"
}

get_time_in_sec_since_last_modification() {
    f=$1
    current=$(date +%s)
    last_modified=$(get_last_modification_time_in_sec $f)
    diff=$((current - last_modified))
    echo "$diff"
}

check_main_process() {
    if [ ! -d "/proc/$MAIN_PID" ]; then
        exit
    fi
}

if [ -f "/etc/opendew/custom.sh" ]; then
    . "/etc/opendew/custom.sh"
else
    if [ -f "$HOME/.opendew/custom.sh" ]; then
        . "$HOME/.opendew/opendew/custom.sh"
    fi
fi


