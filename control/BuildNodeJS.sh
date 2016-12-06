#!/bin/bash

BN=${0##*/}
DN=$(cd $(dirname $0) ; pwd)

#=============================================================================
# BuildNodeJS.sh
#=============================================================================

if [ ! -w /etc/passwd ] ; then
  echo "$0: only 'root' can execute this program"
  exit 1
fi

if [ -z "$BASH_VERSION" ] ; then
  echo "$0: this script can only be executed by bash"
  exit 1
fi

LANG=C # use base language for standard output of some commands
LC_ALL=C

##############################################################################
# arguments                                                                  #
##############################################################################

usage() {
  [[ -n $1 ]] && echo -e "ERROR:\n  $1"
  echo "Usage:"
  echo "  $0 -d DIRECTORY -c CONFIG_FILE"
  echo "Options:"
  echo "  -d : build directory"
  echo "  -c : according to CONFIG_FILE"
  echo "Example:"
  echo "  $0 -c ./build.conf -d dir"
  exit 1
}

unset DIRECTORY CONFIG_FILE
while getopts d:c: c ; do
  case $c in
    d) DIRECTORY=$OPTARG ;;
    c) CONFIG_FILE=$OPTARG ;;
    *) usage ;;
  esac
done
shift $(expr $OPTIND - 1)
[[ $# -ne 0 ]] && usage

[[ -z $DIRECTORY ]] && usage "Option -d missing"
[[ -z $CONFIG_FILE ]] && usage "Option -c missing"
ls $CONFIG_FILE >/dev/null || usage "Option -c void"

CONFIG_FILE=$(readlink -f $CONFIG_FILE)
DIRECTORY=$(readlink -f $DIRECTORY)

#=============================================================================
# ECHO
#=============================================================================

ECHO () {
  local LINE_NUMBER=$(printf "%3d" $1)
  shift
  echo -e "[${0##*/}:$LINE_NUMBER] $@"
}

#=============================================================================
# EXIT
#=============================================================================

EXIT () {
  local ERROR_MSG=$@
  [[ -n $ERROR_MSG ]] && echo "ERROR: $0: $ERROR_MSG"
  rm -rf /tmp/$BN.~$$~
  [[ -n $ERROR_MSG ]] && exit 1 || exit 0
}

##############################################################################
# execution                                                                  #
##############################################################################

if [[ -e $DIRECTORY/work ]] ; then
  ECHO $LINENO rm -rf $DIRECTORY/work
  rm -rf $DIRECTORY/work
fi
mkdir -m 755 -p $DIRECTORY

INI_CONFIG=/var/epages/ini-config.sh
if [[ ! -x $INI_CONFIG ]] ; then
  INI_CONFIG=~/epages-infra/utils/ini-config.sh
  ls $INI_CONFIG >/dev/null || EXIT "requires $INI_CONFIG"
fi

ls ~/epages6-packages/scripts/BuildPackageTree.sh >/dev/null || EXIT "requires $INI_CONFIG"

#=============================================================================
# get required files from GIT
#=============================================================================

WORKING_DIR=$DIRECTORY/work
PERL_BIN=srv/epages/eproot/Perl/bin

ECHO $LINENO ~/epages6-packages/scripts/BuildPackageTree.sh --conf $CONFIG_FILE --git $DIRECTORY/git --target $WORKING_DIR
~/epages6-packages/scripts/BuildPackageTree.sh --conf $CONFIG_FILE --git $DIRECTORY/git --target $WORKING_DIR

ls $WORKING_DIR/$PERL_BIN >/dev/null || EXIT "directory not found"

#=============================================================================
# get nodejs package name node-*-linux-x64.tar.gz
#=============================================================================

cd $DIRECTORY

nodejs_version=$($INI_CONFIG -f $CONFIG_FILE -s nodejs -k version -G)
nodejs_version=${nodejs_version:-latest}
download_dir=$($INI_CONFIG -f $CONFIG_FILE -s nodejs -k download_dir -G)

if [[ $nodejs_version = latest ]] ; then
  ECHO $LINENO "curl -sLk $download_dir"
  pkg=$(curl -sLk $download_dir | awk -F\> '/node-.*-linux-x64.tar.gz/{gsub(/<.*/,"",$2);print $2}')
  [[ -n $pkg ]] || EXIT "no package node-*-linux-x64.tar.gz found in $download_dir"
else
  pkg=node-$nodejs_version-linux-x64.tar.gz
fi

#=============================================================================
# download and unpack nodejs package
#=============================================================================

ECHO $LINENO "wget $download_dir/$pkg"
wget $download_dir$pkg || EXIT "download failed"

ECHO $LINENO "tar zxf $pkg"
rm -rf ${pkg%.tar.gz}
tar zxf $pkg

# we still support CentOS 6.3, therefore used
# glibc version must not be higher than GLIBC_2.9
node_exe=${pkg%.tar.gz}/bin/node
[[ -f $node_exe ]] || EXIT "no $node_exe found in $pkg"

glibc_version=$( (strings $node_exe | grep '^GLIBC_' ; echo GLIBC_2.9) | sort -V | tail -1)
if [[ $glibc_version != GLIBC_2.9 ]] ; then
  EXIT "$node_exe uses glibc version higher than GLIBC_2.9: $glibc_version"
fi

#=============================================================================
# change and copy unpacked nodejs package to DIRECTORY
#=============================================================================

mkdir -m 755 -p $WORKING_DIR/$PERL_BIN/nodejs.d

ECHO $LINENO "( cd ${pkg%.tar.gz} && tar cf - * ) | ( cd $WORKING_DIR/$PERL_BIN/nodejs.d ; tar xf - )"
( cd ${pkg%.tar.gz} && tar cf - * ) | ( cd $WORKING_DIR/$PERL_BIN/nodejs.d ; tar xf - )

cd $WORKING_DIR/$PERL_BIN
ECHO $LINENO "pwd: $(pwd)"

for symlink in $(find nodejs.d -type l) ; do
  ECHO $LINENO cp --remove-destination $(readlink -f $symlink) $symlink
  \cp --remove-destination $(readlink -f $symlink) $symlink
done

ECHO $LINENO ln nodejs.d/bin/node nodejs.d/bin/nodejs
ln nodejs.d/bin/node nodejs.d/bin/nodejs
ECHO $LINENO cp -rl nodejs.d/bin/* .
cp -rl nodejs.d/bin/* .

#=============================================================================
# run npmBuild.sh
#=============================================================================

while IFS== read -a module ; do
  NPM_MODULES="$NPM_MODULES ${module[0]}"
done < <($INI_CONFIG -f $CONFIG_FILE -s npm-modules -G)

ECHO $LINENO $DN/npmBuild.sh -s -g -r $WORKING_DIR $NPM_MODULES
$DN/npmBuild.sh -s -g -r $WORKING_DIR $NPM_MODULES

#=============================================================================
# create resulting data directory
#=============================================================================

cd $DIRECTORY
ECHO $LINENO "pwd: $(pwd)"

ECHO $LINENO "cp -rl work data"
rm -rf data
cp -rl work data

ECHO $LINENO "rm -rf data/$PERL_BIN/*.sh"
rm -rf data/$PERL_BIN/*.sh
for i in $(ls -d data/$PERL_BIN/nodejs.d/lib/node_modules/node-epages6/* 2>/dev/null) ; do
  # do not delete nodejs.d/lib/node_modules/node-epages6/node_modules
  [[ $i = ${i%/node_modules} ]] || continue
  ECHO $LINENO "rm -rf $i"
  rm -rf $i
done

echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Now update git@github.com:ePages-de/node-binaries/data"
echo "by $(pwd)/data"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"

##############################################################################
# exit
##############################################################################

EXIT
