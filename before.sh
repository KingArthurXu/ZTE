#!/bin/bash

#
# $Copyright: Copyright (c) 2016 Veritas Technologies LLC.
# All rights reserved.
# 
# THIS SOFTWARE CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS OF
# VERITAS TECHNOLOGIES LLC.  USE, DISCLOSURE OR REPRODUCTION IS PROHIBITED
# WITHOUT THE PRIOR EXPRESS WRITTEN PERMISSION OF VERITAS TECHNOLOGIES LLC.
#
# The  Licensed  Software  and  Documentation  are  deemed  to be commercial
# computer  software  as  defined  in  FAR  12.212 and subject to restricted
# rights  as  defined in FAR Section 52.227-19 "Commercial Computer Software
# - Restricted  Rights"  and  DFARS 227.7202,  et seq.  "Commercial Computer
# Software  and  Commercial Computer Software Documentation," as applicable,
# and any successor regulations, whether delivered by Veritas as on premises
# or  hosted  services.  Any  use,  modification,  reproduction  release,
# performance,  display  or  disclosure  of  the  Licensed  Software  and
# Documentation by the U.S. Government shall be solely in accordance with
# the terms of this Agreement. $
#
# v1.1.2
# -- write <name>.log instead of logger
# -- remove hastart
# -- fix OLD_VIOM_IP error if there are commented line(#)
# -- Slient execute, exit only VCS Config does not exists 20180420
# -- Change some ERROR to WARNING 20180808

SYSNAME_PATH="/etc/VRTSvcs/conf/sysname"
MAIN_CF_PATH="/etc/VRTSvcs/conf/config/main.cf"
VIOM_CF_PATH="/etc/default/sfm_resolv.conf"

VOMADM="/opt/VRTSsfmh/bin/vomadm"
XPRTLDCTRL="/opt/VRTSsfmh/adm/xprtldctrl"


HAD="/opt/VRTSvcs/bin/had"
PIDOF="pidof"
HASTOP="/opt/VRTS/bin/hastop"
HASTART="/opt/VRTS/bin/hastart"

LOGDIR=$(dirname "${BASH_SOURCE}")
LOGFILE=$(basename "${BASH_SOURCE}" .sh).log
touch "${LOGDIR}/${LOGFILE}"
LOGGER="tee -a $LOGDIR/$LOGFILE"


function change_hostname
{
    local NEW_VIOM
	local NEW_VIOM_IP
	local NEW_HOSTNAME
    
	local OLD_VIOM
	local OLD_VIOM_IP
	local OLD_HOSTNAME

	NEW_VIOM=${1}
	NEW_HOSTNAME=${2}
	
	#
    # Check if VCS sysname and main.cf files exist
    #
    if ! [ -f $SYSNAME_PATH ] || ! [ -f $MAIN_CF_PATH ]; then
        echo "ERROR : VCS Config Files Do Not Exist" | $LOGGER
        return 1
    fi
	
	# Get OLD_HOSTNAME from VCS sysname 
	OLD_HOSTNAME=$(cat $SYSNAME_PATH)

	#
    # Check if VCS [sysname] is empty
    #
    if [ "$OLD_HOSTNAME" == "" ]; then
        echo "ERROR : VCS Config [sysname] is empty, can't get OLD_HOSTNAME" | $LOGGER
        return 1
    fi
	
    #
    # Check if VIOM <sfm_resolv.conf> files exist 
    #
    if ! [ -f $VIOM_CF_PATH ]; then
        echo -e "WARNING : VIOM <sfm_resolv.conf> Files Do Not Exist" | $LOGGER
    fi

    #
    # Print parameter information 
    #	
	echo -e "INFO  : Parameter Information" | $LOGGER
	echo -e "INFO  : NEW_VIOM" $NEW_VIOM "\nINFO  : NEW_HOSTNAME" $NEW_HOSTNAME | $LOGGER

    #
    # Check if VCS is not running
    #
    if $PIDOF $HAD &> /dev/null; then
        echo "INFO  : VCS HAD Processes Is Running" | $LOGGER
		# Stop VCS 
		echo "INFO  : Try to stop VCS --#hastop-- " | $LOGGER
		OUTPUT=$($HASTOP -local -force 2>&1)
		if [[ $? -ne 0 ]]; then
			echo -e "WARNING : hastop failed" | $LOGGER
			echo -e "$OUTPUT" | $LOGGER
		fi
		sleep 3
	fi
    
    #
    # Change VCS <sysname> 
    #
    echo "INFO  : Change VCS <sysname>" | $LOGGER
	echo "INFO  : sed -i \"s/$OLD_HOSTNAME/$NEW_HOSTNAME/g\" $SYSNAME_PATH" | $LOGGER
	sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" $SYSNAME_PATH

    #
    # Change VCS <main.cf>
    #
	echo "INFO  : Change VCS <main.cf>" | $LOGGER
	echo "INFO  : sed -i \"s/$OLD_HOSTNAME/$NEW_HOSTNAME/g\" $MAIN_CF_PATH" | $LOGGER
    sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" $MAIN_CF_PATH
	
	#
    # Backup VIOM config file 
    #
	echo "INFO  : Rename VIOM Config File ... " | $LOGGER
	echo "INFO  : mv $VIOM_CF_PATH $VIOM_CF_PATH.$(date +%Y%m%d%M%H%S) 2>&1" | $LOGGER
	OUTPUT=$(mv $VIOM_CF_PATH $VIOM_CF_PATH.$(date +%Y%m%d%M%H%S) 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "WARNING : Rename VIOM Config File failed" | $LOGGER
		echo -e "$OUTPUT" | $LOGGER
	fi

	#
    # Try to stop VIOM agent 
    #
	echo "INFO  : Stop VIOM Agent ... " | $LOGGER
	echo "INFO  : $XPRTLDCTRL stop 2>&1" | $LOGGER
	OUTPUT=$($XPRTLDCTRL stop 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "WARNING : Stop Agent failed, continue!" | $LOGGER
		echo -e "$OUTPUT" | $LOGGER
	fi
	sleep 3

}

#
# main()
#
if [ $# -lt 2 ]; then
        echo -e $BASH_SOURCE "VIOM_SERVER_NAME" "NEW_HOSTNAME"
        exit 1
else
	echo -e $(date) | $LOGGER
	echo -e "INFO  : Start ..." | $LOGGER
	change_hostname $1 $2
	if [[ $? -eq 0 ]]; then
		echo -e $(date) | $LOGGER
		echo -e "INFO  : Success\n\n\n" | $LOGGER
		exit 0
	else 
		echo -e $(date) | $LOGGER
		echo -e "ERROR : Failed\n\n\n" | $LOGGER
		exit 1
	fi

fi
