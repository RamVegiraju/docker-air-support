#!/usr/bin/env bash
# Display live UC image metadata and an optional AIR run without changing resources.
#
# Usage: ./demo.sh PROFILE CATALOG.SCHEMA.ARTIFACT [RUN_ID]
#   PROFILE:  Authenticated Databricks CLI profile for the image's workspace.
#   ARTIFACT: Three-part UC image name without a tag or registry hostname.
#   RUN_ID:   Optional numeric AIR run ID; omit to display only image metadata.
#
# Requires: Databricks CLI >= 1.20.0, jq, and read access to the selected resources.
# Prints image versions and optional run status to stdout; errors go to stderr.
# No Docker engine is needed, and no new workload is submitted.
# Exit status: 2 for invalid arguments; otherwise nonzero on command/API errors.

# Include pipeline failures so a failed CLI request cannot look like a valid demo.
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "Usage: $0 PROFILE CATALOG.SCHEMA.ARTIFACT [RUN_ID]" >&2
  exit 2
fi

profile=$1
artifact=$2
run_id=${3:-}
# Validate names before embedding them in an API URL path.
if [[ ! "$artifact" =~ ^[a-z][a-z0-9_-]*\.[a-z][a-z0-9_-]*\.[a-z][a-z0-9_-]*$ ]]; then
  echo "Use a three-part image name containing lowercase letters, digits, underscores, or hyphens." >&2
  exit 2
fi
if [[ -n "$run_id" && ! "$run_id" =~ ^[0-9]+$ ]]; then
  echo "RUN_ID must contain only digits." >&2
  exit 2
fi
# Check dependencies before making any workspace requests.
for tool in databricks jq; do
  command -v "$tool" >/dev/null || { echo "Required command not found: $tool" >&2; exit 1; }
done

printf 'Unity Catalog image: %s\nProfile: %s\n\n' "$artifact" "$profile"
# Images use the Software Artifacts API, rather than the UC Volumes API.
endpoint="/api/2.1/unity-catalog/software-artifacts/$artifact/versions"
while :; do
  response=$(databricks api get --profile "$profile" "$endpoint")
  # Format only the fields useful for a presentation; fail on an empty response.
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
  # Follow all pages; URL-encode the opaque continuation token before reuse.
  page_token=$(jq -r '.next_page_token // empty | @uri' <<< "$response")
  [[ -n "$page_token" ]] || break
  endpoint="/api/2.1/unity-catalog/software-artifacts/$artifact/versions?page_token=$page_token"
done

if [[ -n "$run_id" ]]; then
  # AIR wraps run metadata in .data; show the recorded status and dashboard link.
  # The caller supplies the run ID; this lookup does not verify its image digest.
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
