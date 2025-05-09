
if [ ! "$(id -nG)" =~ "g_mod" ]; then
    echo "This command is only for moderators" >&2
    exit 1
fi

MOD=$(whoami)
BLACKLIST="/home/mods/$MOD/blacklist.txt"


if [ ! -f "$BLACKLIST" ]; then
    echo "Creating blacklist.txt in your home directory"
    echo -e "badword1\nbadword2\ninappropriate" > "$BLACKLIST"
    chmod 600 "$BLACKLIST"
    echo "Please edit blacklist.txt with words to censor and run again"
    exit 0
fi


YAML_FILE="/etc/users.yaml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: users.yaml not found in /etc" >&2
    exit 1
fi

ASSIGNED_AUTHORS=$(yq e ".moderators[] | select(.name == \"$MOD\") | .assigned_authors[]" "$YAML_FILE" 2>/dev/null)

for author in $ASSIGNED_AUTHORS; do
    PUBLIC_DIR="/home/authors/$author/public"
    if [ ! -d "$PUBLIC_DIR" ]; then
        continue
    fi
    
    for article in "$PUBLIC_DIR"/*; do
        if [ ! -f "$article" ]; then
            continue
        fi
        
        article_name=$(basename "$article")
        temp_file=$(mktemp)
        blacklist_count=0
        
        
        line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            original_line="$line"
            
            
            while IFS= read -r word; do
                if [ -z "$word" ]; then
                    continue
                fi
                
           
                replaced_line=$(echo "$line" | sed -E "s/\b${word}\b/$(printf '*%.0s' $(seq 1 ${#word}))/gi")
                
           
                matches=$(echo "$line" | grep -io "\b${word}\b" | wc -l)
                if [ "$matches" -gt 0 ]; then
                    blacklist_count=$((blacklist_count + matches))
                    for ((i=0; i<matches; i++)); do
                        echo "Found blacklisted word $word in $article_name at line $line_num"
                    done
                fi
                
                line="$replaced_line"
            done < "$BLACKLIST"
            
            echo "$line" >> "$temp_file"
        done < "$article"
        
        if [ "$blacklist_count" -gt 0 ]; then
            mv "$temp_file" "$article"
            chmod 440 "$article"
        else
            rm -f "$temp_file"
        fi
        
    
        if [ "$blacklist_count" -gt 5 ]; then
            echo "Blog $article_name is archived due to excessive blacklisted words"
            
       
            sudo -u "$author" /scripts/manageBlogs -a "$article_name"
            
       
            AUTHOR_YAML="/home/authors/$author/blogs.yaml"
            if [ -f "$AUTHOR_YAML" ]; then
                temp_yaml=$(mktemp)
                yq e "(.blogs[] | select(.filename == \"$article_name\")).mod_comments = \"found $blacklist_count blacklisted words\"" "$AUTHOR_YAML" > "$temp_yaml"
                chown "$author:g_author" "$temp_yaml"
                chmod 640 "$temp_yaml"
                mv "$temp_yaml" "$AUTHOR_YAML"
            fi
        fi
    done
done

exit 0
