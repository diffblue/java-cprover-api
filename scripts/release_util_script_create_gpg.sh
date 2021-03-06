#!/bin/bash
set -euo pipefail
#--------------------------------------------------------------------------------
SSL_PWD="$1"
RELEASE_KEY_TO_PUBLIC_SERVER="true"
#--------------------------------------------------------------------------------
cat >gen-key-script <<EOF
      %echo Generating a basic OpenPGP key
      Key-Type: RSA
      Key-Length: 4096
      Name-Real: Peter Schrammel
      Name-Email: peter.schrammel@diffblue.com
      Name-Comment:"CProver Java API" 
      Expire-Date: 1y
      %no-protection
      %commit
      %echo done
EOF

## create a local keypair with given configuration
gpg --batch --gen-key gen-key-script
#----------------------------------
#gpg --quick-gen-key 'Peter Schrammel <peter.schrammel@diffblue.com>'
#--------------------------------------------------------------------------------
## get key id
GPG_KEYID=$( gpg --list-keys --with-colons "Peter Schrammel" | grep "pub" | head -n1 | cut -d ':' -f5 )
echo "key id is: ${GPG_KEYID}"

echo "encrypted key id is:"
GPG_KEYID_ENC=$(echo "${GPG_KEYID}" | openssl aes-256-cbc -a -salt -pass pass:"${SSL_PWD}" | openssl enc -A -base64)
echo "${GPG_KEYID_ENC}"
#--------------------------------------------------------------------------------
## list keys public
echo "------- list public keys ------------------"
gpg --list-keys
## list keys private
echo "------- list private keys -----------------"
gpg --list-secret-keys
#--------------------------------------------------------------------------------
if [[ "${RELEASE_KEY_TO_PUBLIC_SERVER}" == "true" ]]
then
    #gpg --keyserver keyserver.ubuntu.com --send-keys ${GPG_KEYID}
    gpg --keyserver pgp.mit.edu --send-keys "${GPG_KEYID}"

    ## wait for the key to be accessible
    while(true); do
        date
        #gpg --keyserver keyserver.ubuntu.com --recv-keys ${GPG_KEYID} && break || sleep 15
        gpg --keyserver pgp.mit.edu --recv-keys "${GPG_KEYID}" && break || sleep 20
    done
fi
#--------------------------------------------------------------------------------
## export key
# gpg --batch --export-secret-key ${GPG_KEYID} -a --passphrase "" > private1.gpg
gpg --batch -a --export-secret-key "${GPG_KEYID}" > private1.gpg
#gpg --armor --export-secret-key 'Peter Schrammel <peter.schrammel@diffblue.com>'

## encode key to file
openssl enc -aes-256-cbc -pass pass:"${SSL_PWD}" -in private1.gpg -out private1.gpg.enc
rm private1.gpg

## remove generated key
gpg --delete-secret-keys "${GPG_KEYID}"
gpg --delete-key "${GPG_KEYID}"

## cleanup local configuration
rm gen-key-script
#--------------------------------------------------------------------------------
