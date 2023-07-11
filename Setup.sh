#!/bin/bash



# some linux dist dont have :
 # - curl 
 # - ping
 # - python 
 # - unzip




# Configuration file provided by security engineer
config_file=$(find / -type f -name configfile.txt 2>/dev/null)

# Global variables

main_folder="/tools"         # the main folder 
node_version="14"          # node version installed 
UPDATE="true"              # to update the host 
DEBUG="false"              # debug system information
cd "$main_folder"

# Function to display section headers
section_header() {
  echo "================================================"
  echo "$1"
  echo "================================================"
}

# Function to display tool installation success message
tool_installed() {
  echo "Tool: $1"
  echo "Status: Installed"
  echo "----------------------------------------------"
}

# Function to display tool installation failure message
tool_installation_failed() {
  echo "Tool: $1"
  echo "Status: Installation Failed"
  echo "----------------------------------------------"
}




# getting the right  verion of node and npm 

installingnode() {
  if [[ "$node_version" = latest ]]
  then
    nvm install node # this will install the latest 
    nvm use node
  else
    nvm install $node_version
    nvm use $node_version
  fi
}


# Function to install tool using APT
install_with_apt() {
  toolname=$1
  version=$2
  echo "$toolname not found, installing with APT"
  apt install -y $toolname
  if [ $? -eq 0 ]; then
    tool_installed $toolname
    $toolname $version
  else
    tool_installation_failed $toolname
    exit 1
  fi
}

# Function to install tool from URL
install_from_url() {
  toolname=$1
  version=$2
  url=$3
  extension=$4
  echo "$toolname not found, installing from URL"
  mkdir $toolname && cd $toolname
  if [[ "$extension" == "TAR"  ]]  # TAR 
  then
    curl -L -o file.tar.gz $url && tar -xzf file.tar.gz && rm file.tar.gz
    if [ $? -eq 0 ]; then
      path=$(find / -type f -name "$toolname")
      echo 'export PATH=$PATH:'"$(echo "$path" | xargs -I {} dirname {})" >> ~/.bashrc && source ~/.bashrc  # setup for later use in jenkins
      chmod +x "$path"
      $toolname $version
      tool_installed $toolname
    else
      tool_installation_failed $toolname
      exit 1
    fi
  elif [[ "$extension" == "ZIP" ]] # ZIP
  then
    curl -L -o file.zip $url && unzip file.zip && rm file.zip
    if [ $? -eq 0 ]; then
      path=$(find / -type f -name "$toolname")
      echo 'export PATH=$PATH:'"$(echo "$path" | xargs -I {} dirname {})" >> ~/.bashrc && source ~/.bashrc  # setup for later use in jenkins
      chmod +x "$path"
      $toolname $version
      tool_installed $toolname
    else
     tool_installation_failed $toolname
     exit 1
    fi
  else
    eval $url
    if [ $? -eq 0 ]; then
      $toolname $version
    else
      tool_installation_failed $toolname
      exit 1
    fi
  fi

  #if [ $? -eq 0 ]; then
  #  path=$(find . -type f -name "$toolname")
  #  echo "export PATH=$PATH:$(echo $path | xargs -I {} dirname {} )"  >> ~/.bashrc && source ~/.bashrc  # setup for later use in jenkins
  #  chmod +x "$path"
  #  $toolname $version
  #  tool_installed $toolname
  #else
  #  tool_installation_failed $toolname
  #fi
  cd "$main_folder"
}

# Function to install tool using Python (pip)
install_with_python() {
  toolname=$1
  version=$2
  echo "$toolname not found, installing with Python"
  pip install $toolname
  if [ $? -eq 0 ]; then
    tool_installed $toolname
    $toolname $version
  else
    tool_installation_failed $toolname
    exit 1
  fi
}

# MAIN 

# Check if apt package manager is available
if ! [ -x "$(command -v apt)" ]; then
  echo "Error: apt package manager is not available."
  echo "Exiting..."
  exit 1
fi


# System update
if [[ "$UPDATE" == "true" ]]; then
  section_header "Performing System Update"
  apt update && apt upgrade -y
fi

# can be used by the developer to debug any failed in the pipeline or to check wether the agent have the capability to deploy the code 
if [ "$DEBUG" == "true" ]
then 
        echo " ========================================= host information ======================================"
        echo " OS = $(uname -s) $(uname -o)"
        echo " kernel release = $(uname -r)"
        echo " machine hardware name = $(uname -m)"
        echo " processor architecture = $(uname -p)"
        echo " ========================================= memory usage =========================================="
        free -th
        echo " ======================================== storage usage =========================================="
        lscpu  -e=CPU,CORE,MAXMHZ,MINMHZ
        echo " ======================================== Disk usage ============================================="
        df -u 
fi 




