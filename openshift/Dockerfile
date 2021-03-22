FROM openshift/origin-release:golang-1.13

# download, verify and install openshift client tools (oc and kubectl)
# upgrade the openssl to the recent version ie 1.1.1g
WORKDIR /tmp
RUN OPENSHIFT_CLIENT_VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt|sed -n '/Version:/ { s/[ ]*Version:[ ]*// ;p}') \
    && curl -L -O -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$OPENSHIFT_CLIENT_VERSION/openshift-client-linux-$OPENSHIFT_CLIENT_VERSION.tar.gz \
    && curl -LO https://www.openssl.org/source/openssl-1.1.1g.tar.gz \
    && curl -L -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$OPENSHIFT_CLIENT_VERSION/sha256sum.txt | \
       grep openshift-client-linux-$OPENSHIFT_CLIENT_VERSION.tar.gz > openshift-origin-client-tools.sha256 \
    && sha256sum -c openshift-origin-client-tools.sha256 \
    && mkdir openshift-origin-client-tools \
    && tar xzf openshift-client-linux-$OPENSHIFT_CLIENT_VERSION.tar.gz --directory openshift-origin-client-tools \
    && tar xf openssl-1.1.1g.tar.gz \
    && mv /tmp/openshift-origin-client-tools/oc /usr/bin/oc \
    && mv /tmp/openshift-origin-client-tools/kubectl /usr/bin/kubectl \
    && rm -rf ./openshift* \
    && cd openssl-1.1.1g \
    && ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp no-idea no-dtls no-dtls1 no-shared no-psk no-srp no-ec2m no-weak-ssl-ciphers \
    && make install \
    && cd .. \
    && rm -rf openssl-1.1.1g.tar.gz openssl-1.1.1g \
    && mv /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
    && oc version

# upgrade to latest PyYAML
RUN python3 -mpip install -U PyYAML

# Allow runtime users to add entries to /etc/passwd
RUN chmod g+rw /etc/passwd
