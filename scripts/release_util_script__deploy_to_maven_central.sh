#!/bin/bash
set -euo pipefail
#------------------------------------------------------------
VERSION=$(mvn help:evaluate -Dexpression=project.version | grep -v -e "^\\[")
RELEASE="true"
GPG_KEY_ENC_FILENAME="scripts/private.gpg.enc"
RELEASE_KEY_TO_PUBLIC_SERVER="false"
#------------------------------------------------------------
SSL_PWD="$1"
## encoding command used of form "echo "$var" | openssl aes-256-cbc -a -salt -pass pass:${SSL_PWD} | openssl enc -A -base64"
SONATYPETOKEN_USER_ENC="VTJGc2RHVmtYMThXUlJTa0hRNzZOK1pReU9wanFpSVBDQ2VWQTFxWDlpZ3Boa0R4clBhd29hakgzRUxrNS9adgo="
SONATYPETOKEN_PWD_ENC="VTJGc2RHVmtYMThOdUduSmg1MEtjRE56R3lQd2hxdVVrd1pScDNFSXpNaVNud1UwUksrakRSTTY2RVVYUDlnQwo="
GPG_KEYID_ENC="VTJGc2RHVmtYMSs5dTVQaW9QS3RCTGhRV2hrTEx0a2FXbHVaMjVqQ05yZlc3QmR6UC9TWGRPWXVtRzFFN2FCagpqeTlJU0Z6eHpjajBlSDlHWThSd0JRPT0K="

decrypt_fn(){
    echo "$1" | openssl enc -A -base64 -d | openssl aes-256-cbc -d -a -pass pass:"$SSL_PWD"
}

SONATYPETOKENUSER=$(decrypt_fn "${SONATYPETOKEN_USER_ENC}")
export SONATYPETOKENUSER
SONATYPETOKENPWD=$(decrypt_fn "${SONATYPETOKEN_PWD_ENC}")
export SONATYPETOKENPWD
GPG_KEYID=$(decrypt_fn "${GPG_KEYID_ENC}")
export GPG_KEYID
#------------------------------------------------------------
openssl enc -aes-256-cbc -d -pass pass:"${SSL_PWD}" -in ${GPG_KEY_ENC_FILENAME} -out private.gpg
gpg --fast-import private.gpg
rm private.gpg

# Following section is in case a key is provided which has not already been
# shared to a pgp public server - and documents that process.
# NB if script 'release_util_script_create_gpg.sh' is used to create a new key,
# this procedure will have already been done.
if [[ "${RELEASE_KEY_TO_PUBLIC_SERVER}" == "true" ]]
then
    gpg --keyserver keys.openpgp.org --send-keys "${GPG_KEYID}"

    ## wait for the key to be accessible
    while(true); do
        date
        gpg --keyserver keys.openpgp.org --recv-keys "${GPG_KEYID}" && break || sleep 20
    done

    echo "wait for 2 minutes to let the key be synced"
    sleep 120
fi

## encoding command is of form 'openssl enc -aes-256-cbc -salt -in file.txt -out file.txt.enc' - nb 'salt'
openssl enc -aes-256-cbc -d -pass pass:"${SSL_PWD}" -in scripts/mvnsettingsPlainText.xml.enc -out mvnsettingsPlainText.xml
#------------------------------------------------------------
if [[ "${RELEASE}" == "false" ]]
then
    echo "This is a 'snapshot' release of cprover-api.jar, version ${VERSION}"
    mvn clean install -DskipTests=true -B -V
else
    echo "this is a 'release' version of cprover-api.jar, version ${VERSION}, this will be uploaded to the maven central staging ground"
    mvn clean deploy -DskipTests=true -P sign,build-extras,stdbuild --settings mvnsettingsPlainText.xml -B -V -Dgpg.keyname="${GPG_KEYID}"
fi
#------------------------------------------------------------
rm mvnsettingsPlainText.xml
## remove key from keyring, if this was a gpg key generated on the fly - then it would be gone forever.
gpg --delete-secret-keys "${GPG_KEYID}"
gpg --delete-key "${GPG_KEYID}"
#------------------------------------------------------------
