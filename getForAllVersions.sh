#!/bin/bash

# Versions to test, provided as comma-separated values
VERSIONS="24.1.1,24.2,24.2.2"  # Example versions, replace with actual versions
INPUT="data"
OUTPUT_DIR="out"
INITIAL_PORT=8011
GET_DIFF=true
KILL_ALL_AOP_PROCESSES=true
KILL_AOP_AFTER_PROCESSING=true
# Function to display help message
display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Process a json request to multiple versions of AOP and generate output along the difference."
    echo
    echo "Options:"
    echo "  -h, --help     Display this help message and exit"
    echo "  -v, --versions Comma-separated list of versions to process (default: $VERSIONS)"
    echo "  -i, --input    Input file or directory (default: $INPUT)"
    echo "  -o, --output   Output directory (default: $OUTPUT_DIR)"
    echo "  -p, --port     Initial port number (default: $INITIAL_PORT)"
    echo "  -d, --diff     Enable diff generation (default: $GET_DIFF)"
    echo "  -k, --kill     Kill all AOP processes after processing (default: $KILL_ALL_AOP_PROCESSES)"
    echo "  -a, --after    Kill AOP processes after processing (default: $KILL_AOP_AFTER_PROCESSING)"
    echo
    echo "Example: $0 -v 24.1.1,24.2,24.2.2 -i ./Exported.json -o out"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            display_help
            exit 0
            ;;
        -v|--versions)
            VERSIONS="$2"
            shift 2
            ;;
        -i|--input)
            INPUT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--port)
            INITIAL_PORT="$2"
            shift 2
            ;;
        -d|--diff)
            GET_DIFF="$2"
            shift 2
            ;;
        -k|--kill)
            KILL_ALL_AOP_PROCESSES="$2"
            shift 2
            ;;
        -a|--after)
            KILL_AOP_AFTER_PROCESSING="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            display_help
            exit 1
            ;;
    esac
done

# Check if help was requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    display_help
    exit 0
fi

# Convert comma-separated versions into an array
IFS=',' read -r -a VERSION_ARRAY <<< "$VERSIONS"

echo "Starting processing for versions: $VERSIONS"

# function to kill all AOP processes
KILL_ALL_AOP_PROCESSESKILL_ALL_AOP_PROCESSES_aop_processes() {
  ps -a | grep APEXOfficePrint | awk '{print $1}' | xargs kill -9
}

# kill specific version of AOP
kill_specific_aop_version() {
  local version=$1
  ps -a | grep v$version/server/APEXOfficePrint | awk '{print $1}' | xargs kill -9
}

# Function to check the server version
check_server_version() {
  local expected_version=$1
  local port=$2

  actual_version=$(curl -s "http://localhost:$port/version")
  if [ "$actual_version" == "$expected_version" ]; then
    echo "Server version check passed for version $expected_version on port $port"
    return 1
  fi
  echo "Server version check failed for version $expected_version on port $port, but got $actual_version"
  return 0
}

# Check if INPUT is a file or directory
if [ -f "$INPUT" ]; then
    INPUT_FILES=("$INPUT")
