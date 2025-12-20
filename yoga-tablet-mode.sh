#!/bin/bash

SCREEN="eDP-1"
STATE_FILE="/tmp/yoga_tablet_mode"
ORIENTATION_FILE="/tmp/yoga_orientation"

LAST_ORIENTATION="normal"

function background_read_state {
    while true; do
        evtest "/dev/input/tablet-mode-switch" | grep -Po --line-buffered 'SW_TABLET_MODE.*\K\d+' | while read state; do
            if [[ "$state" =~ ^[0-1]$ ]]; then
                prev_state=$(cat "$STATE_FILE")
                echo "states now $state!"
                echo "$state" > $STATE_FILE
                
                if [ "${state}" != "${prev_state}" ]; then
                    echo "state changed from $prev_state to $state"

                    if [[ $state -eq 0 ]]; then
                        echo "LAPTOP MODE!"
                        rotate "normal"
                    else
                        echo "state change; reorienting"
                        echo "$LAST_ORIENTATION"
                        rotate $(cat $ORIENTATION_FILE)
                    fi
                fi
	        else
		        echo "hm,,that wrong"
            fi
        done
    done
}

function rotate {
    case $1 in
        "normal")
            ROTATION="normal"
            ;;
        "right-up")
            ROTATION="right"
            ;;
        "bottom-up")
            ROTATION="inverted"
            ;;
        "left-up")
            ROTATION="left"
            ;;
    esac

    echo "received rotation: $ROTATION"

    kscreen-doctor "output.$SCREEN.rotation.$ROTATION"
}

function check_startup {
    echo "checking for hid_sensor_accel_3d..."
    if ! lsmod | grep -q "hid_sensor_accel_3d"; then 
        echo "hid_sensor_accel_3d not found, restarting amd_pmf and amd_sfh..."
        startup
    else
        echo "found hid_sensor_accel_3d"
    fi
}

function startup {
    sudo modprobe -r amd_pmf amd_sfh
    echo "wait..."
    sleep 1
    sudo modprobe amd_sfh amd_pmf
    sleep 4
    echo "wait ok"
}

check_startup
background_read_state &

trap 'trap - SIGTERM && kill 0' SIGINT SIGTERM EXIT

while IFS='$\n' read -r line; do
    rotation="$(echo $line | sed -En "s/^.*orientation changed: (.*)/\1/p")"
    if [[ ! -z $rotation ]]; then
        LAST_ORIENTATION="$rotation"

        echo "$rotation" > $ORIENTATION_FILE

        echo "orientation is now stored as $LAST_ORIENTATION"
        
        mode=$(cat "$STATE_FILE")
        
        if [[ $mode == "1" ]]; then
            echo "yoga in tablet mode, rotating"
            rotate $rotation
        fi
    fi
done < <(stdbuf -oL monitor-sensor)

