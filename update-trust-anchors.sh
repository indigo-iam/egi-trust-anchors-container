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

TRUST_ANCHORS_TARGET=${TRUST_ANCHORS_TARGET:-}
CA_BUNDLE_TARGET=${CA_BUNDLE_TARGET:-}

if [ -n ${TRUST_ANCHORS_TARGET} ]; then
  echo "Copying trust anchors to ${TRUST_ANCHORS_TARGET}"
  rsync -avu -O --no-owner --no-group --no-perms /etc/grid-security/certificates/ ${TRUST_ANCHORS_TARGET}
fi

if [ -n ${CA_BUNDLE_TARGET} ]; then
  echo "Copying ca bundle to ${CA_BUNDLE_TARGET}"
  rsync -avu -O --no-owner --no-group --no-perms --exclude 'CA/private'  /etc/pki/ ${CA_BUNDLE_TARGET}
fi

if [ $# -gt 0 ]; then
  echo "Certificate copy requested to $1"
  rsync -avu -O --no-owner --no-group --no-perms /etc/grid-security/certificates/ $1
fi
