#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_users.yaml>" >&2
    exit 1
fi

YAML_FILE="$1"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: YAML file not found" >&2
    exit 1
fi


for group in g_user g_author g_mod g_admin; do
    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
    fi
done


admins=$(yq e '.admins[]' "$YAML_FILE" 2>/dev/null)
for admin in $admins; do
    if ! id "$admin" &>/dev/null; then
        useradd -m -d "/home/admin/$admin" -G g_admin "$admin"
    else
        usermod -a -G g_admin "$admin"
        mkdir -p "/home/admin/$admin"
        chown -R "$admin:g_admin" "/home/admin/$admin"
    fi
    chmod 750 "/home/admin/$admin"
done


users=$(yq e '.users[]' "$YAML_FILE" 2>/dev/null)
for user in $users; do
    if ! id "$user" &>/dev/null; then
        useradd -m -d "/home/users/$user" -G g_user "$user"
    else
        usermod -a -G g_user "$user"
        mkdir -p "/home/users/$user"
        chown -R "$user:g_user" "/home/users/$user"
    fi
    chmod 750 "/home/users/$user"
    
    
    mkdir -p "/home/users/$user/all_blogs"
    chown "$user:g_user" "/home/users/$user/all_blogs"
    chmod 550 "/home/users/$user/all_blogs"
done


authors=$(yq e '.authors[]' "$YAML_FILE" 2>/dev/null)
for author in $authors; do
    if ! id "$author" &>/dev/null; then
        useradd -m -d "/home/authors/$author" -G g_author "$author"
    else
        usermod -a -G g_author "$author"
        mkdir -p "/home/authors/$author"
        chown -R "$author:g_author" "/home/authors/$author"
    fi
    
  
    mkdir -p "/home/authors/$author/blogs" "/home/authors/$author/public"
    chown -R "$author:g_author" "/home/authors/$author"
    chmod 750 "/home/authors/$author"
    chmod 770 "/home/authors/$author/blogs"
    chmod 750 "/home/authors/$author/public"
    
   
    for user in $users; do
        if [ -d "/home/users/$user/all_blogs" ]; then
            ln -sf "/home/authors/$author/public" "/home/users/$user/all_blogs/$author"
        fi
    done
done


mods=$(yq e '.moderators[].name' "$YAML_FILE" 2>/dev/null)
for mod in $mods; do
    if ! id "$mod" &>/dev/null; then
        useradd -m -d "/home/mods/$mod" -G g_mod "$mod"
    else
        usermod -a -G g_mod "$mod"
        mkdir -p "/home/mods/$mod"
        chown -R "$mod:g_mod" "/home/mods/$mod"
    fi
    chmod 750 "/home/mods/$mod"
    
    
    assigned_authors=$(yq e ".moderators[] | select(.name == \"$mod\") | .assigned_authors[]" "$YAML_FILE" 2>/dev/null)
    
    
    rm -f "/home/mods/$mod/"*
    
    
    for author in $assigned_authors; do
        if [ -d "/home/authors/$author/public" ]; then
            ln -sf "/home/authors/$author/public" "/home/mods/$mod/$author"
        fi
    done
done


setfacl -R -m g:g_admin:rwx /home/users /home/authors /home/mods /home/admin

echo "User initialization completed successfully"
exit 0
