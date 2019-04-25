#!/bin/bash
# Update Cachet
# |----------------------------------------------------------------------------
# | Name         : api_updater
# | Description  : Update CachetHQ from CheckMK using cUrl
# | Dependencies : curl
# | Author       : Sogal <sogal@opensuse.org>
# | Updated      : 25/04/2019
# | License      : GNU GLPv3 or later
# |----------------------------------------------------------------------------

# |----------------------------------------------------------------------------
# | Usage :
# | see Help function below
# |----------------------------------------------------------------------------

# |----------------------------------------------------------------------------
# | Cachet API codes reminder
# |...................
# | INCIDENTS:
# | Status  Name            Description
# | 0       Scheduled       This status is reserved for a scheduled status.
# | 1       Investigating   You have reports of a problem and you're currently
# |                         looking into them.
# | 2       Identified      You've found the issue and you're working on a fix.
# | 3       Watching        You've since deployed a fix and you're currently
# |                         watching the situation.
# | 4       Fixed           The fix has worked, you're happy to close the
# |                         incident.
# |...................
# | Status  Name            Description
# | 1       Operational     The component is working.
# | 2       Performance     Issues The component is experiencing some slowness.
# | 3       Partial Outage  The component may not be working for everybody.
# | 4       Major Outage    The component is not working for anybody.
# | ...................
# | CHECKMK alert codes reminder
# | 0       OK
# | 1       WARN
# | 2       CRIT
# | 3       UNKNOWN
# |----------------------------------------------------------------------------

# |----------------------------------------------------------------------------
# | Variables definition
# |----------------------------------------------------------------------------

MYDIR=$(dirname "$0")       # this script exec path
VERSION="0.1"               # this script version
API_URL="https://cachet.example.com/api/v1"
API_KEY="mySuperApiToken"
# The ALERT_ vars are taken from env
HOST=$ALERT_HOSTNAME
GROUP=$ALERT_HOSTGROUPNAMES
RAWCODE=$ALERT_SERVICESTATEID
SERVICE_AFFECTED=$ALERT_SERVICEFORURL
MSG_SEVERITY_UP="$SERVICE_AFFECTED - Service is back to normal"
MSG_SEVERITY_MEDIUM="$SERVICE_AFFECTED - Issues are being processed"
MSG_SEVERITY_CRIT="$SERVICE_AFFECTED - Issues are being processed"

# |----------------------------------------------------------------------------
# | Functions
# |----------------------------------------------------------------------------

Annonce () {
    if [[ $# -ne 2 ]]
    then
        echo -e "\t\033[1;31mThis function takes 2 parameters: <colour> <message>\033[0;00m"
        exit 1
    fi

    case $1 in
        red     ) echo -e "\n\033[1;31m"$2"\033[0;00m\n" ;;
        green   ) echo -e "\n\033[1;32m"$2"\033[0;00m\n" ;;
        yellow  ) echo -e "\n\033[1;33m"$2"\033[0;00m\n" ;;
        magenta ) echo -e "\n\033[1;35m"$2"\033[0;00m\n" ;;
        cyan    ) echo -e "\n\033[1;36m"$2"\033[0;00m\n" ;;
        gras    ) echo -e "\033[1;37m"$2"\033[0;00m" ;;
        norm    ) echo -e "\033[37m"$2"\033[0;00m" ;;
        *       ) echo -e "\n\t\033[1;31m/!\ : Unavailable colour\033[0;00m\n" ;;
    esac
}

CheckDeps () {
    which curl >/dev/null 2>&1
    if [ $? -ne 0 ] ; then
        Annonce red "Warning: curl not found"
        exit 2
    fi
}

Help () {
    echo -e "Usage: This script must be launched by the CheckMK alert handler
    $0 "name" "status code"

See https://docs.cachethq.io/docs/incident-statuses
and https://docs.cachethq.io/docs/component-statuses
or this script header for status codes."

    exit 1
}

PostIncident () {
    if [ $# -ne 3 ] ; then
        Annonce yellow "Missing argument"
        exit 2
    else
        curl --insecure -s -H 'Content-Type: application/json;' \
            -H "X-Cachet-Token: $API_KEY" \
            -d "{\"name\":\"$1\",\"message\":\"$2\",\"status\":$3}" \
            $API_URL/incidents
    fi
}

GetComponentID () {
    if [ $# -ne 1 ] ; then
        Annonce yellow "Missing argument"
        exit 2
    else
        echo $(curl --insecure -s -H 'Content-Type: application/json;' \
            -H "X-Cachet-Token: $API_KEY" \
            -X GET $API_URL/components\?name\=$1 \
            | python -c \
            'import sys, json; print json.load(sys.stdin)["data"][0]["id"]' 2>/dev/null)
         fi
}

GetGroupID () {
    if [ $# -ne 1 ] ; then
        Annonce yellow "Missing argument"
        exit 2
    else
        echo $(curl --insecure -s -H 'Content-Type: application/json;' \
            -H "X-Cachet-Token: $API_KEY" \
            -X GET $API_URL/components/groups\?name\=$1 \
            | python -c \
            'import sys, json; print json.load(sys.stdin)["data"][0]["id"]' 2>/dev/null)
    fi
}

UpdateComponent () {
    if [ $# -ne 2 ] ; then
        Annonce yellow "Missing argument"
        exit 2
    else
        ID=$(GetComponentID "$1")
        curl --insecure -s -H 'Content-Type: application/json;' \
            -H "X-Cachet-Token: $API_KEY" \
            -X PUT $API_URL/components/$ID \
            -d "{\"status\":$2}"
    fi
}

CreateComponent () {
    if [ $# -ne 3 ] ; then
        Annonce yellow "Missing argument"
        exit 2
    else
        GID=$(GetGroupID "$2")
        if [ -z $GID ] ; then
            GID=$(CreateGroup "$2")
        fi
        curl --insecure -s -H 'Content-Type: application/json;' \
            -H "X-Cachet-Token: $API_KEY" \
            -X POST $API_URL/components \
            -d "{\"name\":\"$1\",\"status\":\"$3\",\"group_id\":\"$GID\"}"
    fi
}

CreateGroup () {
    if [ $# -ne 1 ] ; then
        Annonce yellow "Missing argument"
        exit 2
    else
        curl --insecure -s -H 'Content-Type: application/json;' \
            -H "X-Cachet-Token: $API_KEY" \
            -X POST $API_URL/components/groups \
            -d "{\"name\":\"$1\",\"collapsed\":2}" \
        | python -c 'import sys, json; print json.load(sys.stdin)["data"]["id"]'
    fi
}

# |----------------------------------------------------------------------------
# | Begin script execution
# |----------------------------------------------------------------------------

CheckDeps

# We translate CheckMK code into Cachet codes
# We do not handle code 3 (UNKNOWN)
case $RAWCODE in
    0 ) CODE=1 ;;
    1 ) CODE=1 ;;
    2 ) CODE=4 ;;
    3 ) exit ;;
esac

case "$1" in
    -h)
        Help
        ;;
    * )
        GetID=$(GetComponentID $HOST)
        if [ -z $GetID ] ; then
            CreateComponent "$HOST" $GROUP $CODE
        else
            UpdateComponent "$HOST" $CODE
        fi
        case $CODE in
            1 ) PostIncident "$HOST" "$MSG_SEVERITY_UP" 4 ;;
            2 ) PostIncident "$HOST" "$MSG_SEVERITY_MEDIUM" 2 ;;
            4 ) PostIncident "$HOST" "$MSG_SEVERITY_CRIT" 2 ;;
        esac
        ;;
esac

exit $?
