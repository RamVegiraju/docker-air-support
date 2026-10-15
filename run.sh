#!/usr/bin/env bash
set -euo pipefail

if (( $# < 3 || $# > 4 )); then
  echo "Usage: $0 PROFILE CATALOG SCHEMA [IMAGE_TAG]" >&2
  exit 2
fi

profile=$1
catalog=$2
schema=$3
tag=${4:-v1}

for value in "$catalog" "$schema"; do
  if [[ ! "$value" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    echo "Catalog and schema must use lowercase letters, digits, underscores, or hyphens." >&2
    exit 2
  fi
done
if [[ ! "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "Image tag must use letters, digits, underscores, periods, or hyphens." >&2
  exit 2
fi

cd "$(dirname "$0")"

image_name=air_river_demo
local_image="air-river-demo:$tag"
uc_image="$catalog.$schema.$image_name:$tag"
sed "s|__UC_IMAGE__|$uc_image|g" workload.yaml.template > workload.generated.yaml

docker build --platform linux/amd64 \
  --build-arg "UV_INDEX_URL=${UV_INDEX_URL:-https://pypi.org/simple}" \
  -t "$local_image" .
docker run --rm --platform linux/amd64 "$local_image" python /app/train.py

databricks air images push --profile "$profile" \
  --source "$local_image" --catalog "$catalog" --schema "$schema" \
  --artifact "$image_name:$tag"
databricks air run --profile "$profile" --file workload.generated.yaml --dry-run
databricks air run --profile "$profile" --file workload.generated.yaml --watch
