#!/bin/bash

[[ ${BASH_VERSINFO[0]} -ge 4 ]] || { echo "This script requires at least BASH 4"; exit 1; }
[[ -w /etc/passwd ]] || { echo "Error: Only 'root' can execute this program!"; exit 1; }

BN=${0##*/}
DN=$(cd $(dirname $0) ; pwd)

##############################################################################
# arguments                                                                  #
##############################################################################

usage() {
  echo "Usage:"
  echo "  $BN [-r ROOT_DIR] {package list}"
  echo "Options:"
  echo "  -r ROOT_DIR: dir with srv/epages/eproot/Perl/bin/nodejs.d (default: /)"
  echo "Example:"
  echo " $BN -d /xhost/ep-build/export/home/build-epages/cdp/6.17.13/build/rpm/epages-nodejs-x86_64 jquery jsdom"
  exit 1
}

ROOT_DIR=/
while getopts r:vsqdglmpfSDOByn c ; do
  case $c in
    r) ROOT_DIR=$OPTARG ;;
    v|s|q|d|g|l|m|p|f|S|D|O|B|y|n) NPM_ARGS="$NPM_ARGS -$c" ;;
    *) usage ;;
  esac
done

shift `expr $OPTIND - 1`
[[ $# -eq 0 ]] && usage

##############################################################################
# execution                                                                  #
##############################################################################

. /etc/default/epages6
ls -d $ROOT_DIR/srv/epages/eproot/Perl/bin/ >/dev/null || exit 1
EPAGES_PERL=$(readlink -f "$ROOT_DIR"/srv/epages/eproot/Perl)
ROOT_DIR=$EPAGES_PERL/bin

mkdir -m 755 -p $ROOT_DIR/nodejs.d
chmod -R 755 $ROOT_DIR
cd $ROOT_DIR/nodejs.d || exit 1

echo $ROOT_DIR/npm.sh config set prefix $ROOT_DIR/nodejs.d
$ROOT_DIR/npm.sh config set prefix $ROOT_DIR/nodejs.d

for i in $@ ; do
  echo -e "\nPROCESSING: $i\n"
  ( if cd lib/node_modules/$i 2>/dev/null ; then
      echo "$(pwd): npm.sh remove"
      $ROOT_DIR/npm.sh remove
      echo "$(pwd): npm.sh install"
      $ROOT_DIR/npm.sh install
    else
      echo "`pwd`: $ROOT_DIR/npm.sh remove $i $NPM_ARGS"
      eval $ROOT_DIR/npm.sh remove $i $NPM_ARGS
      echo "$ROOT_DIR/npm.sh install $i $NPM_ARGS"
      eval $ROOT_DIR/npm.sh install $i $NPM_ARGS
    fi
  ) || { echo "ERROR: command failed"; exit 1; }
done

##############################################################################
# exit
##############################################################################

exit 0
