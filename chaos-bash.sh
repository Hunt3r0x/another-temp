#!/bin/bash

output_folder="output"
url="https://chaos-data.projectdiscovery.io/"
endpoints="endpoints.txt"
programs="allprogramms"

mkdir -p "$output_folder"

for file in $(cat "$endpoints"); do
    curl -sLO "$url/$file"
done

for file in "$programs"/*.zip; do
    unzip -q "$file" -d "$programs"
    rm -f "$file"
done

cat "$programs"/*/*.txt > "$output_folder"/subdomains.txt

rm -rf "$programs"
