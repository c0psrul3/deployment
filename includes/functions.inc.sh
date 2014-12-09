#!/bin/sh
#################################
# File: includes/functions.inc.sh
# Author: MIke Nichols
# Date: 08/20/2013

# Function:  log()
#
function log() {
  local action=${1:-"No message provided"}
  shift
  local level="$1"
  level="`echo $level | awk '{print toupper($0)}'`"
  case "$level" in
    [Ee][Rr][Rr][Oo][Rr] )  # specifying an error, we echo text to stdout, in RED
      echo -e "\n \e[91m${action}\e[0m\n"
      exit
      ;;
    [Ww][Aa][Rr][Nn][Ii][Nn][Gg] )  # specifying a warning, we echo text to stdout, in YELLOW 
      echo -e "\n \e[93m${action}\e[0m\n"
      entertocontinue
      ;;
    [Nn][Oo][Tt][Ii][Cc][Ee] )  # specifying a warning, we echo text to stdout, in AQUA
      echo -e "\n \e[96m${action}\e[0m"
      ;;
    [Ii][Nn][Ff][Oo] )  # specifying a warning, we echo text to stdout, in BOLD WHITE
      echo -e "\n \e[1m${action}\e[0m"
      ;;
  esac
  echo "`date` ${level:-"DEBUG"} ${DEPLOYUSERNAME:-"nobody"} ${action}" >> ${LOGFILE}
}

# Function:
#   savelog()
#
function savelog() {
  cat $LOGFILE >> $RUNDIR/`date +%d%m%Y`.log 
}

# Function:
#   pinwheel()
# Synopsis:
#   Display a pinwheel, each spin is 1 second long. takes only 1 argument, being the
#   number of full rotations (defaulting to "1").
#
function pinwheel() {
  COUNTER=${1:-1}
  let COUNTER*=5
  echo ""
  until [ $COUNTER -lt 1 ] ; do
    let COUNTER-=1
    echo -ne '| \r'; sleep 0.04
    echo -ne '/ \r'; sleep 0.04
    echo -ne '- \r'; sleep 0.08
    echo -ne '\\\r'; sleep 0.04
  done
}

# Function:
#   countdown()
# Synopsis:
#   Display a countdown of numbers, sleeping 1 second between each.
#
function countdown() {
  COUNTER=${1:-1}
  echo ""
  until [ $COUNTER == 0 ] ; do
    echo -ne '\r'
    echo -ne "$COUNTER"
    let COUNTER-=1
  done
}

# Function:
#   getInput()
# Synopsis:
#   This function will ask a question of the user, taking their answer and
#   setting a defined variable with the user's response.
# @param: $1
#   variable name to set value of
# @param: $2
#   text to display asking question
# 
function getInput() {
  INPUT=""
  __result=$1
  printf "%b" "\n$2 "
  while read INPUT ; do
    eval $__result="'$INPUT'"
    break
  done
}

# Function:
#   areyousure()
#
function areyousure() {
  REPLY=""
  until [ ! -z $(echo $REPLY|grep [YyNn]) ] ; do
    echo -en "\n Are you sure "
    read -n 1 -p "${1}? [y/n] " REPLY
  done
  if [[ ! $REPLY == [Yy] ]] ; then
    log "User replied \"No\".. Program will quit." notice
    pinwheel 1; exit 1
  fi
}

# Function:
#   entertocontinue()
#
function entertocontinue() {
  local message=${1:-" Press [Enter] to continue..."}
  read -p "${message}"
  echo -e "OK!\n"
  sleep 1
}

