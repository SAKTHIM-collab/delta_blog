#!/bin/bash
if ! id -nG | grep -qw "g_admin"; then
    echo "This command is only for admin" >&2
    exit 1
fi

REPORT_FILE="/home/admin/$(whoami)/blog_report_$(date +%Y%m%d).txt"


echo "Blog Activity Report - $(date)" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"


declare -A published
declare -A deleted
declare -A read_count


for author_dir in /home/authors/*; do
    author=$(basename "$author_dir")
    yaml_file="$author_dir/blogs.yaml"
    
    if [ ! -f "$yaml_file" ]; then
        continue
    fi
    

    blogs=$(yq e '.blogs[]' "$yaml_file" 2>/dev/null)
    
    while IFS= read -r blog; do
        filename=$(echo "$blog" | yq e '.filename' -)
        status=$(echo "$blog" | yq e '.publish_status' -)
        categories=$(echo "$blog" | yq e '.categories' -)
        
  
        IFS=',' read -ra cats <<< "$categories"
        
   
        read_count["$author:$filename"]=$(stat -c %X "$author_dir/blogs/$filename" 2>/dev/null || echo 0)
        
        if [ "$status" == "true" ]; then
            for cat in "${cats[@]}"; do
                published[$cat]=$((published[$cat] + 1))
            done
        else
         
            if [ ! -f "$author_dir/blogs/$filename" ]; then
                for cat in "${cats[@]}"; do
                    deleted[$cat]=$((deleted[$cat] + 1))
                done
            fi
        fi
    done <<< "$blogs"
done


echo -e "\nCategory Statistics:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
for cat in "${!published[@]}"; do
    echo "$cat: Published=${published[$cat]}, Deleted=${deleted[$cat]}" >> "$REPORT_FILE"
done


echo -e "\nTop 3 Most Read Articles:" >> "$REPORT_FILE"
echo "--" >> "$REPORT_FILE"
for blog in "${!read_count[@]}"; do
    echo "${read_count[$blog]} $blog"
done | sort -nr | head -3 | while read count blog; do
    author=${blog%:*}
    filename=${blog#*:}
    echo "$filename by $author - Read $count times" >> "$REPORT_FILE"
done

echo -e "\nReport generated at $(date)" >> "$REPORT_FILE"
echo "Report saved to $REPORT_FILE"


CRON_EXPR="14 15 1-7,25-31 * 2,5,8,11 [ $(date +\%d) -le 7 ] && [ $(date +\%w) -eq 4 ] || [ $(date +\%w) -eq 6 ] && [ $(date +\%d) -ge 25 ]"

echo -e "\nTo set up automatic reporting, add this cron job as root:"
echo "$CRON_EXPR root /scripts/adminPanel"

exit 0
