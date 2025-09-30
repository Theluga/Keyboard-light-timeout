#!/bin/bash

dim_time=10 # time to wait before dimming the keyboard
now_idle=false # flag to indicate if user is currently idle
idle_profile=2 # profile set when idle
priority=19 # CPU limit, adjust as needed 
# Set the priority of the current script
renice "$priority" "$$"

ratbagctl G815 profile active get
code=$?
if [ $code -ne 0 ]; then
    echo "ratbagctl failed with exit code $code"
    exit $code
fi


while true; do
    # Fetch the idle time using gdbus on gnome
    idle_time=$(gdbus call --session --dest org.gnome.Mutter.IdleMonitor --object-path /org/gnome/Mutter/IdleMonitor/Core --method org.gnome.Mutter.IdleMonitor.GetIdletime | awk '{print $2/1000}')

    # Check if user has gone idle
    if (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{ print (idle >= time) }') )) && [ "$now_idle" = false ]; then
        
        # Save current profile
        profile_before=$(ratbagctl G815 profile active get | awk '{print $NF}')

        if [ "$profile_before" -eq "$idle_profile" ]; then
            for p in 0 1 2; do
                if [ "$p" -ne "$idle_profile" ]; then
                    profile_before=$p
                    break
                fi
            done
        fi
        
        # Dim the screen
        $(ratbagctl G815 profile active set 2)
        now_idle=true
        
    # Check if user has become active
    elif (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{ print (idle < time) }') )) && [ "$now_idle" = true ]; then
        # Set profile to the value before dimming
        ratbagctl G815 profile active set "$profile_before"
        now_idle=false
    fi

    sleep 0.5
done

