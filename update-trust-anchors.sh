#!/bin/bash
set -ex

FETCH_CRL_TIMEOUT_SECS=${FETCH_CRL_TIMEOUT_SECS:-5}

if [[ -z "${FORCE_TRUST_ANCHORS_UPDATE}" ]]; then
  echo "Skipping trust anchors update (default behaviour)."
  exit 0
fi

fetch-crl --verbose -T ${FETCH_CRL_TIMEOUT_SECS} || true

# Update centos ca-trust

for c in /etc/grid-security/certificates/*.pem; do
  cp $c /etc/pki/ca-trust/source/anchors/
done

update-ca-trust extract

## Update ca trust does not include trust anchors that can sign client-auth certs,
## which looks like a bug
DEST=/etc/pki/ca-trust/extracted

/usr/bin/p11-kit extract --comment --format=pem-bundle --filter=ca-anchors --overwrite --purpose client-auth $DEST/pem/tls-ca-bundle-client.pem
cat $DEST/pem/tls-ca-bundle.pem $DEST/pem/tls-ca-bundle-client.pem >> $DEST/pem/tls-ca-bundle-all.pem

TRUST_ANCHORS_TARGET=${TRUST_ANCHORS_TARGET:=}
CA_BUNDLE_TARGET=${CA_BUNDLE_TARGET:=}

if [ -n "${TRUST_ANCHORS_TARGET}" ]; then
  echo "Copying trust anchors to ${TRUST_ANCHORS_TARGET}"
  rsync -avu -O --no-owner --no-group --no-perms /etc/grid-security/certificates/ ${TRUST_ANCHORS_TARGET}
fi

if [ -n "${CA_BUNDLE_TARGET}" ]; then
  echo "Copying ca bundle to ${CA_BUNDLE_TARGET}"
  rsync -avu -O --no-owner --no-group --no-perms --exclude 'CA/private'  /etc/pki/ ${CA_BUNDLE_TARGET}
fi

if [ -n "${CA_BUNDLE_SECRET_TARGET}" ]; then
  echo "Copying ca bundle to ${CA_BUNDLE_SECRET_TARGET}"

  if ! command -v kubectl &> /dev/null; then
    curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl
  fi

  if kubectl get secret "$CA_BUNDLE_SECRET_TARGET" 2>/dev/null; then
    kubectl create secret generic "$CA_BUNDLE_SECRET_TARGET" --from-file=ca.crt=$DEST/pem/tls-ca-bundle-all.pem --dry-run=client -o yaml | kubectl replace -f -
    echo "Secret '$CA_BUNDLE_SECRET_TARGET' updated."
  else
    kubectl create secret generic "$CA_BUNDLE_SECRET_TARGET" --from-file=ca.crt=$DEST/pem/tls-ca-bundle-all.pem
    echo "Secret '$CA_BUNDLE_SECRET_TARGET' created."
  fi

fi

if [ -n "${JAVA_BUNDLE_TARGET}" ]; then
  echo "Updating Java cacerts keystore..."
  if [ -d "${JAVA_BUNDLE_TARGET}" ]; then
    keystore_target="${JAVA_BUNDLE_TARGET}/cacerts"
  else
    keystore_target="${JAVA_BUNDLE_TARGET}"
  fi
  java_rpm_pattern=openjdk-headless
  java_rpm=$(rpm -qa | grep ${java_rpm_pattern} | head -1)
  if [ -n "${java_rpm}" ]; then
    cacerts_file=$(rpm -q ${java_rpm} -l | grep cacerts)
    cp ${cacerts_file} ${keystore_target}
    for c in /etc/grid-security/certificates/*.pem; do
      # Prefix alias with IGTF- to prevent any collision with an existing alias in cacerts
      ca_alias=IGTF-$(basename ${c} .pem)
      echo ca_alias=$ca_alias
      keytool -importcert -trustcacerts -noprompt \
	      -alias ${ca_alias} \
  	      -keystore ${keystore_target} \
  	      -file ${c} -storepass changeit
    done
  else
    echo "Java RPM (${java_rpm_pattern}) not installed: cannot update Java cacerts keystore"
    exit 1
  fi
fi

if [ $# -gt 0 ]; then
  echo "Certificate copy requested to $1"
  rsync -avu -O --no-owner --no-group --no-perms /etc/grid-security/certificates/ $1
fi
