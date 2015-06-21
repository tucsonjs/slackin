#!/usr/bin/env bash

# Globals
NOW=`date +%s`
BRANCH=`git rev-parse --abbrev-ref HEAD`
EXTRACTDIR="/tmp/tucsonjs-slack-$NOW"
INSTALLDIR="/home/eric/tucsonjs-slack"

# Command Line Args
FORCE=0

# Parse the command line args
OPTIND=1
while getopts "fb:" OPT ; do
    case "$OPT" in
    f) FORCE=1
       ;;
    esac
done

# Ensure we have a clean repository.
if [ $FORCE -ne 1 ] ; then
    GITSTATUS=`git status --porcelain`
    if [ -n "$GITSTATUS" ] ; then
        git status
        exit 1
    fi
fi

# Inform user of the branch we're about to deploy.
echo -n "Uploading branch $BRANCH... "
echo ""

# Create directory on remote host for extraction.
ssh eric@yucca.limulus.net "mkdir $EXTRACTDIR"
if [ $? -ne 0 ] ; then exit $? ; fi

# Send the archive of the repo to the remote host and extract it.
git archive $BRANCH | bzip2 | \
    ssh eric@yucca.limulus.net "bunzip2 | tar -x -C $EXTRACTDIR"
if [ $? -ne 0 ] ; then exit $? ; fi
echo "done!"

# Rebuild the depencies and run all the tests on remote host.
ssh eric@yucca.limulus.net "cd $EXTRACTDIR && cp -dr $INSTALLDIR/node_modules . && npm update && npm prune && make && npm test"
if [ $? -ne 0 ] ; then exit $? ; fi

# Stop the service, move files in place, start service back up.
echo -n "Taking service down... "
ssh root@yucca.limulus.net "svcadm disable tucsonjs-slack"
ssh root@yucca.limulus.net "mv $INSTALLDIR $INSTALLDIR-deleteme; mv $EXTRACTDIR $INSTALLDIR"
ssh root@yucca.limulus.net "svcadm enable tucsonjs-slack"
echo "deployed!"
echo ""

# Clean up old deployment.
ssh eric@yucca.limulus.net "rm -r $INSTALLDIR-deleteme"
