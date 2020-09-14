FROM debian:10

RUN apt-get update \
    && apt-get install -y curl git openssh-client

ENV CODE_SERVER_VERSION=3.5.0
RUN curl -L -o /tmp/code-server.deb https://github.com/cdr/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb \
    && dpkg -i /tmp/code-server.deb

RUN adduser --gecos '' --disabled-password code

USER code
WORKDIR /home/code
RUN bash -c 'mkdir {workspace,extensions,data}'

CMD ["/usr/bin/code-server","--config","/home/code/code-server.yaml"]

