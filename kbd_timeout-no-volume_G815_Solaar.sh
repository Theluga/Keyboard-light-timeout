#!/bin/bash

dim_time=10               # seconds before dimming keyboard
now_idle=false            # whether user is idle
idle_profile="Profile 3"  # profile to activate when idle
priority=19               # CPU priority for this script

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

idle_time0=$(gdbus call --session \
        --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime | awk '{print $2/1000}')

        
        
while true; do


    idle_time=$(awk -v base="$(gdbus call --session \
            --dest org.gnome.Mutter.IdleMonitor \
            --object-path /org/gnome/Mutter/IdleMonitor/Core \
            --method org.gnome.Mutter.IdleMonitor.GetIdletime | awk '{print $2/1000}')" \
            -v add="$idle_addition" 'BEGIN{print base + add}')
    
    is_greater=$(awk -v t0="$idle_time0" -v t1="$idle_time" 'BEGIN{print (t0 > t1)}')
    
     if [ "$is_greater" -eq 1 ]; then
        # idle_time0 > idle_time, do something
        
        idle_time=$(gdbus call --session \
        --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime | awk '{print $2/1000}')
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
            idle_addition=70
            # do nothing, still considered idle
        else
            set_profile "$profile_before"
            now_idle=false
            volume_changed_during_idle=false
        fi
        
         
        
    fi
    
    idle_time0=$(awk -v base="$(gdbus call --session \
            --dest org.gnome.Mutter.IdleMonitor \
            --object-path /org/gnome/Mutter/IdleMonitor/Core \
            --method org.gnome.Mutter.IdleMonitor.GetIdletime | awk '{print $2/1000}')" \
            -v add="$idle_addition" 'BEGIN{print base + add}')
        
    sleep 0.5
done

