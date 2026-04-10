FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl unzip tar git python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY . /workspace
RUN chmod +x /workspace/roadmap-agent /workspace/rma /workspace/rma.sh /workspace/scripts/unix/roadmap-agent.sh /workspace/docker/entrypoint.sh /workspace/scripts/unix/setup-local-models-mempalace.sh

ENTRYPOINT ["/workspace/docker/entrypoint.sh"]
