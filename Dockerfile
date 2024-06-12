FROM indigoiam/egi-trustanchors:main

# https://letsencrypt.org/certificates/
RUN yum install -y wget
RUN wget https://letsencrypt.org/certs/isrgrootx1.pem -o /etc/pki/ca-trust/source/anchors/isrgrootx1.pem