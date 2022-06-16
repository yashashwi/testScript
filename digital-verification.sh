#!/bin/bash

###################################################################
## Dose IQ Image
###################################################################

# ------------------------------------------------------------
# Verification and Build
# ------------------------------------------------------------
scriptDir=`dirname $0`
cat $scriptDir/docker-compose-appliance.yml |-e "s/jboss/keycloak/615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:keycloak/" 
if [[ "$1" == "" ]]; then
	echo "Argument 1 should be the application version: x.y.z".
	exit 1
fi

if [[ "$2" == "" ]]; then
	echo "Argument 2 should be the keycloak version: a.b.c".
	exit 1
fi

# Installing Cosign hardcoded to 1.8 (latest at the moment)
wget "https://github.com/sigstore/cosign/releases/download/v1.8.0/cosign-linux-amd64"
mv cosign-linux-amd64 /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
cosign version

rm -rf /applianceCode
mkdir -m 0755 /applianceCode && git clone https://doseiq_svc_user:D0se1q@bitbucket-prod.aws.baxter.com/scm/dsq/appliance.git /applianceCode
rm -Rf /applianceCode/.git

mv /applianceCode/* /appliance/

rm -rf /applianceCode

aws configure set default.region us-east-2

$(aws ecr get-login --region us-east-2 --no-include-email)
aws sts get-caller-identity

# decrypt the credential file, so that aws can be configured to role which can verify the images
aws kms decrypt --ciphertext-blob fileb:///appliance/serviceAccountCreds/doseiq-service-account-encrypted-creds.txt --key-id bc32ba6e-aef0-49d4-82ea-5a2fa8d35f63 --output text --query Plaintext | base64 --decode > prodAccountKeyId.txt

cat prodAccountKeyId.txt
unset AWS_SESSION_TOKEN
unset AWS_SECRET_ACCESS_KEY
unset AWS_ACCESS_KEY_ID
export AWS_ACCESS_KEY_ID=AKIAQ7KQ5QWAPUIKEX37
export AWS_SECRET_ACCESS_KEY=$(cat prodAccountKeyId.txt)

rm -rf prodAccountKeyId.txt
$(aws ecr get-login --region us-east-2 --no-include-email)
aws sts get-caller-identity

tag=$1
keycloak=$2

# set the correct version number in the docker compose file
echo $tag > /appliance/tag
echo $keycloak > /appliance/keycloak

#pull the images

docker pull 615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:api-$tag
# pull UI image
docker pull 615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:ui-$tag

docker pull 615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:keycloak-$keycloak

export AWS_REGION=us-east-2

#verifying the images
cosign verify --key awskms:///arn:aws:kms:us-east-2:067278570880:key/ec459556-2fb1-400a-8429-34b890d11fba 615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:ui-$tag

cosign verify --key awskms:///arn:aws:kms:us-east-2:067278570880:key/ec459556-2fb1-400a-8429-34b890d11fba 615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:api-$tag

cosign verify --key awskms:///arn:aws:kms:us-east-2:067278570880:key/ec459556-2fb1-400a-8429-34b890d11fba 615146175312.dkr.ecr.us-east-2.amazonaws.com/doseiq:keycloak-$keycloak



