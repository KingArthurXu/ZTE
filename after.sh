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
# v1.1
# -- write <name>.log instead of logger
# -- add hastart
# -- ssh to NEW_VIOM to refresh Storage Mapping Information 2018/04/02


#VIOM_CF_PATH="/root/conf/sfm_resolv.conf"

VIOM_CF_PATH="/etc/default/sfm_resolv.conf"

VOMADM="/opt/VRTSsfmh/bin/vomadm"
XPRTLDCTRL="/opt/VRTSsfmh/adm/xprtldctrl"
HAD="/opt/VRTSvcs/bin/had"
PIDOF="pidof"
HASTART="/opt/VRTS/bin/hastart"

LOGDIR=$(dirname "${BASH_SOURCE}")
LOGFILE=$(basename "${BASH_SOURCE}" .sh).log
touch "${LOGDIR}/${LOGFILE}"
LOGGER="tee -a $LOGDIR/$LOGFILE"

function delete_from_viom
{
    local NEW_VIOM
	local NEW_HOSTNAME
	NEW_VIOM=${1}
	NEW_HOSTNAME=${2}
	DEPLOY_SCRIPT="${NEW_VIOM}.pl"
	DEPLOY_SCRIPT="$(dirname "${BASH_SOURCE}")/"$DEPLOY_SCRIPT
	
    #
    # Check ssh is working
    #
    OUTPUT=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -l root $NEW_VIOM date 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "ERROR : ssh ${NEW_VIOM} failed" | $LOGGER
        return 1
    fi

	#
    # Print parameter information 
    #	
	echo -e "INFO  : Parameter Information" | $LOGGER
	echo -e "INFO  : NEW_VIOM" $NEW_VIOM "\nINFO  : NEW_HOSTNAME" $NEW_HOSTNAME | $LOGGER
	
    #
    # ssh to NEW_VIOM to delete old information
    #
	echo "INFO  : Remove Old Registered Information" | $LOGGER
	echo "INFO  : ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -l root $NEW_VIOM \"$VOMADM host-mgmt --remove --host $NEW_HOSTNAME -f 2>&1\"" | $LOGGER
	OUTPUT=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -l root $NEW_VIOM "$VOMADM host-mgmt --remove --host $NEW_HOSTNAME -f 2>&1")
	if [[ $? -ne 0 ]]; then
		echo -e "ERROR : Remove Registered Server Failed (Maybe Not Registered Before, Continue!" | $LOGGER
	fi
	echo -e "$OUTPUT" | $LOGGER
	sleep 3
	
	#
    # STOP VIOM agent 
    #
	echo "INFO  : Stop VIOM Agent ... " | $LOGGER
	echo "INFO  : $XPRTLDCTRL stop 2>&1" | $LOGGER
	OUTPUT=$($XPRTLDCTRL stop 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "ERROR : Stop Agent failed" | $LOGGER
		echo -e "$OUTPUT" | $LOGGER
		return 1
	fi
	sleep 3
	
	#
    # Rename VIOM config file 
    #
	echo "INFO  : Rename VIOM Config File ... " | $LOGGER
	echo "INFO  : mv $VIOM_CF_PATH $VIOM_CF_PATH.$(date +%Y%m%d%M%H%S) 2>&1" | $LOGGER
	OUTPUT=$(mv $VIOM_CF_PATH $VIOM_CF_PATH.$(date +%Y%m%d%M%H%S) 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "ERROR : Stop Agent failed" | $LOGGER
		echo -e "$OUTPUT" | $LOGGER
		return 1
	fi

	#
    # START VIOM agent 
    #
	echo "INFO  : Start VIOM Agent ... " | $LOGGER
	echo "INFO  : $XPRTLDCTRL start 2>&1" | $LOGGER
	OUTPUT=$($XPRTLDCTRL start 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "ERROR : Start Agent Failed" | $LOGGER
		echo -e "$OUTPUT" | $LOGGER
		return 1
	fi
	sleep 3
    
	#
    # Redeploy 
    #
	echo "INFO  : Redeploy And Register" | $LOGGER
	echo "INFO  : $DEPLOY_SCRIPT 2>&1" | $LOGGER
	OUTPUT=$($DEPLOY_SCRIPT 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "ERROR : Redeploy Failed" | $LOGGER
		echo -e "$OUTPUT" | $LOGGER
		return 1
	fi
	echo -e "$OUTPUT" | $LOGGER
    
	#
    # ssh to NEW_VIOM to refresh Storage Mapping Information
    #
	echo "INFO  : Refresh Storage Mapping Information" | $LOGGER
	REFRESH_VOM="/opt/VRTSsfmh/bin/perl /opt/VRTSsfmh/bin/mh_driver.pl --family VMWARE --hidden --id VMWARE_FAMILY "
	echo "INFO  : ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -l root $NEW_VIOM \"$REFRESH_VOM 2>&1\"" | $LOGGER
	OUTPUT=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -l root $NEW_VIOM "$REFRESH_VOM 2>&1")
	if [[ $? -ne 0 ]]; then
		echo -e "ERROR : Refresh Storage Mapping Information failed, Continue!" | $LOGGER
	fi
	echo -e "$OUTPUT" | $LOGGER
	sleep 3
	
}

#
# Check parameter & show usage
#
if [ $# -lt 2 ]; then
        echo -e "Usage:" $BASH_SOURCE "VIOM_SERVER_NAME" "NEW_HOSTNAME" 
        exit 1
else
	echo -e $(date) | $LOGGER
	echo -e "INFO  : Begin to Register MH to VIOM" | $LOGGER

    #
    #  Check HAD process, if not start VCS using new config 
    #
    if $PIDOF $HAD &> /dev/null; then
        echo "WARNING : VCS HAD Processes Is Running" | $LOGGER
	else
		echo "INFO  : Try to start VCS --#hastart--" | $LOGGER
		OUTPUT=$($HASTART 2>&1)
		if [[ $? -ne 0 ]]; then
			echo -e "ERROR : hastart Failed" | $LOGGER
			echo -e "INFO  : $OUTPUT" | $LOGGER
		fi
	fi
	
	delete_from_viom $1 $2
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
