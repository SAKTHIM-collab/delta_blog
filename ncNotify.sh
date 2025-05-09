
if [ "$#" -lt 1 ]; then
    echo "Usage:"
    echo "For authors: $0 notify <message>"
    echo "For users: $0 check"
    exit 1
fi

USER=$(whoami)
USER_GROUPS=$(id -nG)
NOTIFY_FILE="/home/users/$USER/notifications.log"
PORT=9999

if [[ "$USER_GROUPS" =~ "g_author" ]]; then
  
    if [ "$1" != "notify" ]; then
        echo "Authors can only send notifications" >&2
        exit 1
    fi
    
    MESSAGE="$2"
    if [ -z "$MESSAGE" ]; then
        echo "Message cannot be empty" >&2
        exit 1
    fi
    

    SUBSCRIBE_FILE="/etc/subscriptions.yaml"
    if [ ! -f "$SUBSCRIBE_FILE" ]; then
        echo "No subscribers found" >&2
        exit 0
    fi
    
    subscribers=$(yq e ".subscriptions[] | select(.author == \"$USER\") | .user" "$SUBSCRIBE_FILE" 2>/dev/null)
    
 
    for sub in $subscribers; do
    
        if who | grep -q "^$sub "; then
         
            echo "New article from $USER: $MESSAGE" | nc -w 1 localhost "$PORT" &
        fi
        
     
        mkdir -p "/home/users/$sub"
        if [ ! -f "/home/users/$sub/notifications.log" ]; then
            echo "new_notifications" > "/home/users/$sub/notifications.log"
            echo "---" >> "/home/users/$sub/notifications.log"
        fi
        
     
        sed -i "/new_notifications/a $(date): New article from $USER: $MESSAGE" "/home/users/$sub/notifications.log"
    done
    
    echo "Notification sent to subscribers"
    
elif [[ "$USER_GROUPS" =~ "g_user" ]]; then
 
    if [ "$1" != "check" ]; then
        echo "Users can only check notifications" >&2
        exit 1
    fi
    
    if [ ! -f "$NOTIFY_FILE" ]; then
        echo "No notifications"
        exit 0
    fi
    
 
    echo "Unread notifications:"
    sed -n '/new_notifications/,/---/p' "$NOTIFY_FILE" | grep -v -e "new_notifications" -e "---"
    
  
    sed -i 's/new_notifications/old_notifications/' "$NOTIFY_FILE"
esudo nano /scripts/ncNotify.shlse
    echo "This command is only for users or authors" >&2
    exit 1
fi


if [ "$(id -u)" -eq 0 ]; then
    CRON_JOB="0 * * * * root /scripts/ncNotify check"
    if ! crontab -l | grep -q "/scripts/ncNotify check"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Hourly notification check cron job installed"
    fi
fi

exit 0
