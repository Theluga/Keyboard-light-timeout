#!/bin/bash

dim_time=15               # seconds before dimming keyboard
now_idle=false            # whether user is idle
idle_profile="Profile 3"  # profile to activate when idle
priority=19               # CPU priority for this script
tmp_file="/tmp/wprintidle_output.txt"
lock_file="/tmp/kbd_timeout_G815.lock"

# Prevent multiple instances of this script
exec 9>"$lock_file"
if ! flock -n 9; then
    echo "Script is already running."
    exit 1
fi

# Set low priority
renice "$priority" "$$" >/dev/null

# Function to get current active profile name
get_current_profile() {
    solaar config G815 onboard_profiles 2>/dev/null | \
        awk -F'= ' '/onboard_profiles/{print $2}' | xargs
}

# Function to set a profile active
set_profile() {
    local profile="$1"
    solaar config G815 onboard_profiles "$profile" >/dev/null 2>&1
}

# Initial check
current_profile=$(get_current_profile)
if [ -z "$current_profile" ]; then
    echo "❌ Could not get current profile via solaar."
    exit 1
fi


# Variable to track if volume changed recently
volume_changed_during_idle=false
idle_addition=0

# Start wprintidle only once
if ! pgrep -x "wprintidle" > /dev/null; then
    wprintidle > "$tmp_file" &
    sleep 0.1
fi

# Clean up temporary file when this script exits
cleanup() {
    rm -f "$tmp_file"
}
trap cleanup EXIT INT TERM

get_idle_time() {

    # Check if wprintidle is running
    if ! pgrep -x "wprintidle" > /dev/null; then
        # If not, start wprintidle in the background and redirect output to a file
        wprintidle > "$tmp_file" &
        echo "wprintidle started in the background."
        sleep 0.1
    fi

    # Send USR2 signal to wprintidle to force it to update the idle time
    pkill -USR2 wprintidle

    # get the idle time
    clean_idle_time=$(tr -d '\0' < "$tmp_file" | tail -n 1)

    # replace values there to not be without memory
    echo "$clean_idle_time" > "$tmp_file"

    echo "$clean_idle_time" | awk '{print $1/1000}'
}

# Get idle time using qdbus (for any wayland compatible with wprintidle DE)
idle_time0=$(get_idle_time)

while true; do


    idle_time=$(awk -v base="$(get_idle_time)" \
            -v add="$idle_addition" 'BEGIN{print base + add}')
    
    is_greater=$(awk -v t0="$idle_time0" -v t1="$idle_time" 'BEGIN{print (t0 > t1)}')
    
     if [ "$is_greater" -eq 1 ]; then
        # idle_time0 > idle_time, do something
        
        idle_time=$(get_idle_time)
        idle_addition=0
    fi
            
            
            
    # Save previous volume if not set
    if ! [ -v volume_before ]; then
        volume_before=$(wpctl get-volume @DEFAULT_SINK@)
    fi

    # Compare volumes
    volume_now=$(wpctl get-volume @DEFAULT_SINK@)
    if [ "$volume_before" != "$volume_now" ]; then
        volume_changed_during_idle=true
        volume_change_time=$(date +%s%3N)
    fi
    volume_before="$volume_now"

    # Became idle
    # Select keyboard profile without being the idle one, so it's the first in order
    if (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{print (idle >= time)}') )) && [ "$now_idle" = false ]; then
        profile_before=$(get_current_profile)
        if [ "$profile_before" == "$idle_profile" ]; then
            for p in "Profile 1" "Profile 2" "Profile 3"; do
                if [ "$p" != "$idle_profile" ]; then
                    profile_before="$p"
                    break
                fi
            done
        fi
        set_profile "$idle_profile"
        idle_addition=0
        now_idle=true

    # Became active
    elif (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{print (idle < time)}') )) && [ "$now_idle" = true ]; then
        current_time=$(date +%s%3N)

        # Ignore brief wake caused by volume change
        # 1000 ms of sensibility of volume
        if [ "$volume_changed_during_idle" = true ] && (( current_time - volume_change_time < 1000 )); then
            idle_addition=$(awk -v base="$dim_time" -v factor="$dim_time" 'BEGIN {print base * factor}')
            # do nothing, still considered idle
        else
            set_profile "$profile_before"
            now_idle=false
            volume_changed_during_idle=false
        fi
        
         
        
    fi
    
    idle_time0=$(awk -v base="$(get_idle_time)" \
            -v add="$idle_addition" 'BEGIN{print base + add}')
        
    sleep 0.5
done
