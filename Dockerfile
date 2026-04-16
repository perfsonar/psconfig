FROM ghcr.io/perfsonar/unibuild/u20:latest

WORKDIR /usr/src/app

COPY . .

# Build
RUN cd /etc/apt/sources.list.d/ && \
    curl -o perfsonar-release.list http://downloads.perfsonar.net/debian/perfsonar-release.list && \
    curl http://downloads.perfsonar.net/debian/perfsonar-official.gpg.key | apt-key add - && \
    apt update
RUN make

#Cleanup
RUN apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/
RUN rm -rf ./*
