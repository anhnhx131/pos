#!/bin/bash

set -e

# 1. Install Google Cloud Ops Agent

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh

bash add-google-cloud-ops-agent-repo.sh --also-install

# 2. Add config to retrive log Docker 

cat << 'EOF' > /etc/google-cloud-ops-agent/config.yaml
logging:
  receivers:
    docker_logs:
      type: files
      include_paths:
        - /var/lib/docker/containers/*/*-json.log
  service:
    pipelines:
      default_pipeline:
        receivers: [docker_logs]
metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics]
EOF

# 3. Make sure Docker use log-driver json-file

mkdir -p /etc/docker

cat << 'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF

systemctl restart docker

# 4. Restart Ops Agent

systemctl restart google-cloud-ops-agent

