#!/bin/dash
[ -z "$EDITOR" ] && EDITOR="vim"

timestamp=$(date +%s)
publish_date=$(date -d "@$timestamp" "+%b\/%d\/%Y")
month_year=$(date -d "@$timestamp" "+%B %Y")
month_day=$(date -d "@$timestamp" "+%b %d")

post_prefix="blog-"
tag_prefix="blogtag-"
page_title_prefix="Jeremiah Knol - "
commit_msg="See this post's relevant git commit."

draft_dir="drafts/"
published_dir="published/"
post_list="$published_dir"posts
title_list="$published_dir"titles
tag_list="$published_dir"tags

post_index="blog.html"
title_index="blogtitles.html"
tag_index="blogtags.html"

usage="blog.sh [option]\nn = new draft\nv = view drafts\ne = edit draft\nd = delete draft\np = publish draft"
[ "$#" -ne 1 ] && echo "You must provide exactly 1 argument\n$usage" >&2 && return 1
[ "$1" = "h" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] && echo "$usage" && return 0

# Blog init, make sure all required directories and files exist (post/title/tag index pages must be created manually)
mkdir -p "$draft_dir" "$published_dir"
[ ! -f "$post_list" ]   && touch "$post_list"
[ ! -f "$title_list" ]  && touch "$title_list"
[ ! -f "$tag_list" ]    && touch "$tag_list"

# New blog draft
[ "$1" = "n" ] && draft="$draft_dir$timestamp" && echo "create=$timestamp\ntitle=\ntags=\ncommit=\npost=" > "$draft"

task=""; [ "$1" = "e" ] && task="edit"; [ "$1" = "p" ] && task="publish"; [ "$1" = "d" ] && task="delete"
if [ -n "$task" ] || [ "$1" = "v" ]; then
    [ ! "$(ls -A drafts)" ] && echo "No drafts" >&2 && return 2

    # Enumerate drafts, showing date/time created and title
    echo "#    date    time   title"
    i=0; for draft in "$draft_dir"*; do
        i=$((i + 1));
        dtime="${draft#$draft_dir}" && date_time=$(date -d "@$dtime" "+%D %R")
        title=$(grep -m 1 ^title= "$draft") && title="${title#title=}"
        echo "$i  $date_time  $title"
    done; num_drafts="$i"; [ "$1" = "v" ] && return 0

    # Ask user which draft to operate on (blank input = cancel)
    choice=0; while [ "$choice" -lt 1 ] || [ "$choice" -gt "$num_drafts" ]; do
        read -r -p "Enter draft number to $task : " input; [ -z "$input" ] && return 0
        [ "$input" -eq "$input" ] 2>/dev/null && choice="$input"
    done

    # Get nth draft's filename and save to $draft
    i=0; for draft in "$draft_dir"*; do
        i=$((i + 1)) && [ "$i" = "$choice" ] && break;
    done
fi

# Edit or delete draft
[ "$1" = "e" ] || [ "$1" = "n" ] && "$EDITOR" "$draft" && return 0
[ "$1" = "d" ] && rm "$draft" && return 0

# Catch all unknown arguments
[ "$1" != "p" ] && echo "Unknown argument '$1'\n$usage" >&2 && return 99

# Publish draft
post=$(sed 1,/^post=/d "$draft")
tags=$(grep -m 1 ^tags= "$draft")       && tags="${tags#tags=}"
title=$(grep -m 1 ^title= "$draft")     && title="${title#title=}"
create=$(grep -m 1 ^create= "$draft")   && create="${create#create=}"
commit=$(grep -m 1 ^commit= "$draft")   && commit="${commit#commit=}"

[ -z "$title" ] || [ -z "$post" ] && echo "Draft title and post cannot be empty" >&2 && return 3

