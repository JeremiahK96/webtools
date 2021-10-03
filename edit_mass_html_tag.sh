#!/bin/dash
# usage: edit_mass_html_tag [options]
#   -t = tag to edit
#   -e = file(s) to edit
#   -i = input file with desired tag to apply
tag="header"
edit="*.html"
input="index.html"
verbose=0;
while getopts t:e:i:v: flag; do # Set values from command line arguments
    case "${flag}" in
        t) tag=${OPTARG};;
        e) edit=${OPTARG};;
        i) input=${OPTARG};;
        v) verbose=${OPTARG};;
    esac
done

# Edit all files, skipping the input file
[ "$verbose" -gt 1 ] && echo "Applying <$tag> tag from $input"
tmp="edit_mass_html_tag.tmp"
for file in $edit; do
    [ "$file" != "$input" ] &&
        sed -n "1,/<$tag/ { /<$tag/b; p}" "$file" > "$tmp" &&
        sed -n "/<$tag/,/<\/$tag>/p" "$input" >> "$tmp" &&
        sed -n "/<\/$tag>/,\$ { /<\/$tag>/b; p}" "$file" >> "$tmp" &&
        mv "$tmp" "$file" &&
        [ "$verbose" -gt 0 ] && echo "Modified $file"
done
