#!/bin/bash

# Default values
OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')
OS_TYPE_FULL=""
VERSION=""
URL_BASE="https://s3-eu-west-1.amazonaws.com/apexofficeprint"
EXECUTABLE="APEXOfficePrint" # Adjust this as necessary
INCLUDE_LICENSE=0
ISLINUX=0

# must change variables.
EXECUTABLES_FOLDER="${pwd}" # folder where your executables should download.
LICENSE_PATH="" # default licnense file path for the AOP.
OTHERARGS="" # extra argument that should run (like -d or --enable_local_resource). Ex. (-d --enable_local_resource -p 8011)
PORT=8011 # default port number for AOP( you can either use -p=8010).

# Parse command-line arguments for version
for i in "$@"; do
# echo $i
case $i in
    --vd=*)
    VERSION="${i#*=}"
    shift # past argument=value
    ;;
    --license)
    INCLUDE_LICENSE=1
    ;;

    --license=*)
    INCLUDE_LICENSE=1
    LICENSE_PATH_TEMP="${i#*=}"
    if [ LICENSE_PATH_TEMP != "" ]; then
        echo "License Provided  ${LICENSE_PATH_TEMP}"
        LICENSE_PATH="${LICENSE_PATH_TEMP}"
    fi
    echo "License to use ${LICENSE_PATH}"
    shift # past argument=value
    ;;

    --exeFolder=*)
    EXECUTABLES_FOLDER="${i#*=}"
    shift # past argument=value
    ;;

    -h)
    echo "This script will help you download specific AOP version and run automatically on specied port."
    echo "You must change the value for the EXECUTABLES_FOLDER variable. As this will be the folder that will have downloaded AOP version."
    echo "The available options are: "
    echo "--vd              aop version to download and run (ex: --vd=24.1)"
    echo "-p                Port number to start AOP."
    echo "--license         whether to include license or not. Path can be set here or in the default values of the script. (Ex: --license=<PathToLicense>)"
    echo "--exeFolder       Folder to download the zip file. Path can be set here or in the default values of the script. (Ex: --exeFolder=\"<PathToDownloadZip>)\""
    echo "-h                See help"

    shift # past argument=value
    # past argument=value
    ;;

    -p=*)
    PORT="${i#*=}"
    ;;

    *)
        OTHERARGS="${OTHERARGS} ${i//=/ }"
    ;;

esac
done

echo "Executables folder ${EXECUTABLES_FOLDER}"
eval "cd \"${EXECUTABLES_FOLDER}\""

# echo "${OTHERARGS}"
# Validate version number
if [ -z "$VERSION" ]; then
    echo "Version number is required. Use --vd to specify the version."
    exit 1
fi

# Adjust OS_TYPE for folder naming

case "$OS_TYPE" in
    linux*)     
        OS_TYPE="linux"
        OS_TYPE_FULL="linux"
        EXECUTABLE="APEXOfficePrintLinux64"
        ISLINUX=1
    ;;
    mingw*)     
        OS_TYPE="win"
        OS_TYPE_FULL="windows"
        EXECUTABLE="APEXOfficePrintWin64.exe"
    ;;
esac


FOLDER="v${VERSION}"

# Construct the URL dynamically based on OS and version
URL="${URL_BASE}/${OS_TYPE_FULL}/aop_${OS_TYPE}_${FOLDER}.zip"

# Check if folder exists
if [ ! -d "$FOLDER" ]; then
    echo "Folder does not exist. Downloading and extracting from $URL..."

    # Download the file
    curl -o archive.zip "$URL"

    # Extract the file using 7zip
    7z x archive.zip

    # Cleanup the downloaded archive if needed
    rm archive.zip

else
    echo "Folder $FOLDER exists. Skipping download."
fi

# Navigate to the certain folder if needed
# Example: CD into the folder if it's not the current working directory
cd "./${FOLDER}/server"
cd "${EXECUTABLE}" || cd "${EXECUTABLE}_4096"
# explorer .
# ls -la
# Check if we need to set executable permissions and run the executable

if [ $ISLINUX -eq 1 ]; then
    chmod u+x "$EXECUTABLE"
fi

RUN_CMD="./${EXECUTABLE} "

if [ ! -z $PORT ]; then
    RUN_CMD="${RUN_CMD} -p ${PORT}"
fi
if [ $INCLUDE_LICENSE -eq 1 ]; then
    RUN_CMD="${RUN_CMD} --license \"${LICENSE_PATH}\""
fi

if [ ! -z $OTHERARGS ]; then
    RUN_CMD="${RUN_CMD} ${OTHERARGS}"
fi

echo "Running ${RUN_CMD}"
eval $RUN_CMD
