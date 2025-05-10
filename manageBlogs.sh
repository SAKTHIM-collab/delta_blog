#!/bin/bash

if [ ! "$(id -nG)" =~ "g_author" ]; then
    echo "This command is only for authors" >&2
    exit 1
fi

AUTHOR=$(whoami)
BLOGS_DIR="/home/authors/$AUTHOR/blogs"
PUBLIC_DIR="/home/authors/$AUTHOR/public"
YAML_FILE="/home/authors/$AUTHOR/blogs.yaml"


if [ ! -f "$YAML_FILE" ]; then
    echo "blogs: []" > "$YAML_FILE"
    chown "$AUTHOR:g_author" "$YAML_FILE"
    chmod 640 "$YAML_FILE"
fi

function get_categories {
    echo "Available categories:"
    echo "1. Technology"
    echo "2. Cinema"
    echo "3. Sports"
    echo "4. Food"
    echo "5. Travel"
    echo "Enter category preferences (e.g., 2,1 for Cinema and Technology):"
    read -r categories
    echo "$categories"
}

function publish_article {
    local filename=$1
    local categories=$(get_categories)
    

    yq e ".blogs += [{\"filename\": \"$filename\", \"publish_status\": true, \"categories\": \"$categories\"}]" -i "$YAML_FILE"
    
    ln -sf "$BLOGS_DIR/$filename" "$PUBLIC_DIR/$filename"
    
   
    chmod 440 "$PUBLIC_DIR/$filename"
    
    echo "Article $filename published successfully"
}

function archive_article {
    local filename=$1
    
   
    yq e "(.blogs[] | select(.filename == \"$filename\")).publish_status = false" -i "$YAML_FILE"
    
  
    rm -f "$PUBLIC_DIR/$filename"
    
    echo "Article $filename archived successfully"
}

function delete_article {
    local filename=$1
    
 
    yq e "del(.blogs[] | select(.filename == \"$filename\"))" -i "$YAML_FILE"
    
 
    rm -f "$BLOGS_DIR/$filename" "$PUBLIC_DIR/$filename"
    
    echo "Article $filename deleted successfully"
}

function edit_article {
    local filename=$1
    
 
    if ! yq e ".blogs[] | select(.filename == \"$filename\")" "$YAML_FILE" >/dev/null; then
        echo "Article $filename not found" >&2
        return 1
    fi
    
    local categories=$(get_categories)
    
 
    yq e "(.blogs[] | select(.filename == \"$filename\")).categories = \"$categories\"" -i "$YAML_FILE"
    
    echo "Article $filename categories updated successfully"
}


case "$1" in
    -p)
        if [ -z "$2" ]; then
            echo "Filename required" >&2
            exit 1
        fi
        if [ ! -f "$BLOGS_DIR/$2" ]; then
            echo "File $2 not found in blogs directory" >&2
            exit 1
        fi
        publish_article "$2"
        ;;
    -a)
        if [ -z "$2" ]; then
            echo "Filename required" >&2
            exit 1
        fi
        archive_article "$2"
        ;;
    -d)
        if [ -z "$2" ]; then
            echo "Filename required" >&2
            exit 1
        fi
        delete_article "$2"
        ;;
    -e)
        if [ -z "$2" ]; then
            echo "Filename required" >&2
            exit 1
        fi
        edit_article "$2"
        ;;
    *)
        echo "Usage: $0 [-p|-a|-d|-e] <filename>" >&2
        exit 1
        ;;
esac

exit 0
