#!/bin/bash

output_folder="output"
url="https://chaos-data.projectdiscovery.io/"
endpoints="endpoints.txt" # must be updated every run
programs="programs"

mkdir -p "$output_folder"
mkdir -p "$programs"

for file in $(cat "$endpoints"); do
    curl -sLO "$url/$file"
done

for file in *.zip; do
    unzip -q "$file" -d "$programs"
    rm "$file"
done

cat "$programs"/*/*.txt > "$output_folder"/subdomains.txt

rm -rf "$programs"
