#!/usr/bin/env bash

# include function library
source includes/functions.inc.sh

### IMPORTANT VARIABLES ###
  # create Date variable "ddmmYYYY-HHMMSS"
  DATETIME=$(date +%d%m%Y-%H%M%S)
  # assume /tmp for temporary DocumentRoot
: ${TEMP:="${HOME}/.deployment/testing.txt"}

## declare this here, for now... until we're pretty much done
declare -A deployment
  # "this" directory
  deployment['ScriptDir']="${PWD}"
  deployment['ConfigDir']="${deployment['ScriptDir']}/config"
  deployment['ConfigFile']=""
  #deployment['GitDir']="/opt/git"
  #deployment['GitDir']="${HOME}/Documents/sources"  # for testing
  deployment['GitDir']="/tmp"
  deployment['GitUser']="git"
  deployment['GitHost']="git.assembla.com"
  deployment['RsyncOptions']=""
  deployment['DestinationHost']="localhost"
  deployment['DestinationRoot']="/var/www"
  deployment['DestinationPath']="" # add DATETIME suffix so we can do "rollbacks"
  #: ${deployment['Repository']:="$1"}
  deployment['Repository']=""
  deployment['Environment']=""
  deployment['Branch']=""
  deployment['YAMLTEMP']="/tmp/yaml.test.tmp"
  #deployment['']=""    ## template for default values
  deployment['gitversion_file']='RELEASE.log'

function showusage {
  cat <<EOF
  Usage: deploy.sh [options] [repository name] [environment]
  
  To see full list of options, use option "-h".
    For Example:
                 ./deploy-yaml.sh -e staging dppo-lms.lms  
      -or-       ./deploy-yaml.sh web_service staging
EOF
}

function showhelp {
  cat <<EOF

  Usage: deploy.sh [options] [repository name] [environment]

    -d  override destination directory for git repo.
          Default is "<repository>-<environment>"
          NOTE: *do not* include trailing slash.
    -e  set environment ***IMPORTANT***
    -g  set git host to clone from.
          DEFAULT: "git.assembla.com"
    -u  set git user to clone from.
          DEFAULT: "git.assembla.com"
    -h  Show this message.
    -H  set Webserver Host to deploy to
          NOTE: this option is no longer necessary if "deployment['DestinationHost']" is
            configured in settings file.

    For Example:
                 ./deploy-yaml.sh -e staging dppo-lms.lms  
      -or-       ./deploy-yaml.sh web_service staging

EOF
exit
}

# if number of args is less than 1, `showusage`
[ $# -lt 1 ] && showusage 
options=":d:u:g:H:h"
while getopts "$options" optchar ; do
  case $optchar in
    h  )
       showhelp
       ;;
    d  )
       deployment['DestinationPath']="$OPTARG"
       shift ;;
    u  )
       deployment['GitUser']="$OPTARG"
       shift ;;
    g  )
       deployment['GitHost']="$OPTARG"
       shift ;;
    H  )
       deployment['DestinationHost']="$OPTARG"
       shift
       log "-H is not longer necessary, if deployment['DestinationHost'] is set in config file." info
       ;;
    \? ) log "Unknown option: -$OPTARG" warning ; showhelp ; exit ;;
    :  ) log "Missing option argument for -$OPTARG" warning ; showhelp ; exit ;;
    *  ) log "Unimplemented option" warning ; showhelp ; exit ;;
  esac
done

# Set our deployment[] variable for Repository name from the arguments
[ ! -z "$1" ] && deployment['Repository']="$1" && shift || \
  log "Missing 1st argument. You must supply a repository name to work from." error

# determine if Configuration File can be read, if so, define [ConfigFile]
[ -r "${deployment['ConfigDir']}/${deployment['Repository']}.yaml" ] && \
  deployment['ConfigFile']="${deployment['ConfigDir']}/${deployment['Repository']}.yaml" || \
  log "Configuration file \"./config/${deployment['Repository']}.yaml\" could not be found." error
# verify the Repository specified is defined in the configuration file
[[ `yaml get-value Name` = ${deployment['Repository']} ]] || \
  log "Could not verify configuration file \"${deployment['ConfigFile']}\"." error

# Set our deployment[] variable for Environment name from the arguments
[ ! -z "$1" ] && deployment['Environment']="$1" && shift || \
  log "Missing 2nd argument. You must supply an environment to deploy to." error
# Check that Environment name is defined in config file
[[ `yaml "get-type" Environment.${deployment['Environment']}` -eq "struct" ]] || \
  log "Could not verify Environment name \"${deployment['Environment']}\"." error

