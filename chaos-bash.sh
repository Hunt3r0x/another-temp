#!/bin/bash

JSON_FILE="index.json"
JSON_URL="https://chaos-data.projectdiscovery.io/index.json"
OLD_JSON_FILE="old_index.json"
OUTPUT_DIR="output_directory"

# Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Creating output directory..."
  mkdir "$OUTPUT_DIR"
fi

download_json_file() {
  echo "Downloading JSON file: $JSON_URL"
  if curl -s "$JSON_URL" -o "$JSON_FILE"; then
    echo "Downloaded JSON file: $JSON_FILE"
  else
    echo "Failed to download JSON file."
    return 1
  fi
}

check_json_changes() {
  if [ -f "$OLD_JSON_FILE" ]; then
    current_updated=$(jq -r '.[].last_updated' "$JSON_FILE")
    old_updated=$(jq -r '.[].last_updated' "$OLD_JSON_FILE")

    if [ "$current_updated" = "$old_updated" ]; then
      echo "No changes in JSON file. Skipping download."
      return 0
    fi
  fi

  mv "$JSON_FILE" "$OLD_JSON_FILE"
}

download_and_extract_urls_from_json() {
  urls=$(jq -r '.[].URL' "$JSON_FILE")
  for url in $urls; do
    filename=$(basename "$url")
    zip_filename="${filename%.*}.zip"
    extracted_filename="${filename%.*}.txt"

    # Check if the extracted file already exists
    if [ -f "$OUTPUT_DIR/$extracted_filename" ]; then
      echo "File already exists: $extracted_filename. Skipping download and extraction."
      continue
    fi

    echo "Downloading: $filename"
    if wget -q "$url" -O "$OUTPUT_DIR/$zip_filename"; then
      echo "Downloaded: $zip_filename"
      echo "Extracting: $zip_filename"
      if unzip -qq -o "$OUTPUT_DIR/$zip_filename" "*.txt" -d "$OUTPUT_DIR"; then
        echo "Extracted: $zip_filename"
        rm "$OUTPUT_DIR/$zip_filename"
      else
        echo "Failed to extract: $zip_filename"
      fi
    else
      echo "Failed to download: $filename"
    fi
  done
}

if [ ! -f "$JSON_FILE" ]; then
  download_json_file
fi

if [ -f "$JSON_FILE" ]; then
  check_json_changes
  download_and_extract_urls_from_json
fi


