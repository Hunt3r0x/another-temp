#!/bin/bash

JSON_FILE="index.json"
JSON_URL="https://chaos-data.projectdiscovery.io/index.json"
OUTPUT_DIR="output"
TMP_DIR="$OUTPUT_DIR/.tmp"
TMP_SUBDOMAINS_FILE="$TMP_DIR/tmp-subdomains.txt"
SUBDOMAINS_FILE="$OUTPUT_DIR/subdomains.txt"
PREVIOUS_JSON_FILE="$OUTPUT_DIR/previous_index.json"

sleep_duration=1000  # Default sleep duration in seconds

# Function to check if directories exist and create them if needed
check_directories() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo -e "\e[32mCreating directory: $OUTPUT_DIR\e[0m"
        mkdir "$OUTPUT_DIR"
    fi
    
    if [ ! -d "$TMP_DIR" ]; then
        echo -e "\e[32mCreating directory: $TMP_DIR\e[0m"
        mkdir "$TMP_DIR"
    else
        rm -rf "$TMP_DIR"/*
    fi
}

# Function to display script usage information
show_usage() {
    echo "Usage: $0 -s <sleep_duration>"
    echo "Options:"
    echo "  -s    Sleep duration in seconds (default: 300)"
}

# Function to log error messages
log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Process command-line arguments
while getopts "s:" opt; do
    case "$opt" in
        s)
            sleep_duration="$OPTARG"
        ;;
        \?)
            log_error "Invalid option: -$OPTARG"
            show_usage
            exit 1
        ;;
        :)
            log_error "Option -$OPTARG requires an argument."
            show_usage
            exit 1
        ;;
    esac
done

# Check and create directories before starting the loop
check_directories

while true; do
    # Download the latest index.json file
    check_json_file() {
        echo -e "\e[36mDownloading: $JSON_URL\e[0m"
        if curl -s "$JSON_URL" -o "$JSON_FILE"; then
            echo -e "\e[32mDownloaded JSON file: $JSON_FILE\e[0m"
        else
            log_error "Failed to download JSON file."
            return 1
        fi
    }
    
    check_json_file
    
    download_and_extract_urls_from_json() {
        while IFS= read -r url; do
            filename=$(basename "$url")
            zip_filename="${filename%.*}.zip"
            extracted_filename="${filename%.*}.txt"
            
            # Check if the extracted file already exists
            if [ -f "$TMP_DIR/$extracted_filename" ]; then
                echo -e "\e[33mFile already exists: $extracted_filename. Skipping download and extraction.\e[0m"
                continue
            fi
            
            echo -e "\e[36mDownloading: $filename\e[0m"
            if wget -q "$url" -O "$TMP_DIR/$zip_filename"; then
                echo -e "\e[32mDownloaded: $zip_filename\e[0m"
                echo -e "\e[36mExtracting: $zip_filename\e[0m"
                if unzip -qq -o "$TMP_DIR/$zip_filename" "*.txt" -d "$TMP_DIR"; then
                    echo -e "\e[32mExtracted: $zip_filename\e[0m"
                    rm "$TMP_DIR/$zip_filename"
                    unzip -p "$TMP_DIR/$extracted_filename" >> "$TMP_SUBDOMAINS_FILE"
                else
                    log_error "Failed to extract: $zip_filename"
                fi
            else
                log_error "Failed to download: $filename"
            fi
        done < <(cat "$JSON_FILE" | jq -r '.[].URL')
        
        # Check if the $SUBDOMAINS_FILE exists and has a non-zero size
        if [ -s "$SUBDOMAINS_FILE" ]; then
            # If it does, do nothing
            :
        else
            # If it doesn't, sort and remove duplicates from $TMP_SUBDOMAINS_FILE
            sort -u "$TMP_SUBDOMAINS_FILE" > "$SUBDOMAINS_FILE"
        fi
        
        if [ -s "$TMP_SUBDOMAINS_FILE" ]; then
            cat "$TMP_SUBDOMAINS_FILE" | anew "$SUBDOMAINS_FILE" | httpx -silent -l "$OUTPUT_DIR/uniquesubdomains.txt" > /dev/null 2>&1
            nuclei -t ~/nuclei-templates/ -l "$OUTPUT_DIR/uniquesubdomains.txt" -o "$OUTPUT_DIR/nuclei-output.txt"
        else
            echo -e "\e[33mNo new subdomains found\e[0m"
        fi
    }
    
    check_directories
    
    # Compare current and previous JSON files
    if cmp -s "$JSON_FILE" "$PREVIOUS_JSON_FILE"; then
        echo -e "\e[33mNo changes in the JSON file. Skipping the loop iteration.\e[0m"
    else
        echo -e "\e[32mChanges detected in the JSON file. Running the loop iteration.\e[0m"
        
        # Backup current JSON file as the previous version
        cp "$JSON_FILE" "$PREVIOUS_JSON_FILE"
        
        download_and_extract_urls_from_json
        
        echo -e "\e[36mCleaning up...\e[0m"
        rm -rf "$TMP_DIR"
    fi
    
    sleep "$sleep_duration"  # Use the sleep duration specified by the user
done
