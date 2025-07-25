docker run -d \
  --name cl-dora \
  -p 8080:8080 \
  -v "$(pwd)/dora/explorer-config.yaml:/explorer-config.yaml" \
  pk910/dora-the-explorer:v1.17.0 \
  -config=/explorer-config.yaml