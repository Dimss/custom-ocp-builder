FROM openshift/origin

MAINTAINER Dmitry Kartsev <dkartsev@redhat.com>

LABEL io.k8s.description="Custom Image Builder" \
      io.k8s.display-name="Custom Builder" \
      io.openshift.tags="builder,custom"

RUN echo "Installing Build Tools" && \
    yum install -y git && \
    yum clean all -y

ADD jq /usr/bin
ADD build.sh /tmp/build.sh

ENTRYPOINT [ "/bin/sh", "-c" ]

CMD [ "/tmp/build.sh" ]