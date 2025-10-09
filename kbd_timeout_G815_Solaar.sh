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

while true; do
    # Get idle time in seconds from GNOME IdleMonitor
    idle_time=$(gdbus call --session \
        --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime | awk '{print $2/1000}')

    # User became idle
    if (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{ print (idle >= time) }') )) && [ "$now_idle" = false ]; then
        profile_before=$(get_current_profile)
        if [ "$profile_before" == "$idle_profile" ]; then
            # pick another profile to restore to later
            for p in "Profile 1" "Profile 2" "Profile 3"; do
                if [ "$p" != "$idle_profile" ]; then
                    profile_before="$p"
                    break
                fi
            done
        fi
        set_profile "$idle_profile"
        now_idle=true

    # User became active again
    elif (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{ print (idle < time) }') )) && [ "$now_idle" = true ]; then
        set_profile "$profile_before"
        now_idle=false
    fi

    sleep 0.5
done

