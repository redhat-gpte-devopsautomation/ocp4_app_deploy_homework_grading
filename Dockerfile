FROM registry.access.redhat.com/ubi8/go-toolset:latest as builder
ENV SKOPEO_VERSION=v1.0.0
RUN git clone -b $SKOPEO_VERSION https://github.com/containers/skopeo.git && cd skopeo/ && make binary-local DISABLE_CGO=1

FROM image-registry.openshift-image-registry.svc:5000/openshift/jenkins-agent-maven:v4.0 as final
USER root
RUN mkdir /etc/containers
COPY --from=builder /opt/app-root/src/skopeo/default-policy.json /etc/containers/policy.json
COPY --from=builder /opt/app-root/src/skopeo/skopeo /usr/bin
USER 1001
