#!/usr/bin/env bash
# Read-only display of a UC container image and an optional AIR run.
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "Usage: $0 PROFILE CATALOG.SCHEMA.ARTIFACT [RUN_ID]" >&2
  exit 2
fi

profile=$1
artifact=$2
run_id=${3:-}
if [[ ! "$artifact" =~ ^[a-z][a-z0-9_-]*\.[a-z][a-z0-9_-]*\.[a-z][a-z0-9_-]*$ ]]; then
  echo "Use a three-part image name containing lowercase letters, digits, underscores, or hyphens." >&2
  exit 2
fi
if [[ -n "$run_id" && ! "$run_id" =~ ^[0-9]+$ ]]; then
  echo "RUN_ID must contain only digits." >&2
  exit 2
fi
for tool in databricks jq; do
  command -v "$tool" >/dev/null || { echo "Required command not found: $tool" >&2; exit 1; }
done

printf 'Unity Catalog image: %s\nProfile: %s\n\n' "$artifact" "$profile"
endpoint="/api/2.1/unity-catalog/software-artifacts/$artifact/versions"
while :; do
  response=$(databricks api get --profile "$profile" "$endpoint")
  jq -er '
    if (.software_artifact_versions // [] | length) == 0 then
      error("No image versions returned; check the image name and UC permissions")
    else
      .software_artifact_versions[] |
      "Tags:          \((.tags // []) | join(", "))\n" +
      "Digest:        \(.digest)\n" +
      "Acceleration:  \(.image_acceleration_details.status // "UNSPECIFIED")\n" +
      "Created:       \(.create_time)\n"
    end
  ' <<< "$response"
  page_token=$(jq -r '.next_page_token // empty | @uri' <<< "$response")
  [[ -n "$page_token" ]] || break
  endpoint="/api/2.1/unity-catalog/software-artifacts/$artifact/versions?page_token=$page_token"
done

if [[ -n "$run_id" ]]; then
  databricks air get "$run_id" --profile "$profile" --output json | jq -er '
    if .data == null then error("Run response did not contain data") else
      .data |
      "AIR run:       \(.run_id)\n" +
      "Status:        \(.status)\n" +
      "Duration:      \(.duration_seconds) seconds\n" +
      "Open run:      \(.dashboard_url)"
    end
  '
fi
