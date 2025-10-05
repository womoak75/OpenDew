#!/bin/sh
tickintervalSec=1
count=0

MAIN_PID=$$

periodic_5sec_function() {
    echo "5sec"
}

periodic_60sec_function() {
    echo "60sec"
}

periodic_1sec_function() {
    echo "tick $count"
}

check_main_process() {
    if [ ! -d "/proc/$MAIN_PID" ]; then
        exit
    fi
}

while true; do
    sleep "$tickintervalSec"
    check_main_process
    count=$(($count+1))
    periodic_1sec_function
    if [ "$(($count%5))" = "0" ]; then
        periodic_5sec_function
    fi
    if [ "$(($count%60))" = "0" ]; then
            periodic_60sec_function
    fi
done
