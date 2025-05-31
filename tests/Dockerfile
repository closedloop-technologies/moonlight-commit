FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      bash \
      libfaketime \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
COPY hooks/ ./hooks/
RUN chmod +x hooks/pre-commit hooks/commit-msg

COPY tests/run-tests.sh /usr/local/bin/run-tests.sh
RUN chmod +x /usr/local/bin/run-tests.sh

ENTRYPOINT ["run-tests.sh"]
