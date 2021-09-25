#!/bin/dash
# usage:    edit_mass_html_tag [options]
#           -t = tag to edit
#           -e = file(s) to edit
#           -i = input file with desired tag to apply
tag="header"
edit="*.html"
input="index.html"
while getopts t:e:i: flag   # Set values from command line arguments
do
    case "${flag}" in
        t) tag=${OPTARG};;
        e) edit=${OPTARG};;
        i) input=${OPTARG};;
    esac
done

# Get tag to apply from input file, and save it to a temporary file
sed -n "1,/<$tag>/!{ /<\/$tag>/,/<$tag>/!p; }" "$input" > tag_to_apply.tmp

# Edit all files, skipping the input file
for file in $edit
do
    [ "$file" != "$input" ] &&
        sed -i "1,/<$tag>/!{ /<\/$tag>/,/<$tag>/!d; }" "$file" &&
        sed -i "/<$tag>/r tag_to_apply.tmp" "$file";
done
rm tag_to_apply.tmp
