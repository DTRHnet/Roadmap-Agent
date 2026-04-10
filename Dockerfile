FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl unzip tar git python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY . /workspace
RUN chmod +x /workspace/roadmap-agent.sh /workspace/roadmap-agent /workspace/rma /workspace/rma.sh /workspace/entrypoint.sh /workspace/scripts/setup-local-models-mempalace.sh

ENTRYPOINT ["/workspace/entrypoint.sh"]