# make destination directory and go there ## or log the error 
[ ! -d "${deployment['GitDir']}/${deployment['Repository']}" ] && \
  ( mkdir -p "${deployment['GitDir']}/${deployment['Repository']}" || \
  log "Could not create directory to save repository at \"$_\"" error )

# Set our deployment[] variable for Branch name from the arguments
[ ! -z "$1" ] && deployment['Branch']="$1" && shift || \
  ( log "Missing 3rd argument. You have not specified a branch name" notice ; \
  echo -e "\tTherefore, the \"master\" branch as been chosen for you.  Please interrupt" ; \
  echo -e "\t this action with [ctrl+c] if this is unacceptable.\n" )

# clone the repo into a temporary location
if [ -d "${deployment['GitDir']}/${deployment['Repository']}-${deployment['Environment']}" ] ; then
  cd "${deployment['GitDir']}/${deployment['Repository']}-${deployment['Environment']}"
  git clean -f
  git reset --hard HEAD
  git pull
  git checkout "${deployment['Branch']}" && \
    log "Successfully checked-out branch \"${deployment['Branch']}\" in \"${PWD}\"." notice
else
  git clone "${deployment['GitUser']}@${deployment['GitHost']}:${deployment['Repository']}" \
    "${deployment['GitDir']}/${deployment['Repository']}/$DATETIME" && cd "$_" || \
    log "Failed to clone \"${deployment['Repository']}\" into \"$_\"" error
  # Verify Branch Name does actually exist, then checkout that branch
  (git tag --list ; git branch -r --list) | grep ${deployment['Branch']} || \
    log "Could not verify branch \"${deployment['Branch']}\" presence in Repository." warning
  git checkout "${deployment['Branch']}" && \
    log "Successfully checked-out branch \"${deployment['Branch']}\" in \"${PWD}\"." notice
fi

## this will output the top 3 lines from `git log` in "master" branch
truncate -s0 ${deployment['gitversion_file']}
echo "${DEPLOYUSERNAME} deployed ${deployment['Repository']}" >> ${deployment['gitversion_file']}
echo -e "\tat ${DATETIME} with branch ${deployment['Branch']}" >> ${deployment['gitversion_file']}
echo -e "to ${deployment['DestinationHost']} , \"${deployment['Environment']}\"\n" >> ${deployment['gitversion_file']}
git log|head -n15 >> ${deployment['gitversion_file']}
# state a fact
log "`git log|head -n5`" info

#TODO: refactor to a function GitSubmodule
for submodule in `yaml get-value Git.Submodule` ; do
  git submodule $submodule
done

#TODO: refactor to a function
for mkdir in `yaml get-value MkDirs` ; do
  mkdir -p "$mkdir" && log "Succcesfuly created dir \"$_\"" notice
done

# compile rsync options
for option in `yaml get-value Rsync.Options` ; do
  deployment['RsyncOptions']=${deployment['RsyncOptions']}"--${option} "
done

for ENV in ${deployment['Environment']} Default ; do
  for FILE in `yaml keys Environment.${ENV}|grep ^[a-z]` ; do
    #TODO: check if $FILE returns "NoneType", if yes, `continue`
    _FILE="`yaml get-value Environment.${ENV}.${FILE}.Path`/`yaml get-value Environment.${ENV}.${FILE}.Filename`"
    [[ -r "${_FILE}.template" ]] && mv ${_FILE}.template ${_FILE}
    for KEY in `yaml keys Environment.${ENV}.${FILE}` ; do
      ## TODO: 1) import default settings from YAML file
      ## TODO: 2) overwrite settings from specific environment
      case $KEY in
        "Require")
