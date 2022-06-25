#!/bin/bash

# This script searches for and blocks brute force attempts against a RHEL mail server running zimbra
# Created 12/03/2020 - SS
# Version 0.1

#VARIABLES
r_VERSION=0.1
SUBNETS_TO_EXCLUDE="10\.|192\.168"
ZONES="/etc/firewalld/zones"
FIRED="$ZONES/public.xml"
FIRED_BKUP_DIR="/etc/firewalld/public.xml_backups"
FIRED_ACCEPT="/etc/firewalld/public.xml"
TS=$(date +%m%d%Y-%H%M%S)
CHANGES=0
BLOCKED_IPS=""

# create backup dir if not already created
[[ ! -s "${FIRED_ACCEPT}_accept" ]] && touch "${FIRED_ACCEPT}_accept"

# grep live firewalld public.xml for accepted IPs and store in $ACCEPTED
ACCEPTED=$(grep -B1 "accept" $FIRED | egrep -o '[0-9]{1,3}+\.[0-9]{1,3}+\.[0-9]{1,3}+\.[0-9]{1,3}')

# store accepted IP's in a text file in /etc/firewalld/public.xml_accept
echo "$ACCEPTED" > "${FIRED_ACCEPT}_accept"

# grep for origin IPs in audit.log
IPS_TO_BLOCK=$(cat /opt/zimbra/log/audit.log | grep "authentication failed" | grep soap | egrep 'oip=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]' | awk -F\; '{ print $2 }' | awk -F= '{ print $2 }' | sort | uniq -c | egrep -v "$SUBNETS_TO_EXCLUDE" | awk ' $1 > 5 { print $2 }')

# test IPS_TO_BLOCK without being on mail server
# IPS_TO_BLOCK="6.6.6.6"

	for IP in $IPS_TO_BLOCK
	do
		if [[ ! $(grep $IP "${FIRED_ACCEPT}_accept") && \
		      ! $(grep " $IP/32 " "${FIRED}") && \
		      ! "$BLOCKED_IPS" =~ "$IP" ]]
		then
			BLOCKED_IPS="$BLOCKED_IPS $IP"
			echo "Adding IP $IP to firewalld reject" >&2
			echo "firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address=''    ${IP}'' reject""
			firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${IP}' reject"
			CHANGES=1
		else
			echo "${IP} had a conflict and wasn't added to firewalld"

		fi
	done

if [[ $CHANGES -ne 0 ]]
then
	[ ! -d "$FIRED_BKUP_DIR" ] && /bin/mkdir "$FIRED_BKUP_DIR"
	cp "$FIRED" "$FIRED_BKUP_DIR/public.xml_$TS"
      	gzip "$FIRED_BKUP_DIR/public.xml_$TS"
	echo "reloading firewalld"
	firewall-cmd --reload
fi

# List the last 10 IP's added to firewalld reject
echo "Last 10 IP's added to firewalld reject:"
firewall-cmd --list-all | grep -E reject | tail -n 10

USER_STATUS=""

for IP in $IPS_TO_BLOCK
do
 for user in $(cat /opt/zimbra/log/audit.log | grep "authentication failed" | egrep 'soap|imap' | egrep 'oip=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]' | egrep -v "$SUBNETS_TO_EXCLUDE" | awk '{ print $9 }' | awk -F= '{ print $2 }' | sed 's/;//')
 do
  if [[ "$user" =~ "$DOMAIN" ]]
  then
   if [[ ! "$USER_STATUS" =~ "$user" ]]
   then
    status=$(su - zimbra -c "zmprov ga $user zimbraAccountStatus" | grep "^zimbraAccountStatus" | awk '{ print $NF }')
    USER_STATUS="$USER_STATUS $user:$status"
    if [[ "$status" == "locked" ]]
    then
     echo "Account $user is locked, unlocking"
     su - zimbra -c "zmprov ma $user zimbraAccountStatus active"
     su - zimbra -c "zmprov ga $user zimbraAccountStatus" | grep "^zimbraAccountStatus"
    fi
   fi
  fi
 done
done
