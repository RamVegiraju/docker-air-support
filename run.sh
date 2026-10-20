#!/usr/bin/env bash
# Build, locally verify, publish, and run the River custom-image example.
#
# Usage: ./run.sh PROFILE CATALOG SCHEMA [IMAGE_TAG]
#   PROFILE:   OAuth CLI profile for the target AWS workspace.
#   CATALOG:   Existing Unity Catalog catalog for the image.
#   SCHEMA:    Existing schema in that catalog.
#   IMAGE_TAG: Image version label (default: v1); use a new tag for changed images.
#
# Requires: Docker engine, Databricks CLI >= 1.20.0, registry privileges,
# and the AI Runtime / Artifact Registry workspace previews.
# Optional: UV_INDEX_URL overrides the Python package index used during the build.
# Writes workload.generated.yaml, stores a local image, publishes a UC image,
# and submits a billable one-A10 workload while streaming its logs.
# Exit status: 2 for invalid arguments; otherwise propagates command failures.

# Stop before later stages if a command, unset variable, or pipeline fails.
set -euo pipefail

if (( $# < 3 || $# > 4 )); then
  echo "Usage: $0 PROFILE CATALOG SCHEMA [IMAGE_TAG]" >&2
  exit 2
fi

profile=$1
catalog=$2
schema=$3
tag=${4:-v1}

# Restrict names before inserting them into the YAML template with sed.
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

# Resolve the build context and template relative to this script, not the caller.
cd "$(dirname "$0")"

image_name=air_river_demo
local_image="air-river-demo:$tag"
uc_image="$catalog.$schema.$image_name:$tag"
# AIR expects a three-part UC image name, without the registry hostname.
sed "s|__UC_IMAGE__|$uc_image|g" workload.yaml.template > workload.generated.yaml

# Build for AIR's Linux x86-64 workers, including on Apple Silicon hosts.
# Avoid the registry error observed when pushing Docker's attestation index.
docker build --platform linux/amd64 --provenance=false \
  --build-arg "UV_INDEX_URL=${UV_INDEX_URL:-https://pypi.org/simple}" \
  -t "$local_image" .
# Verify the packaged dependency and script before uploading; remove the container.
docker run --rm --platform linux/amd64 "$local_image" python /app/train.py

# Configure registry OAuth, tag the local image, and push it into the chosen schema.
databricks air images push --profile "$profile" \
  --source "$local_image" --catalog "$catalog" --schema "$schema" \
  --artifact "$image_name:$tag"
# Validate against the workspace without submitting compute.
databricks air run --profile "$profile" --file workload.generated.yaml --dry-run
# Submit the workload and keep streaming logs until the run finishes.
databricks air run --profile "$profile" --file workload.generated.yaml --watch