safe_title=$(echo "$title" | sed "y/ /-/; s/+/-plus/g" | tr 'A-Z' 'a-z' | tr -d -c 'A-Za-z0-9''-_')
link_prefix="$post_prefix$safe_title"
title_line_num=$(sed -n "/^$title\s\+[0-9]\+\$/ {=; q}" "$title_list")
page_title="$page_title_prefix$title"

# If this is a new title...else
[ -z "$title_line_num" ] &&
    title_count=0 && new_count=1 && page_link="$link_prefix-1.html" && series_link="$page_link" &&
    echo "$title $new_count" >> "$title_list" && sort -f -o "$title_list" "$title_list"
[ -n "$title_line_num" ] &&
    title_line=$(sed -n "$title_line_num"p "$title_list") &&
    title_count="${title_line##* }" && new_count=$((title_count + 1)) &&
    page_link="$link_prefix-$new_count.html" && series_link="$title_index#$safe_title" &&

    # Fix Part 1's page title, title, and listings on indexes
    sed -i "s/<title>$page_title<\/title>/<title>$page_title--Part 1<\/title>/" "$link_prefix-1.html" &&
    sed -i "s/<a href=\"$link_prefix-1.html\">$title<\/a>/<a href=\"$series_link\">$title<\/a> <span>Part 1<\/span>/" "$link_prefix-1.html" &&
    sed -i -s "s/<a href=\"$link_prefix-1.html\">$title<\/a>/<a href=\"$link_prefix-1.html\">$title <span>Part 1<\/span><\/a>/" "$post_index" "$tag_index" "$tag_prefix"* &&

    page_title="$page_title--Part $new_count" &&
    sed -i -e "$title_line_num"a"$title $new_count" -e "$title_line_num"d "$title_list"

# Copy homepage to new page, using <main> content from blog_template.html, and set the <title>
cp index.html "$page_link"; ../edit_mass_html_tag.sh -t main -e "$page_link" -i blog_template.html
sed -i "s/<title>.*<\/title>/<title>$page_title<\/title>/" "$page_link"

# Add nav links between new and previous (possibly unrelated) posts
prev_post=$(sed -n '$p' "$post_list"); [ "$prev_post" ] &&
    sed -i "s/<!--prevpost-->/<a href=\"$prev_post\">\&lt;\&lt;<\/a>/" "$page_link" &&
    sed -i "s/<!--nextpost-->/<a href=\"$page_link\">\&gt;\&gt;<\/a>/" "$prev_post"
echo "$page_link" >> "$post_list"

# Add nav links between new and previous posts in the same series
prev_part=""; title_span=""; [ "$title_count" -ne 0 ] &&
    prev_part="$link_prefix-$title_count.html" && title_span="<span> Part $new_count<\/span>" &&
    sed -i "s/<!--prevpart-->/<a href=\"$prev_part\">\&lt;\&lt; Part $title_count<\/a>/" "$page_link" &&
    sed -i "s/<!--nextpart-->/<a href=\"$page_link\">Part $new_count \&gt;\&gt;<\/a>/" "$prev_part"

# Add title heading, date heading, post, and commit
sed -i "s/<!--title-->/<h1><a href=\"$series_link\">$title<\/a>$title_span<\/h1>\n<h3>$publish_date<\/h3>/" "$page_link"
echo "$post" > newpost; sed -i -e "/<!--post-->/r newpost" -e "/<!--post-->/d" "$page_link"; rm newpost
[ -n "$commit" ] && sed -i "s~<!--commit-->~<p><a class=\"commit\" href=\"$commit\" target=\"_blank\">$commit_msg<\/a><\/p>~" "$page_link"

