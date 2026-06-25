FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      bash \
      curl \
      faketime \
 && rm -rf /var/lib/apt/lists/*

RUN git config --global user.email "test@example.com" \
 && git config --global user.name "moonlight-commit tests"

WORKDIR /usr/src/app
COPY hooks/ ./hooks/
RUN chmod +x hooks/pre-commit hooks/commit-msg
COPY pages/ ./pages/
COPY install.sh ./install.sh
RUN chmod +x install.sh

COPY tests/run-tests.sh /usr/local/bin/run-tests.sh
RUN chmod +x /usr/local/bin/run-tests.sh

ENTRYPOINT ["run-tests.sh"]