if [ -z "$(which ping)" ]
then
  echo "ping not found , installing"
  yes | apt install -y iputils-ping
  echo "==================== ping installed ======================"
  ping -V
  if [ $? -eq 0 ]; then
    tool_installed "ping"
  else
    tool_installation_failed "ping"
    exit 1
  fi
else
  ping -V
fi



# Check internet connectivity ( some linux dist doesnt have ping )
ping -q -c 1 -W 1 8.8.8.8 > /dev/null
if [ $? -ne 0 ]; then 
  echo "Error: Internet connection not available."
  echo "Exiting..."
  exit 1
fi

if [ -z "$(which yarn)" ]
then
  echo " yarn not found , installing " 
  yes | apt install cmdtest
  if [ $? -eq 0]; then
    tool_installed "yarn"
    yarn --version
  else
    tool_installation_failed "yarn"
  fi
else
  yarn --version
fi
    
# unzip
if [ -z "$(which unzip)" ]
then
  echo "unzip not found , installing"
  yes | apt install -y unzip
  echo "================== unzip installed ========================"
  if [ $? -eq 0 ]; then
    tool_installed "unzip"
    unzip -v
  else
    tool_installation_failed "unzip"
    exit 1
  fi
else
  unzip -v
fi


# Check if curl is available ( some linux dist doesnt have curl )
if [ -z "$(which curl)" ]; then
  echo "curl not found , installing"
  yes | apt install -y curl
  echo "================== curl ==================================="
  if [ $? -eq 0 ]; then
    tool_installed "curl"
    curl --version
  else
    tool_installation_failed "curl"
    exit 1
  fi
else
  curl --version
fi


# essential

# java insallation

if [ -z "$(which java)" ]
then
  echo "================== JAVA ========================"
  apt install default-jdk
  java --version
  echo "================================================"
  if [ $? -eq 0 ]; then
    tool_installed "java"
    java -version
  else
    tool_installation_failed "java"
    exit 1
  fi
fi




# nvm check ( this will offer the different ndoejs version to be used later on this will used by the jenkins file to choose the type of npm and node js version used )
nvm_check=$(which nvm)
if [ -z "$nvm_check" ]
then
  echo "nvm not found , installing nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm -v
else
  nvm -v
fi

# node
npm_check=$( which npm )
node_check=$( which node )
if [[ "$node_check" = "$node_version" ]]
then
  echo $npm_check
  echo $node_check
else
  nvm unistall $node_check
  installingnode
fi




# Read the configuration file
while IFS= read -r line; do
  # Skip commented lines and empty lines
  if [[ "$line" =~ ^\s*# ]] || [[ "$line" =~ ^\s*$ ]]; then
    continue
  fi

  # Extract tool information from the configuration line
  tool=$(echo "$line" | awk '{print $1}')
  existence=$(echo "$line" | awk '{print $2}' | tr -d '"' | sed 's/-E=//')
  version_code=$(echo "$line" | awk '{print $3}' | tr -d '"' | sed 's/-v=//')
  extension=$(echo "$line" | awk '{print $4}' | tr -d '"' | sed 's/-e=//')
  url=$(echo "$line" | awk '{print $5}' | tr -d '"' | sed 's/-U=//')
  update_option=$(echo "$line" | awk '{print $6}' | tr -d '"' | sed 's/-u=//' )
  installation_mode=$(echo "$line" | awk '{print $7}' | tr -d '"' | sed 's/-I=//') # Remove double quotes

  section_header "Installing Tool: $tool"

  # Check if the tool is required for the pipeline
  if [[ "$existence" == "false" ]]; then
    echo "Tool is not required."
    continue
  fi

  if [[ ! -z "$(which $tool)" ]]; then
    $tool $version_code
    continue
  fi

  # Install the tool based on the installation mode
  case $installation_mode in
    "APT")
      install_with_apt $tool $version_code
      ;;
    "URL")
      install_from_url $tool $version_code $url $extension
      ;;
    "PY")
      install_with_python $tool $version_code
      ;;
    *)
      echo "Invalid installation mode: $installation_mode"
      echo "Skipping installation."
      ;;
  esac

if [ "$tool" == "pmd" ]
then
  git clone https://github.com/pmd/pmd.git
  cd pmd
  keep_files=("pmd-java" "pmd-html" "pmd-javascript")
  #install the ruleset for pmd ( only java and javascript and html stored ) 
  for file in *; do
    if [[ ! " ${keep_files[@]} " =~ " ${file} " ]]; then
      if [[ -d $file ]]; then
        rm -rf "$file"  # Remove the directory and its contents recursively
      else
        rm "$file"     # Remove the file
      fi
    fi
  done
fi

done < "$config_file"

echo "======================================== FINISH SUCCESS ============================================================="
cd "$main_folder"
exit 0
