#!/bin/bash
if [ ! "$(id -nG)" =~ "g_admin" ]; then
    echo "This command is only for admin" >&2
    exit 1
fi

USER_PREF="/etc/userpref.yaml"
if [ ! -f "$USER_PREF" ]; then
    echo "Error: userpref.yaml not found in /etc" >&2
    exit 1
fi

BLOGS=()
while IFS= read -r line; do
    author=$(dirname "$line" | xargs basename)
    blog=$(basename "$line")
    BLOGS+=("$author:$blog")
done < <(find /home/authors -type f -path "*/public/*" | sed 's|/home/authors/||')


USERS=$(yq e '.users[]' /etc/users.yaml 2>/dev/null)


for user in $USERS; do
    FY_FILE="/home/users/$user/FYI.yaml"
    echo "blogs: []" > "$FY_FILE"
    chown "$user:g_user" "$FY_FILE"
    chmod 440 "$FY_FILE"
done


for blog in "${BLOGS[@]}"; do
    author=${blog%:*}
    blog_name=${blog#*:}
    

    AUTHOR_YAML="/home/authors/$author/blogs.yaml"
    if [ ! -f "$AUTHOR_YAML" ]; then
        continue
    fi
    
    categories=$(yq e ".blogs[] | select(.filename == \"$blog_name\") | .categories" "$AUTHOR_YAML" 2>/dev/null)
    if [ -z "$categories" ]; then
        continue
    fi
    

    IFS=',' read -ra blog_cats <<< "$categories"
    

    best_users=()
    best_score=0
    
    for user in $USERS; do
 
        prefs=$(yq e ".users[] | select(.name == \"$user\") | .preferences[]" "$USER_PREF" 2>/dev/null)
        if [ -z "$prefs" ]; then
            continue
        fi
        
   
        score=0
        for pref in $prefs; do
            for cat in "${blog_cats[@]}"; do
                if [ "$pref" == "$cat" ]; then
                    score=$((score + 1))
                fi
            done
        done
        
   
        if [ "$score" -gt "$best_score" ]; then
            best_score=$score
            best_users=("$user")
        elif [ "$score" -eq "$best_score" ]; then
            best_users+=("$user")
        fi
    done
    
 
    assigned=0
    for user in "${best_users[@]}"; do
        FY_FILE="/home/users/$user/FYI.yaml"
        current_count=$(yq e '.blogs | length' "$FY_FILE" 2>/dev/null)
        
        if [ "$current_count" -lt 3 ]; then
            yq e ".blogs += [{\"author\": \"$author\", \"blog\": \"$blog_name\"}]" -i "$FY_FILE"
            assigned=$((assigned + 1))
            
   
            if [ "$assigned" -ge $(( ${#USERS[@]} / ${#BLOGS[@]} + 1 )) ]; then
                break
            fi
        fi
    done
    
 
    if [ "$assigned" -eq 0 ]; then
      
        min_blogs=3
        for user in $USERS; do
            FY_FILE="/home/users/$user/FYI.yaml"
            current_count=$(yq e '.blogs | length' "$FY_FILE" 2>/dev/null)
            if [ "$current_count" -lt "$min_blogs" ]; then
                min_blogs=$current_count
            fi
        done
        
    
        for user in $USERS; do
            FY_FILE="/home/users/$user/FYI.yaml"
            current_count=$(yq e '.blogs | length' "$FY_FILE" 2>/dev/null)
            
            if [ "$current_count" -eq "$min_blogs" ] && [ "$current_count" -lt 3 ]; then
                yq e ".blogs += [{\"author\": \"$author\", \"blog\": \"$blog_name\"}]" -i "$FY_FILE"
                assigned=$((assigned + 1))
                
           
                if [ "$assigned" -ge $(( ${#USERS[@]} / ${#BLOGS[@]} + 1 )) ]; then
                    break
                fi
            fi
        done
    fi
done

echo "FY pages updated successfully"
exit 0
