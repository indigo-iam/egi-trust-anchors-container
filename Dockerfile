FROM almalinux:9

COPY EGI-trustanchors.repo /etc/yum.repos.d/
COPY ./update-trust-anchors.sh /

RUN adduser --uid 12345 randomuser
RUN yum -y install epel-release && yum -y update

RUN yum -y install rsync ca-policy-egi-core fetch-crl

RUN curl -LO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

RUN chmod go+rx /update-trust-anchors.sh && chmod go+w /etc/grid-security/certificates/ && chmod -R go+wx /etc/pki

ENTRYPOINT ["/update-trust-anchors.sh"]