# Function:
#   tokenReplace()
# Synopsis:
#   Replaces tokens with strings in config files
#
function getConfigSettings() {
  if [ $# -lt 2 ] ; then
    echo "Insufficient args supplied for configSetup()"
    exit 1
  fi
  chmod -R 0777 "." # make sure files are writeable
  declare -A configFiles
#  declare -A settings
  declare -A mkdirs
  _settingsFile=$1
  ENVIRONMENT=$2
  source ${_settingsFile} 
  if [ ${#mkDirs[@]} -gt 0 ] ; then
    for DIR in ${mkDirs[@]} ; do
      mkdir -m 0777 $DIR
    done
  fi
  if [ "${#configFiles[@]}" -gt 0 ] ; then
    for _fileName in "${!configFiles[@]}" ; do
      echo "Modifying ${_fileName} ..."
      for _token in "${!settings[@]}" ; do
        sed -i "s#%%${_token}%%#${settings[$_token]}#g" ${configFiles[$_fileName]}/${_fileName}.template
        if [ $? -gt 0 ] ; then
          echo "Something went wrong during replacement of token \"${_token}\""
          exit 1
        fi
      done
      sleep 1
      chmod -R 0777 "."
      mv ${configFiles[$_fileName]}/${_fileName}.template ${configFiles[$_fileName]}/${_fileName}
    done
  fi
}

# Function:
#   selectRepository()
#
function selectRepository() {
  ## get list of Repositories and provide list to select from
  local __result=$1
  declare -a LIST
  local COUNTER=0
  for repoName in `find -P ${CONFIGDIR} -name *.yaml -printf '%f\n'|sed s/\.yaml//`; do
    (( COUNTER ++ ))
    echo -e " $COUNTER)\e[93m $repoName\e[0m"
    LIST[$COUNTER]=$repoName
  done
  echo -ne "\n Please choose a deployment environment [1-${COUNTER}]: "
  local choice
  while read choice ; do
    eval $__result="${LIST[$choice]}"
    break
  done
} 

# Function:
#   selectEnvironment()
#
function selectEnvironment() {
  ## get list of Environments and provide list to select from
  local __result=$1
  declare -a LIST
  local COUNTER=0
  for envName in `cat config/${REPOSITORY}.yaml|yaml keys Environment|grep ^[a-z]` ; do
    (( COUNTER ++ ))
    echo -e " $COUNTER)\e[93m $envName\e[0m"
    LIST[$COUNTER]=$envName
  done
  echo -ne "\n Please choose a deployment environment [1-${COUNTER}]: "
  local choice
  while read choice ; do
    eval $__result="${LIST[$choice]}"
    break
  done
}

# Function:
#   selectBranch()
#
function selectBranch() {
#TODO: re-arrange deployment to pull down the repository
  log "\nfunction not implemented yet... \n\tattempting pseudo-intelligence mode..." notice
}

# Function:
#   mkDirs()
#
function mkDirs() {
  if [ ${#mkDirs[@]} -gt 0 ] ; then
    for DIR in ${mkDirs[@]} ; do
      mkdir -m 0777 $DIR
    done
  fi
}

# Function:
#   replaceTokens()
#
function replaceTokens() {
  if [ "${#configFiles[@]}" -gt 0 ] ; then
    for _fileName in "${!configFiles[@]}" ; do
      echo "Modifying ${_fileName} ..."
      for _token in "${!settings[@]}" ; do
        sed -i "s#%%${_token}%%#${settings[$_token]}#g" ${configFiles[$_fileName]}/${_fileName}.template
        if [ $? -gt 0 ] ; then
          echo "Something went wrong during replacement of token \"${_token}\""
          exit 1
        fi
      done
      sleep 1
      chmod -R 0777 "."
      mv ${configFiles[$_fileName]}/${_fileName}.template ${configFiles[$_fileName]}/${_fileName}
    done
  fi
}

# Function:   replaceToken()
#
function replaceToken() {
  local TOKEN="$1"
    shift
  local VALUE="$1"
    shift
  local FILE="$1"
    shift
  sed -i --expression="s#${TOKEN}#${VALUE}#g" ${FILE} 
}

# Function:   replaceString()
#
function replaceString() {
  local TOKEN="$1"
    shift
  local VALUE="$1"
  echo $@ | sed --expression="s#${TOKEN}#${VALUE}#g"
}

# Function:  yaml()
# @param: FILE 
#   The YAML format file that is provided
# @param: function
#   The function used against `shyaml`. options include:
#     'get-value','get-type','keys','values'
# @param: KEY
#   The KEY passed to shyaml
#
function yaml() {
  local function=${1:-"keys"}
    shift;
  local KEY=${1:-"deploy"}
    shift;
  FILE=${1:-"${deployment['ConfigFile']}"}
  # return values and (in-place) remove the leading "-"
  cat ${FILE} | shyaml "${function}" "${KEY}"|sed -e 's/^-//g' #|sed -e 's/:$//g' 
#  awk -F ": " '{print "[\"" $1 "\"]=\""$2"\""}')
#  awk -F ": " '{for (i=0;i<=NF;i++){printf $1 "\"]=\""$2"\""}')
#  awk '{for(i=2;i<=NF;i++){printf "%s ", $i}; printf "\n"}'
#  rm $YAMLTEMP
#OLD# sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' config/web_service.yaml 
}

# Function:
#   deploymentReview()
# Synopsis:
#   Display values of determined variables used in deployment
#
function deploymentReview() {
cat <<EOF

  Here's what we have so far:
  Repository:    ${deployment['Repository']}
  Environment:   ${deployment['Environment']}
  Branch:        ${deployment['Branch']}
  Git User:      ${deployment['GitUser']}
  Git Host:      ${deployment['GitHost']}
  Webserver:     ${deployment['DestinationHost']}
  Docroot:       ${deployment['DestinationPath']}
  RsyncOptions:  ${deployment['RsyncOptions']}

EOF
entertocontinue "Press [enter] if this looks reasonable..." 
}

# Function:
#   chownDocRoot()
# Synopsis:
#   Change ownership of DocRoot 
# @param: owner
#   The intended new owner of the 'DestinationPath'
#
function chownDocRoot() {
  owner=${1:-"www-data"}
  log "Changing DocumentRoot Path Ownership to $owner" info
  # prepare DestinationPath for writing -- TODO: this should be changed to ACL
  ssh ${deployment['DestinationHost']} "sudo chown -R ${owner}:${owner} ${deployment['DestinationPath']}"  
}

# Function:
#   chmodDocRoot()
# Synopsis:
#   Change mode of DocRoot 
# @param: mode
#   The intended new mode of the 'DestinationPath'
#
function chmodDocRoot() {
  mode=${1:-"0755"}
  log "Changing DocumentRoot Path Permissions to $mode" info
  # prepare DestinationPath for writing -- TODO: this should be changed to ACL
  ssh ${deployment['DestinationHost']} "sudo chmod -R ${mode} ${deployment['DestinationPath']}"  
}

# Function:
#	backupDocRoot()
# Synopsis:
#
function backupDocRoot() {
  ssh ${deployment['DestinationHost']} \
	"tar c -C ${deployment['DestinationRoot']} -f ${deployment['Repository']}.`date +%s`.tar ${deployment['Repository']}-${deployment['Environment']}"
  log "Successfully backed-up docroot \"${deployment['DestinationPath']}\" "
}


##TODO: rename to deployDocRoot()
# Function:   deploymentDo()
#
function deploymentDo() {
  # rsync Verbosely so we can verify things happen and DO NOT preserve 'group' nor 'owner'
  log "rsync -avcz ${deployment['RsyncOptions']} . ${deployment['DestinationHost']}:${deployment['DestinationPath']}" notice
  #rsync -avcz ${deployment['RsyncOptions']} "." ${deployment['DestinationHost']}:${deployment['DestinationPath']}
  ##TODO: line below is for deploying symlinked directory, with switch previous to current deployment
  ###   this one requires setting new symlinks, etc. to make the new deployment effective.
  rsync -n -avcz ${deployment['RsyncOptions']} "." ${deployment['DestinationHost']}:${deployment['DestinationPath']}-${DATETIME}
}

# Function:   setSymlink()
# Synopsis: Sets the symlink for the destination docroot -> host
function setSymlink() {
  echo -e "\nChanging DocRoot Symlink for testing.  Press [enter] after verifying deployment is ok."
  # remove orig. symlink
  ssh ${deployment['DestinationHost']} "unlink ${deployment['DestinationRoot']}/${deployment['DestiantionHost']}"
  ## set new symlink
  ssh ${deployment['DestinationHost']} "ln -s ${deployment['DestinationPath']}-${DATETIME} ${deployment['DestinationRoot']}/${deployment['DestiantionHost']}"
}

# vim: syntax=sh ts=2 sw=2 sts=2 sr noet
