#!/bin/bash

VOICE_PACKAGE_ID="0XXXG000003vgM3"
SCRATCH_ORG_TTL=30
SKIP_VOICE_INSTALL="false"
SKIP_MOCK_CADENCE_DATA="false"
TARGET_DEV_HUB=""

# Exit immediately if a command exits with a non-zero status.
set -e

help_message()
{
    # Display help
    echo ''"$0"' -n org-name [options...]

    Options:

      -n  org-name             Set the org name for the new scratch org (required)
      -o  voice-package-id     Override the voice package id
      -b  git-branch           Builds a new scratch org from the specified branch
      -t  scratch-org-ttl      Set expiration time for the scratch org in days
                               (default '"$SCRATCH_ORG_TTL"' days)
      --target-dev-hub         Username or alias of the Dev Hub-enabled org
      --skip-voice-install     Skips installation of Conquer Voice
      --skip-mock-cadence-data Skips addition of mock Cadence data
      -h
      --help                   This help text
'
    exit
}

# validate the current working directory is a root dialsource repo
validate_work_dir()
{
    if [ ! -d "./packages/salesforce/conquer" ]; then
        echo "Cannot find directory packages/salesforce/conquer"
        echo "$(pwd) does not appear to be a root dialsource directory"
        exit
    fi
}

# calculate and set the working directory based on the script location
set_work_dir()
{
    if [ -z "$DIR" ]; then
        DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        cd "$DIR" && cd ../../
    fi
}

# gets the sfdx org info in a praseable way by running a sfdx force org list --json
create_scratch_org()
{
    # https://stackoverflow.com/a/50668339
    if ! [ -o xtrace ]; then
        # Print commands and their arguments as they are executed.
        set -x
        # Restore option on RETURN
        trap "set +x" RETURN
    fi

    cd packages/salesforce/conquer/

    sf org create scratch \
        --target-dev-hub "$TARGET_DEV_HUB" \
        --definition-file ./config/project-scratch-def.json \
        --duration-days "$SCRATCH_ORG_TTL" \
        --alias "$ORG_NAME" \
        --set-default

    if ! $SKIP_VOICE_INSTALL; then
        sf package install \
            --target-org "$ORG_NAME" \
            --package "$VOICE_PACKAGE_ID" \
            --no-prompt
    fi

    sf project deploy start \
        --target-org "$ORG_NAME" \
        --source-dir ./force-app/

    if ! $SKIP_MOCK_CADENCE_DATA; then
        sf apex run \
            --target-org "$ORG_NAME" \
            --file <(echo "new ScratchOrg();")
    fi

    sf org open \
        --target-org "$ORG_NAME"

}

# Python script to verify that an org exists and is Dev Hub-enabled
validate_dev_hub_org() {
    local org="$1"
    sf org list --json | python3 -c '
import sys
import json

data = json.loads(sys.stdin.read())
non_scratch_orgs = data["result"]["nonScratchOrgs"]
target_org = sys.argv[1]

for org in non_scratch_orgs:
    username = org["username"]
    alias = org["alias"]
    if target_org in (username, alias):
        if org["isDevHub"]:
            sys.exit(0)
        else:
            print("Error: Provided target Dev Hub is not Dev Hub-enabled")
            sys.exit(1)

print(f"Error: No org matches: {target_org}")
sys.exit(1)
    ' "$org"
    return $?
}

# Python script to attempt to find a Dev Hub-enabled organization
get_devhub_org_username()
{
    TARGET_DEV_HUB=$(sf org list --json | python3 -c '
import sys
import json

data = json.loads(sys.stdin.read())
non_scratch_orgs = data["result"]["nonScratchOrgs"]

usernames = []

for org in non_scratch_orgs:
    username = org["username"]
    if org["isDevHub"]:
        usernames.append(username)
        if org["isDefaultDevHubUsername"]:
            usernames = [username]
            break

if usernames:
    print(usernames[0])
')
    if [ -z "$TARGET_DEV_HUB" ]; then
        echo "Error: Did not find a Dev Hub-enabled organization"
        exit
    fi
}

# Get the options
while getopts ":n:o:b:t:h-:" OPTION; do
    case $OPTION in
        -)
            case "$OPTARG" in
                help) # display help
                    help_message;;
                skip-voice-install)
                    SKIP_VOICE_INSTALL="true";;
                skip-mock-cadence-data)
                    SKIP_MOCK_CADENCE_DATA="true";;
                target-dev-hub)
                    arg="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                    if [ -z "$arg" ]; then
                        echo "Error: Target Dev Hub was not specified"
                        exit
                    fi
                    TARGET_DEV_HUB_ORG="$arg"
                    ;;
            esac;;
        h) # display help
            help_message;;
        n) # Enter a name
            ORG_NAME=$OPTARG;;
        o) # override voice package id
            VOICE_PACKAGE_ID=$OPTARG;;
        b) # create scratch org from branch
            git stash && \
                git pull && \
                git checkout "$OPTARG";;
        t) # set scratch org expiration
            SCRATCH_ORG_TTL=$OPTARG;;
        \?) # Invalid option
            echo "Error:  $OPTARG is unknown"
            echo "See '$0 -h' for more information"
            exit;;
    esac
done

# ensure ORG_NAME is set
if [ -z "$ORG_NAME" ]; then
    echo "Error: org name. Please provide an org name. See '$0 -h' for more information"
    exit
fi

# Adding mock Cadence data requires installation of Conquer Voice
if ! $SKIP_MOCK_CADENCE_DATA && $SKIP_VOICE_INSTALL; then
    echo "Error: Can not add mock Cadence data unless Conquer Voice is installed"
    exit
fi


if [ -z "$TARGET_DEV_HUB" ]; then
    # Determine Dev Hub org
    get_devhub_org_username
else
    # Validate explicitly provided org
    validate_dev_hub_org "$TARGET_DEV_HUB_ORG"
fi

# navigate to the root dialsource directory
set_work_dir

# confirm we're in a root dialsource repo directory
validate_work_dir

# begin spinning up the scratch org
create_scratch_org
