#!/bin/bash

# Script to flush and refresh MCX on a Mac
# Based on work found at jamfnation.jamfsoftware.com/discussion.html?id=5171
# and https://github.com/franton/Refresh-MCX/blob/master/RefreshMCX.sh

# Implemented : contact@richard-purves.com
# Moded by : godardyvan@gmail.com
# Version 1.0 : Initial Version
# Version 1.1 : Now kills the cfprefsd process to make sure there's no preference caching going on
# 				https://developer.apple.com/library/mac/#releasenotes/CoreFoundation/CoreFoundation.html
# Version 1.2 : Now removes MCX info from the local database to make sure.

# Brutally refresh mcx for a machine and all mobile accounts on it

# Variables initialisation
version="refreshMCX v1.3- 2015, Yvan Godard [godardyvan@gmail.com]"
versionOSX=$(sw_vers -productVersion | awk -F '.' '{print $(NF-1)}')
scriptDir=$(dirname "${0}")
scriptName=$(basename "${0}")
scriptNameWithoutExt=$(echo "${scriptName}" | cut -f1 -d '.')
listUsers=$(mktemp /tmp/${scriptName}_listUsers.XXXXX)
listMobileUsers=$(mktemp /tmp/${scriptName}_listMobileUsers.XXXXX)

function error () {
	echo -e "\n*** Erreur ${1} ***"
	echo -e ${2}
	alldone ${1}
}

function alldone () {
	ls /tmp/${scriptName}* > /dev/null 2>&1
	[ $? -eq 0 ] && rm -R /tmp/${scriptName}*
	exit ${1}
}

[[ `whoami` != 'root' ]] && echo "Ce script ${scriptName} nécessite des droits root, utilisez 'sudo' si besoin." && exit 1

echo ""
echo "****************************** `date` ******************************"
echo "${scriptName} démarré..."
echo "sur Mac OSX version $(sw_vers -productVersion)"

echo -e "\nkillall cfprefsd ..." && killall cfprefsd
[[ -e /Library/Managed\ Preferences ]] && echo -e "\nrm -Rfd /Library/Managed Preferences" && rm -Rfd /Library/Managed\ Preferences

# Clear machine cache
echo -e "\nSuppression du cache MCX machine ..."
[[ ${versionOSX} -lt 6 ]] && dscl . -delete /Computers
[[ ${versionOSX} -ge 6 ]] && dscl . -list Computers | grep -v "^localhost$" | while read computer_name ; do sudo dscl . -delete Computers/"$computer_name" ; done
[[ ${versionOSX} -eq 4 ]] && /System/Library/CoreServices/mcxd.app/Contents/Resources/MCXCacher -f

ls -A1 /Users/ | grep -v Guest | grep -v Shared | grep -v ".localized" > ${listUsers}
dscl . -list /Users AuthenticationAuthority | grep LocalCachedUser | awk '{print $1}' | tr '\n' ' ' > ${listMobileUsers}

echo -e "\nSuppression des caches MCX des Utilisateurs :"
for currentUser in $(cat ${listUsers}) ; do
	isMobile=0
	cat ${listMobileUsers} | grep -E "${currentUser} " > /dev/null 2>&1
	[[ $? -eq 0 ]] && isMobile=1
	echo -e "\n>> Traitement du compte ${currentUser}..."
	echo -e "   ...Suppression des MCXSettings pour ${currentUser}..."
	[[ ${isMobile} -eq 1 ]] && dscl . -delete /Users/${currentUser} MCXSettings
	dscl . -delete /Users/${currentUser} dsAttrTypeStandard:MCXSettings
	dscl . -mcxdelete /Users/${currentUser}
	echo -e "   ...Suppression des MCXFlags pour ${currentUser}..."
	[[ ${isMobile} -eq 1 ]] && dscl . -delete /Users/${currentUser} MCXFlags
	dscl . -delete /Users/${currentUser} dsAttrTypeStandard:MCXFlags
	echo -e "   ...Suppression des caches MCX de groupes pour ${currentUser}..."
	dscl . -delete /Users/${currentUser} cached_groups
	[[ -e /users/${currentUser}/Library/Managed\ Preferences ]] && echo -e "\nrm -Rfd /users/${currentUser}/Library/Managed Preferences" && rm -Rfd /users/${currentUser}/Library/Managed\ Preferences
	#Attempt to refresh from server
	[[ ${versionOSX} -ge 6 ]] && mcxrefresh -n ${currentUser}
done
	
alldone 0