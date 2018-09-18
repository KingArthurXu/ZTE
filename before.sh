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
# v1.1.1
# -- write <name>.log instead of logger
# -- remove hastart
# -- fix OLD_VIOM_IP error if there are commented line(#)

#SYSNAME_PATH="/root/conf/sysname"
#MAIN_CF_PATH="/root/conf/main.cf"
#VIOM_CF_PATH="/root/conf/sfm_resolv.conf"

SYSNAME_PATH="/etc/VRTSvcs/conf/sysname"
MAIN_CF_PATH="/etc/VRTSvcs/conf/config/main.cf"
VIOM_CF_PATH="/etc/default/sfm_resolv.conf"

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
        echo -e "ERROR : VIOM <sfm_resolv.conf> Files Do Not Exist" | $LOGGER
        return 1
    fi
    # Get VIOM [OLD_VIOM] 
 	OLD_VIOM=$(awk -F '=' '/^cs_config_name/{sub(/^[[:blank:]]*/,"",$2); sub(/;\s*$/,"",$2); print $2}' $VIOM_CF_PATH)
    # Check if VIOM [OLD_VIOM] is empty
    #
    if [ "$OLD_VIOM" == "" ]; then
        echo "ERROR : VIOM [OLD_VIOM] is empty,  can't get OLD_VIOM" | $LOGGER
		return 1
    fi
	
	OLD_VIOM_IP=$(awk '/^\s*[^#].*'$OLD_VIOM'/{print $1;exit}' /etc/hosts)
	NEW_VIOM_IP=$(awk '/^\s*[^#].*'$NEW_VIOM'/{print $1;exit}' /etc/hosts)
	
    #
    # Print parameter information 
    #	
	echo -e "INFO  : Parameter Information" | $LOGGER
	echo -e "INFO  : OLD_VIOM" $OLD_VIOM "\nINFO  : OLD_VIOM_IP" $OLD_VIOM_IP "\nINFO  : OLD_HOSTNAME" $OLD_HOSTNAME | $LOGGER
	echo -e "INFO  : NEW_VIOM" $NEW_VIOM "\nINFO  : NEW_VIOM_IP" $NEW_VIOM_IP "\nINFO  : NEW_HOSTNAME" $NEW_HOSTNAME | $LOGGER

	if [[ $OLD_VIOM_IP = "" ]] || [[ $NEW_VIOM_IP = "" ]]; then
		echo -e "ERROR : Failed To Get IP Information" | $LOGGER
		return 1
	fi

    #
    # Check if VCS is not running
    #
    if $PIDOF $HAD &> /dev/null; then
        echo "INFO  : VCS HAD Processes Is Running" | $LOGGER
		# Stop VCS 
		echo "INFO  : Try to stop VCS --#hastop-- " | $LOGGER
		OUTPUT=$($HASTOP -local -force 2>&1)
		if [[ $? -ne 0 ]]; then
			echo -e "ERROR : hastop failed" | $LOGGER
			echo -e "$OUTPUT" | $LOGGER
			return 1
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
    # Change VIOM <sfm_resolv.conf>
    #
	echo "INFO  : Change VIOM <sfm_resolv.conf> file" | $LOGGER

	echo "INFO  : sed -i \"s/$OLD_HOSTNAME/$NEW_HOSTNAME/g\" $VIOM_CF_PATH" | $LOGGER
	sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" $VIOM_CF_PATH

	echo "INFO  : sed -i \"s/$OLD_VIOM/$NEW_VIOM/g\" $VIOM_CF_PATH" | $LOGGER
    sed -i "s/$OLD_VIOM/$NEW_VIOM/g" $VIOM_CF_PATH

	echo "INFO  : sed -i \"s/$OLD_VIOM_IP/$NEW_VIOM_IP/g\" $VIOM_CF_PATH" | $LOGGER
	sed -i "s/$OLD_VIOM_IP/$NEW_VIOM_IP/g" $VIOM_CF_PATH

    #
    #  Start VCS using new config 
    #
	#echo "INFO  : Start VCS" | $LOGGER
	#OUTPUT=$($HASTART 2>&1)
	#if [[ $? -ne 0 ]]; then
	#	echo -e "ERROR : hastart Failed" | $LOGGER
	#	echo -e "INFO  : $OUTPUT" | $LOGGER
	#	return 1
	#fi
	
}

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