# Add tags, linking each to its page, add each tag to tag list alphabetically
num_tags=$(echo "$tags" | tr -cd ',' | wc -c); num_tags=$((num_tags + 1))
i=1; tag=$(echo "$tags" | cut -d ',' "-f$i")
while [ -n "$tags" ] && [ ! "$i" -gt "$num_tags" ]; do
    tag_link=$(echo "$tag_prefix$tag.html" | sed "y/ /-/; s/+/-plus/g" | tr 'A-Z' 'a-z' | tr -d -c 'A-Za-z0-9''-_')
    sed -i "/<!--tags-->/i\ \ \ \ <li><a href=\"$tag_link\">$tag<\/a><\/li>" "$page_link"
    if [ -z "$(grep -x "$tag" "$tag_list")" ]; then
        echo "$tag" >> "$tag_list" && sort -f -o "$tag_list" "$tag_list"
        tag_line_num=$(sed -n "/^$tag\$/ {=; q}" "$tag_list"); tag_line_num=$((tag_line_num - 1))
        [ "$tag_line_num" = "0" ] && sed -i "/<!--tags-->/a<li><a href=\"$tag_link\">$tag<\/a><\/li>" "$tag_index"
        [ "$tag_line_num" != "0" ] &&
            prev_tag=$(sed -n "$tag_line_num {p; q}" "$tag_list") &&
            prev_tag_link=$(echo "$tag_prefix$prev_tag.html" | sed "y/ /-/") &&
            sed -i "/<a href=\"$prev_tag_link\">$prev_tag<\/a>/a<li><a href=\"$tag_link\">$tag<\/a><\/li>" "$tag_index"

        # Create new page for tag
        cp index.html "$tag_link"; ../edit_mass_html_tag.sh -t main -e "$tag_link" -i tag_template.html
        sed -i "s/<!--title-->/<h1>$tag<\/h1>/" "$tag_link"
    fi

    # Add link to new post to top of tag page
    sed -i "/<!--links-->/a<li>$publish_date <a href=\"$page_link\">$title$title_span<\/a><\/li>" "$tag_link"
    i=$((i+1)); tag=$(echo "$tags" | cut -d ',' "-f$i")
done; sed -i "/<!--tags-->/d" "$page_link";

# Update blog index by post, add current month heading if needed and add link to new post below month heading
month_labeled=$(grep -c "<h3>$month_year<\/h3>" "$post_index")
[ "$month_labeled" -eq 0 ] && sed -i "/<!--posts-->/a\ \ \ \ <h3>$month_year</h3>" "$post_index"
sed -i "/<h3>$month_year<\/h3>/a<li>$month_day <a href=\"$page_link\">$title$title_span<\/a><\/li>" "$post_index"

# Update blog index by series
series_list=$(sed "/\s\+1\$/d" "$title_list")
if [ "$new_count" -eq 2 ]; then
    series_line_num=$(echo "$series_list" | sed -n "/^$title\s\+[0-9]\+\$/ {=; q}")
    num_series=$(echo "$series_list" | wc -l)

    # Add new heading for title (alphabetically) with link to Part 1 if this is Part 2
    [ "$series_line_num" = "$num_series" ] && sed -i "/<!--posts-->/i\ \ \ \ <a id=\"$safe_title\"><h3>$title<\/h3><\/a>\\n<li>$month_day <a href=\"$link_prefix-1.html\">$title<span> Part 1<\/span><\/a><\/li>" "$title_index"
    [ "$series_line_num" != "$num_series" ] &&
        next_series=$(echo "$series_list" | sed -n "$(($series_line_num + 1))p" | sed "s/\s\+[0-9]\+\$//") &&
        sed -i "/>$next_series<\/h3>/i\ \ \ \ <a id=\"$safe_title\"><h3>$title<\/h3><\/a>\\n<li>$month_day <a href=\"$link_prefix-1.html\">$title<span> Part 1<\/span><\/a><\/li>" "$title_index"
fi
[ "$new_count" -gt 1 ] &&   # Add link to this new part below the last part
    sed -i "/$title<span> Part $title_count<\/span>/a<li>$month_day <a href=\"$page_link\">$title<span> Part $new_count<\/span><\/a><\/li>" "$title_index"

# Add timestamp and move draft to published posts
sed -i "/^create=/a publish=$timestamp" "$draft"
mv "$draft" "$published_dir"
