#!/bin/bash
if [ "$#" -eq 0 ]; then
    echo "Usage:"
    echo "For users: $0 request"
    echo "For admin: $0 approve"
    exit 1
fi

USER=$(whoami)
REQUEST_FILE="/etc/requests.yaml"

if [[ "$1" == "request" ]]; then
  
    if [ ! "$(id -nG)" =~ "g_user" ]; then
        echo "Only regular users can request author role" >&2
        exit 1
    fi
    
 
    if [ -f "$REQUEST_FILE" ] && yq e ".requests[] | select(.user == \"$USER\")" "$REQUEST_FILE" >/dev/null; then
        echo "You already have a pending request" >&2
        exit 0
    fi
    
 
    if [ ! -f "$REQUEST_FILE" ]; then
        echo "requests: []" > "$REQUEST_FILE"
        chmod 640 "$REQUEST_FILE"
    fi
    
 
    yq e ".requests += [{\"user\": \"$USER\", \"status\": \"pending\"}]" -i "$REQUEST_FILE"
    
    echo "Author role request submitted. Waiting for admin approval."
    
elif [[ "$1" == "approve" ]]; then
 
    if [ ! "$(id -nG)" =~ "g_admin" ]; then
        echo "Only admin can approve requests" >&2
        exit 1
    fi
    
    if [ ! -f "$REQUEST_FILE" ]; then
        echo "No pending requests"
        exit 0
    fi
    
 
    pending=$(yq e '.requests[] | select(.status == "pending") | .user' "$REQUEST_FILE" 2>/dev/null)
    
    if [ -z "$pending" ]; then
        echo "No pending requests"
        exit 0
    fi
    
    echo "Pending requests:"
    select user in $pending "Done"; do
        if [ "$user" == "Done" ]; then
            break
        fi
        
        echo "Approve or reject $user? (a/r)"
        read -r decision
        
        if [[ "$decision" =~ ^[Aa] ]]; then
    
            if [ -d "/home/users/$user" ]; then
                mv "/home/users/$user" "/home/authors/$user"
            else
                mkdir -p "/home/authors/$user"
                chown "$user:g_author" "/home/authors/$user"
            fi
            
    
            mkdir -p "/home/authors/$user/blogs" "/home/authors/$user/public"
            chown -R "$user:g_author" "/home/authors/$user"
            chmod 750 "/home/authors/$user"
            chmod 770 "/home/authors/$user/blogs"
            chmod 750 "/home/authors/$user/public"
            
           
            usermod -g g_author "$user"
            
        
            yq e "(.requests[] | select(.user == \"$user\")).status = \"approved\"" -i "$REQUEST_FILE"
            
      
            for user_dir in /home/users/*; do
                if [ -d "$user_dir/all_blogs" ]; then
                    ln -sf "/home/authors/$user/public" "$user_dir/all_blogs/$user"
                fi
            done
            
            echo "$user is now an author"
        elif [[ "$decision" =~ ^[Rr] ]]; then
      
            yq e "del(.requests[] | select(.user == \"$user\"))" -i "$REQUEST_FILE"
            echo "Request from $user rejected"
        else
            echo "Invalid choice"
        fi
    done
else
    echo "Invalid command" >&2
    exit 1
fi

exit 0
