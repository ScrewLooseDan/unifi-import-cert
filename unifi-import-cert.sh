#!/bin/bash
# Much of this script came from two places:
# https://util.wifi.gl/unifi-import-cert.sh
# Author: Frank Gabriel, 15.09.2018
# Credits Kalle Lilja and others
# &
# https://github.com/stevejenkins/unifi-linux-utils
# UniFi Controller SSL Certificate Import Script for Unix/Linux Systems
# by Steve Jenkins <http://www.stevejenkins.com/>
#
# Also, a bit of code copied from:
# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker

# Poorly patched together by Screw Loose Dan 10/16/2018

############ Usage ############

# 1. Copy this file somewhere logical (/usr/local/bin/ ?)
#    and ensure it is excecutable by root (chmod 700)
# 2. Verify that you have valid certificates.
# 3. Update the settings as necassary below.
# 4. Manually run the script once to make sure it works.
# 5. Verify that the UniFi Controller is now using the expected certs.
# 6. Put a symlink in /etc/letsencrypt/renewal-hooks/deploy/ to script
#     (something like ln -s /usr/local/bin/usr/local/bin/unifi-import-cert.sh)
# 7. Probably should do a dry run (certbot renew --dry-run) to ensure
#     that the deploy hooks are seen (but they aren't run).
# 8. Have some coffee and wait for your certs to renew and verify everything works!

################################

############ Dependencies ###############

# An attempt has been made to keep this fairly portable and as such,
#  the binaries required for this should be on most linux systems.
# A mail command ('mail') needs to be functioning in order to reeceive emails.
# But, user beware - I've only tested on Ubuntu 18.04.

#########################################

############ Settings ##################
# Set the Domain name, only really needed if using LE 
# and not changing the PRIV_KEY and CHAIN_FILE below.
# This is going to be the pathname to the cert in the LE directory.
DOMAIN="drcstang.com"

# Email to get failure/success emails
EMAIL="dan@hd883.com"

# If using LE on Ubuntu/Debian (other?) you may not need to change
# If NOT using LE, point the below to your private and full chain certificates
PRIV_KEY=/etc/letsencrypt/live/${DOMAIN}/privkey.pem
CHAIN_FILE=/etc/letsencrypt/live/${DOMAIN}/fullchain.pem

# Uncomment/Change as needed
KEYSTORE=/var/lib/unifi/keystore	# Debian/Ubuntu based systems
# KEYSTORE=/opt/UniFi/data/keystore	# Fedora/RedHat/CentOS

########################################

######### Probably no need to change below ############

script=$(basename $0)

# A little bit of code to check for locate binaries on different systems
# Borrowed from https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker

find_binary() {
	local x= path= bin=$1 bin_paths='/bin /usr/bin /usr/local/bin /usr/sbin /usr/local/sbin /root/bin /root/.bin'

	for x in $bin_paths; do
		path="$x/$bin"

		if [ -x $path ]; then
			echo $path
			return
		fi
	done
}
send_email() {
	if [ -z $(find_binary mail) ] ; then
		# printf "ERROR: $0 there has been an issue and unable to mail.\n$1"
		logger -t $script "ERROR: $0 there has been an issue and unable to mail. - $1"
		exit 1
	else
		printf "An issue with updating UniFi certs.\n$1\n$script" | $(find_binary mail) -s "Error updating UniFi certs on $(hostname)" $EMAIL
		logger -t $script "Error - $1"
		exit 1
	fi
}
service_cmd() {
	# arch linux does not have a 'service' command
	local x= svc= svc_list="systemctl service rc-service"

	for x in $svc_list; do
		svc=$(which $x 2>/dev/null)
		if [ -n "$svc" ]; then
			case "$x" in
				# in an ideal world, this would be reloads, but on my system reload just kills the process
				# <shrug>
				systemctl) svc="$svc restart unifi.service";;
				service) svc="$svc unifi restart";;
				rc-service) svc="$svc unifi restart";;
			esac
			break
		else
			# centos does not have 'which' by default
			svc="/usr/sbin/service nginx reload"
		fi
	done

	echo $svc
}

# Verify required files exist
if [ ! -f ${PRIV_KEY} ] || [ ! -f ${CHAIN_FILE} ] || [ ! -f ${KEYSTORE} ]; then
        # printf "\nMissing one or more required files. Check your settings.\n"
	logger -t $script "Missing one or more required files. Check your settings."
        exit 1
else
        # Everything looks OK to proceed
	logger -t $script "Required keys/certs located, proceeding"
        # printf "\nImporting the following files:\n"
        # printf "Private Key: %s\n" "$PRIV_KEY"
	# printf "CA File: %s\n" "$CHAIN_FILE"
fi

# Make sure binaries exist
if [ -z $(find_binary mktemp) ] || [ -z $(find_binary keytool) ] || [ -z $(find_binary openssl) ] || [ -z $(find_binary cp) ] || [ -z $(find_binary date) ]; then
	send_email "ERROR $0 requires binaries mktemp, keytool, openssl, and cp.  One of them missing.\n"
	exit 1
fi

# Create temp file
P12_TEMP=$(mktemp -t $script.XXXXXXXX)

# Backup previous keystore
logger -t $script "Making a backup of the keystore"
cp ${KEYSTORE} ${KEYSTORE}.$(date +%Y%m%d_%H%M%S)
if [ $? -ne 0 ] ; then send_email "Issue making a backup" ; exit 1 ; fi

# Convert cert to PKCS12 format
logger -t $script "Converting cert to PKCS12 format" 
$(find_binary openssl) pkcs12 -export -inkey ${PRIV_KEY} -in ${CHAIN_FILE} -out ${P12_TEMP} -name unifi -password pass:unifi
if [ $? -ne 0 ] ; then send_email "ERROR with converting to PKCS12" ; exit 1 ; fi

# Delete the previous certificate data from keystore to avoid "already exists" message
logger -t $script "Removing previous certificate data from UniFi keystore..."
$(find_binary keytool) -delete -alias unifi -keystore ${KEYSTORE} -deststorepass aircontrolenterprise -noprompt
if [ $? -ne 0 ] ; then send_email "ERROR with removing previous cert from keystore" ; exit 1 ; fi

# Import certificate
logger -t $script "Importing certificate"
$(find_binary keytool) -importkeystore -deststorepass aircontrolenterprise -destkeypass aircontrolenterprise -destkeystore ${KEYSTORE} -srckeystore ${P12_TEMP} -srcstoretype PKCS12 -srcstorepass unifi -alias unifi -noprompt
if [ $? -ne 0 ] ; then send_email "ERROR with importing cert" ; exit 1 ; fi

# Remove temp file
logger -t $script "Removing temp file"
rm ${P12_TEMP}

# Restart the UniFi controller
logger -t $script "Restarting UniFi controller"
reload_service="$(service_cmd)"
$reload_service 2>&1 >/dev/null
if [ $? -ne 0 ] ; then send_email "ERROR with UniFi Controller restart\n$?" ; exit 1 ; fi

if [ -z $(find_binary mail) ] ; then
	logger -t $script "Unifi Controller Certificate Updated"
else
	printf "Unifi Controller Certificate Updated - $(hostname)\n" | mail -s "Unifi Controller Certificate Updated - $(hostname)" $EMAIL
fi
exit 0
