FROM indigoiam/egi-trustanchors:el9
COPY igi-test-ca.repo /etc/yum.repos.d/
RUN yum -y install igi-test-ca