#          bootstrapfile="`yaml get-value Environment.${ENV}.${FILE}.Path`/`yaml get-value Environment.${ENV}.${FILE}.Filename`"
          bootstrapfile="/dev/null"
          echo "<?php" > ${bootstrapfile}
          for REQUIREONCE in `yaml get-value Environment.${ENV}.${FILE}.Require` ; do
            echo "require __DIR__ . '/bootstrap/${REQUIREONCE}';" >> ${bootstrapfile}
          done
          ;;
        "CopyFile")
          CopyFileFrom=`yaml get-value Environment.${ENV}.${FILE}.CopyFile.from | sed --expression="s#{ENVIRONMENT}#${deployment['Environment']}#g" | sed --expression="s#{SCRIPTDIR}#${deployment['ScriptDir']}#g" | sed --expression="s#{CONFIGDIR}#${deployment['ConfigDir']}#g"`
          CopyFileTo="`yaml get-value Environment.${ENV}.${FILE}.CopyFile.to`"
          cp "$CopyFileFrom" "${PWD}/${CopyFileTo}" && log "Copied file ${CopyFileFrom}" notice
          ;;
        "Path")
          ;;
        "Filename")
          ;;
        *)
          VALUE=`yaml get-value Environment.${ENV}.${FILE}.${KEY}`
          VALUE=`echo ${VALUE} | sed --expression="s#{ENVIRONMENT}#${deployment['Environment']}#g"`
  #TODO: validate AWS keys in MongoDB
  #TODO: validate BWS keys in MongoDB
          echo -en "${ENV} - Replacing \"${KEY}\" in ${FILE}"
          replaceToken "%%${KEY}%%" "${VALUE}" "${_FILE}" && echo -e "\t\t[ \e[92mOK\e[0m ]" || echo -e "\t\t[ \e[31mFAILED\e[0m ]" 
          ;;
      esac
      replaceToken "%%Environment%%" "${deployment['Environment']}" "${_FILE}"
    done
  done
done

##insert## Hook:  Pre-deploy
#[ "`yaml get-type Hooks.Pre-deploy.exec`" == "struct" ] && \
#  { hookPreExec="`yaml get-value Hooks.Pre-deploy.exec`";
#    log "Pre-deploy hook found, running command \"${hookPreExec}\"";
#    $hookPreExec; }

[ "`yaml get-type Hooks.Pre-deploy`" == "sequence" ] && \
  { yaml get-value Hooks.Pre-deploy | while read hookPreDeploy ;
  do echo "running command \"$hookPreDeploy\""; $hookPreDeploy; done }

# set rsync DestinationPath
: ${deployment['DestinationPath']:="${deployment['DestinationRoot']}/${deployment['Repository']}-${deployment['Environment']}"}

# determine destination hostnames for rsync deployment
if [ -z $_WEBHOST ] ; then
  # if there is a list, get *list* of destination webhost's
  if [[ "`yaml get-type Environment.${deployment['Environment']}.WEBHOST`" = "sequence" ]] ; then
    log "Multiple destination hosts found, please confirm each." notice
    for _hostname in `yaml get-value Environment.${deployment['Environment']}.WEBHOST` ; do
      ##TODO: make this block (deployment workflow) into a function deploymentDo()
      deployment['DestinationHost']=`echo ${_hostname} | sed -e "s#{ENVIRONMENT}#${deployment['Environment']}#g"`
      deploymentReview
      backupDocRoot
      entertocontinue "This is your last chance to cancel before overwriting existing files.  [Press Enter to Continue]"
      chownDocRoot "deploy"
      ##TODO: rename to deployDocRoot()
      deploymentDo
      chownDocRoot
      chmodDocRoot
#TODO: for load balanced servers, there will be no decision.  set the symlinks properly without asking
      #setSymlink  ## function not ready
    done
  else
    _WEBHOST="`yaml get-value Environment.${deployment['Environment']}.WEBHOST`"
    ##TODO: call deploymentDo() function instead
    deployment['DestinationHost']=`echo ${_WEBHOST} | sed -e "s#{ENVIRONMENT}#${deployment['Environment']}#g"`
    deploymentReview
    backupDocRoot
	entertocontinue "This is your last chance to cancel before overwriting existing files.  [Press Enter to Continue]"
    chownDocRoot "deploy"
    ##TODO: rename to deployDocRoot()
    deploymentDo
    chownDocRoot
    chmodDocRoot
    #setSymlink
#TODO: decide whether new site is working, if yes, continue, if no, revert symlink.
    #confirmSiteWorking=$(getInput confirmSiteWorking "is the site working")
    #[ == "OK" ] || setSymLink undo
  fi
fi

##insert## Hook:  Post-deploy

# TODO: implement "rollback procedure"
# 1 TODO: download copy of $DestinationPath, so we have a local backup ... (aka: $BackupPath) 
# 2 TODO: `mv` $DestinationPath to "$DestinationPath-bak-$DATETIME"
# 3 TODO: upload as usual
# 4 TODO: `rm`  "$DestinationPath-bak-$DATETIME"

#TODO: cleanup procedure
#echo "Remove temporary deployment dir \"$PWD\" ?"
#      rm -rf $PWD


log "Finished Deployment" info
entertocontinue