elif [ -d "$INPUT" ]; then
    if [ -z "$(ls -A "$INPUT")" ]; then
        echo "Warning: Input directory is empty. Exiting."
        exit 1
    fi
    INPUT_FILES=("$INPUT"/*)
else
    echo "Error: Input '$INPUT' is neither a file nor a directory. Exiting."
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    echo "Created output directory: $OUTPUT_DIR"
fi

# Iterate over each version
for VERSION in "${VERSION_ARRAY[@]}"; do
  echo "Processing version: $VERSION"
  
  PORT=$INITIAL_PORT
  SERVER_STARTED=false
  # Loop until the correct version is found or no response
  while true; do
    response=$(curl -s "http://localhost:$PORT/version")
    if [ -z "$response" ]; then
      echo "No response from server on port $PORT. Exiting loop."
      break
    elif [ "$response" == "$VERSION" ]; then
      echo "Server version $VERSION found on port $PORT"
      SERVER_STARTED=true
      break
    else
      echo "Incorrect version found: $response. Waiting for $VERSION"
      ((PORT++))
    fi
  done

  # If server didn't start, try to start it
  if ! $SERVER_STARTED; then
    echo "Attempting to start server for version $VERSION on port $PORT"
    drunAOP.sh --vd="$VERSION" -p=$PORT &
    echo "Waiting for server to start..."
    sleep 8
    retries=0
    while [ $retries -lt 3 ]; do
      if curl -s "http://localhost:$PORT/marco" > /dev/null; then
        echo "Server started successfully"
        SERVER_STARTED=true
        break
      else
        echo "Attempt $((retries+1)): Server not responding. Waiting 5 more seconds..."
        sleep 5
        ((retries++))
      fi
    done

    if ! $SERVER_STARTED; then
      echo "Failed to start server after 3 attempts"
    fi
  fi

  # Iterate over each input file
  for INPUT_FILE in "${INPUT_FILES[@]}"; do
    # Extract the file name without the directory path
    INPUT_FILENAME=$(basename "$INPUT_FILE")

    # Create a separate directory for each input file
    FILE_OUTPUT_DIR="$OUTPUT_DIR/${INPUT_FILENAME%.*}"
    mkdir -p "$FILE_OUTPUT_DIR"

    # Set the output file name
    OUTPUT_FILE="$FILE_OUTPUT_DIR/${INPUT_FILENAME%.*}_${VERSION}.pdf"

    echo "Processing file: $INPUT_FILENAME"
    # Send the request using curl

  # detect the filetype of below curl response and update OUTPUT_FILE accordingly.
    # Send the request using curl and save the response to a temporary file
    TEMP_FILE=$(mktemp)
    curl -X POST -H 'Content-Type: application/json' -d @"$INPUT_FILE" "http://localhost:$PORT/" > "$TEMP_FILE"

    # Detect the file type using the 'file' command
    FILE_TYPE=$(file -b --mime-type "$TEMP_FILE")

    echo "File Type: $FILE_TYPE"

    # Update the OUTPUT_FILE extension based on the detected file type
    case "$FILE_TYPE" in
        "application/pdf")
            OUTPUT_FILE="${OUTPUT_FILE%.*}.pdf"
            ;;
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
            OUTPUT_FILE="${OUTPUT_FILE%.*}.docx"
            ;;
        "application/vnd.openxmlformats-officedocument.presentationml.presentation")
            OUTPUT_FILE="${OUTPUT_FILE%.*}.pptx"
            ;;
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
            OUTPUT_FILE="${OUTPUT_FILE%.*}.xlsx"
            ;;
        *)
            OUTPUT_FILE="${OUTPUT_FILE%.*}.bin"
            ;;
    esac

    # Move the temporary file to the final output file
    mv "$TEMP_FILE" "$OUTPUT_FILE"

    echo "Output saved to: $OUTPUT_FILE (Detected file type: $FILE_TYPE)"
    
    if $KILL_AOP_AFTER_PROCESSING; then
      kill_specific_aop_version $VERSION
      echo "Killed AOP processes after processing"
    fi

    # if this is not the first version, compare the output with the previous version
    if [ "$VERSION" != "${VERSION_ARRAY[0]}" ]; then
      echo "Current version is not the first version. Comparing with previous version."
      previous_version_index=$((${#VERSION_ARRAY[@]} - 1))
      for ((i=${#VERSION_ARRAY[@]}-1; i>=0; i--)); do
        echo "Checking version at index $i: ${VERSION_ARRAY[i]}"
        if [ "${VERSION_ARRAY[i]}" = "$VERSION" ]; then
          previous_version_index=$((i-1))
          echo "Found current version. Previous version index: $previous_version_index"
          break
        fi
      done
      # if GET_DIFF and output type is pdf then only proceed 
      if [ "$GET_DIFF" = true ] && [ "$FILE_TYPE" = "application/pdf" ] && [ $previous_version_index -ge 0 ]; then
        previous_version="${VERSION_ARRAY[previous_version_index]}"
        echo "Comparing current version ($VERSION) with previous version ($previous_version)"
        echo "Running diff-pdf command..."
        diff-pdf "$OUTPUT_FILE" "$FILE_OUTPUT_DIR/${INPUT_FILENAME%.*}_${previous_version}.pdf" --output-diff="$FILE_OUTPUT_DIR/${INPUT_FILENAME%.*}_${VERSION}_vs_${previous_version}_diff.pdf"
        echo "Diff-pdf command completed. Output saved to: $FILE_OUTPUT_DIR/${INPUT_FILENAME%.*}_${VERSION}_vs_${previous_version}_diff.pdf"
      else
        echo "No previous version found for comparison."
      fi
    else
      echo "Current version is the first version. Skipping comparison."
    fi

  done  
  echo "Finished processing version: $VERSION"
done

if $KILL_ALL_AOP_PROCESSES; then
  KILL_ALL_AOP_PROCESSESKILL_ALL_AOP_PROCESSES_aop_processes
fi

echo "All versions processed."
