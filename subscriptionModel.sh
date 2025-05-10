#!/bin/bash
if [ "$#" -lt 1 ]; then
    echo "Usage:"
    echo "For users: $0 subscribe <author>"
    echo "For authors: $0 publish <filename> <public|subscribers>"
    exit 1
fi

USER=$(whoami)
USER_GROUPS=$(id -nG)

if [[ "$USER_GROUPS" =~ "g_user" ]]; then
 
    if [ "$1" != "subscribe" ]; then
        echo "Users can only subscribe to authors" >&2
        exit 1
    fi
    
    if [ -z "$2" ]; then
        echo "Author name required" >&2
        exit 1
    fi
    
    AUTHOR="$2"
    SUBSCRIBE_FILE="/etc/subscriptions.yaml"
    
 
    mkdir -p "/home/users/$USER/subscribed_blogs"
    chown "$USER:g_user" "/home/users/$USER/subscribed_blogs"
    chmod 550 "/home/users/$USER/subscribed_blogs"
    
 
    if [ ! -f "$SUBSCRIBE_FILE" ]; then
        echo "subscriptions: []" > "$SUBSCRIBE_FILE"
    fi
    
 
    if yq e ".subscriptions[] | select(.user == \"$USER\" and .author == \"$AUTHOR\")" "$SUBSCRIBE_FILE" >/dev/null; then
        echo "You are already subscribed to $AUTHOR"
        exit 0
    fi
    

    yq e ".subscriptions += [{\"user\": \"$USER\", \"author\": \"$AUTHOR\"}]" -i "$SUBSCRIBE_FILE"
    
 
    if [ -d "/home/authors/$AUTHOR/blogs" ]; then
        ln -sf "/home/authors/$AUTHOR/blogs" "/home/users/$USER/subscribed_blogs/$AUTHOR"
    fi
    
    echo "Subscribed to $AUTHOR successfully"
    
elif [[ "$USER_GROUPS" =~ "g_author" ]]; then
  
    if [ "$1" != "publish" ]; then
        echo "Authors can only publish articles" >&2
        exit 1
    fi
    
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Filename and audience required" >&2
        echo "Usage: $0 publish <filename> <public|subscribers>" >&2
        exit 1
    fi
    
    FILENAME="$2"
    AUDIENCE="$3"
    BLOGS_DIR="/home/authors/$USER/blogs"
    PUBLIC_DIR="/home/authors/$USER/public"
    SUBS_DIR="/home/authors/$USER/subscribers"
    
    if [ ! -f "$BLOGS_DIR/$FILENAME" ]; then
        echo "File $FILENAME not found in your blogs directory" >&2
        exit 1
    fi
    
    if [ "$AUDIENCE" == "public" ]; then
    
        ln -sf "$BLOGS_DIR/$FILENAME" "$PUBLIC_DIR/$FILENAME"
        chmod 440 "$PUBLIC_DIR/$FILENAME"
        
    
        yq e "(.blogs[] | select(.filename == \"$FILENAME\")).audience = \"public\"" -i "/home/authors/$USER/blogs.yaml"
        
        echo "Published $FILENAME to public"
    elif [ "$AUDIENCE" == "subscribers" ]; then
        
        mkdir -p "$SUBS_DIR"
        chown "$USER:g_author" "$SUBS_DIR"
        chmod 750 "$SUBS_DIR"
        
   
        ln -sf "$BLOGS_DIR/$FILENAME" "$SUBS_DIR/$FILENAME"
        chmod 440 "$SUBS_DIR/$FILENAME"
        
  
        yq e "(.blogs[] | select(.filename == \"$FILENAME\")).audience = \"subscribers\"" -i "/home/authors/$USER/blogs.yaml"
        
 
        SUBSCRIBE_FILE="/etc/subscriptions.yaml"
        if [ -f "$SUBSCRIBE_FILE" ]; then
            subscribers=$(yq e ".subscriptions[] | select(.author == \"$USER\") | .user" "$SUBSCRIBE_FILE" 2>/dev/null)
            for sub in $subscribers; do
         
                mkdir -p "/home/users/$sub/subscribed_blogs/$USER"
                ln -sf "$SUBS_DIR/$FILENAME" "/home/users/$sub/subscribed_blogs/$USER/$FILENAME"
            done
        fi
        
        echo "Published $FILENAME to subscribers"
    else
        echo "Invalid audience. Use 'public' or 'subscribers'" >&2
        exit 1
    fi
else
    echo "This command is only for users or authors" >&2
    exit 1
fi

exit 0
