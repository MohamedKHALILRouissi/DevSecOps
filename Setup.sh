root@2cb3efe30244:/home# cat Setup.sh 
#!/bin/bash



# some linux dist dont have :
 # - curl 
 # - ping
 # - python 
 # - unzip




# Configuration file provided by security engineer
config_file=$(find / -type f -name configfile.txt 2>/dev/null)

# Global variables
main_folder=$(pwd)
node_version="14"
UPDATE="true"
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
    fi
  else
    eval $url
    if [ $? -eq 0 ]; then
      $toolname $version
    else
      tool_installation_failed $toolname
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
  cd $mainfolder
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
  fi
}

# Check if apt package manager is available
if ! [ -x "$(command -v apt)" ]; then
  echo "Error: apt package manager is not available."
  echo "Exiting..."
  #exit 1
fi

# Check internet connectivity ( some linux dist doesnt have ping )
ping -q -c 1 -W 1 8.8.8.8 > /dev/null
if [ $? -ne 0 ]; then
  apt install iputils-ping # use check to not redo it 
  echo "Error: Internet connection not available."
  echo "Exiting..."
  #exit 1
fi

# Check if curl is available ( some linux dist doesnt have curl )
if [ -z "$(which curl)" ]; then
  apt install curl # fix to check to not redo it 
  echo "Error: curl is not available."
  echo "Exiting..."
  #exit 1
fi

# System update
if [[ "$UPDATE" == "true" ]]; then
  section_header "Performing System Update"
  apt update && apt upgrade -y
fi




# essential

# java insallation

if [ -z "$(which java)" ]
then
  echo "================== JAVA ========================"
  apt install default-jdk
  java --version
  echo "================================================"
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

done < "$config_file"
