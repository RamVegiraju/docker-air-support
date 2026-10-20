# Custom Docker image for Databricks AI Runtime

This example adds [River](https://riverml.xyz/) to a [Databricks AI Runtime base image](https://docs.databricks.com/aws/en/machine-learning/ai-runtime/cli/docker-images), then trains a tiny online classifier on synthetic data. River is absent from the base image; the Dockerfile installs it. No dataset or model download is needed.

AI Runtime allocates one A10 GPU for the workload. River trains this example on CPU, so the result demonstrates custom image packaging rather than GPU performance or a meaningful accuracy gain.

## Prerequisites

- Docker running locally and [Databricks CLI](https://docs.databricks.com/aws/en/machine-learning/ai-runtime/cli/installation) 1.20.0 or newer.
- An AWS workspace with **AI Runtime Beta Features** and **Databricks Artifact Registry** enabled in Previews.
- An existing Unity Catalog catalog and schema where you can push and read images. A new image needs `USE CATALOG`, `USE SCHEMA`, `CREATE VOLUME`, and `READ VOLUME`. See [Artifact Registry setup](https://docs.databricks.com/aws/en/artifact-registry/get-started#artifact-registry-permissions).
- An OAuth CLI profile for that workspace, created with `databricks auth login --host https://YOUR_WORKSPACE_HOST --profile air-demo`.

## Run

From this repository, pass your profile, catalog, and schema to the script:

```bash
./run.sh air-demo your_catalog your_schema v1
```

The script builds a `linux/amd64` image, tests the classifier locally, pushes the image to Artifact Registry, validates the AIR workload, and streams the AIR run. It writes `workload.generated.yaml` with your Unity Catalog image name; that generated file is ignored by Git. The training log prints River's version and accuracy on 100 held-out synthetic examples. The first image push can take several minutes.

Use a new image tag when you change the image. If Docker cannot reach PyPI, set `UV_INDEX_URL` to a reachable package index before running the script. This sample uses the AWS AIR base image; for Azure, change the Dockerfile to the corresponding Azure base image.

## Verified deployment

Validated on October 20, 2026 with Databricks CLI **1.21.0** and Docker Desktop **4.96.0**:

- **UC image:** `custom_ml.default.air_river_demo:v1`.
- **Registry reference:** `7474655512364318.container.us-east-1.cloud.databricks.com/custom_ml.default.air_river_demo:v1`.
- **Digest:** `sha256:b3727908dda182bd5aeb9c01ad1b81c7e2a34c330567ffce29bb139f13a63f0e`.
- **Result:** [Databricks run 20652474725107](https://dbc-b1357123-778f.cloud.databricks.com/jobs/runs/20652474725107) finished `SUCCESS`; River 0.22.0 achieved **97% accuracy** on 100 held-out synthetic examples after training on 400. Local and remote results matched.
- **Image acceleration:** `SUCCESS`, confirmed through the Software Artifacts API.

Reproduce in this workspace with `./run.sh ml-demos custom_ml default <new-tag>` after authenticating the `ml-demos` profile.

### Find the image in Unity Catalog

Artifact Registry images are governed in Unity Catalog, but [Catalog Explorer currently has no image interface](https://docs.databricks.com/aws/en/artifact-registry/#limitations). There is no direct UC image UI page. Use the authenticated [image versions API](https://dbc-b1357123-778f.cloud.databricks.com/api/2.1/unity-catalog/software-artifacts/custom_ml.default.air_river_demo/versions), or run:

```bash
databricks api get --profile ml-demos \
  '/api/2.1/unity-catalog/software-artifacts?parent=schemas/custom_ml.default'
databricks api get --profile ml-demos \
  '/api/2.1/unity-catalog/software-artifacts/custom_ml.default.air_river_demo/versions'
```

The versions response includes the digest, tags, and image acceleration status. These workspace links and commands require workspace access and the corresponding UC privileges.

### Show it live in a demo

Run this read-only script from your terminal with an authenticated CLI profile and `jq` installed:

```bash
./demo.sh ml-demos custom_ml.default.air_river_demo 20652474725107
```

It queries Databricks live and prints the image's tags, full digest, acceleration status, creation time, and the run's status and URL. Omit the run ID to show only the image. It does not require Docker or submit a new workload. Open the printed run URL to show the training logs and 97% accuracy result.

## Troubleshooting

- **Registry internal server error after layers upload:** The default Docker attestation index failed in this deployment; pushing its single-platform manifest succeeded. `run.sh` uses `--provenance=false` to produce that format. To recover an already-built image after the CLI helper configures registry authentication:

  ```bash
  docker push --platform linux/amd64 \
    <registry-host>/<catalog>.<schema>.air_river_demo:<tag>
  ```

- **Invalid OAuth refresh token:** Run `databricks auth login --host <workspace-url> --profile <profile>` again.
- **Homebrew upgrade blocked by outdated Xcode tools:** Update the Command Line Tools, or install an official prebuilt Databricks CLI release and verify its published SHA-256 checksum. This deployment used the verified 1.21.0 binary.
- **Docker Desktop installation requests an administrator password:** Complete installation interactively, or install the official app directly and use its bundled CLI. Verify both client and server with `docker version` before running the script.
- **GPU pools API returns `FEATURE_DISABLED`:** That response alone did not block this deployment. Workload validation and the actual A10 run succeeded.

## Files

- `Dockerfile` adds River to the AIR base image and copies `train.py` into the image.
- `train.py` trains and evaluates the small classifier.
- `demo.sh` displays live UC image metadata and an optional AIR run for presentations.
- `workload.yaml.template` defines the AIR compute and command; `run.sh` fills in the image name and submits it with the [updated `databricks air` CLI](https://docs.databricks.com/aws/en/machine-learning/ai-runtime/cli/).

## Before contributing

Check `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT` before committing. Use your GitHub name and a GitHub-associated email (including your GitHub noreply address) so commits are attributed to your profile.

## Resources

- [Databricks CLI installation and updates](https://docs.databricks.com/aws/en/dev-tools/cli/install).
- [AI Runtime CLI quickstart](https://docs.databricks.com/aws/en/machine-learning/ai-runtime/cli/).
- [Custom Docker images, base images, and limitations](https://docs.databricks.com/aws/en/machine-learning/ai-runtime/cli/docker-images).
- [Artifact Registry setup, OAuth, permissions, and discovery](https://docs.databricks.com/aws/en/artifact-registry/get-started).
- [Artifact Registry troubleshooting](https://docs.databricks.com/aws/en/artifact-registry/troubleshooting).
- [Docker single-platform push behavior](https://docs.docker.com/reference/cli/docker/image/push/).
- [Docker Desktop for Mac installation](https://docs.docker.com/desktop/setup/install/mac-install/).
- [Official Databricks CLI releases and checksums](https://github.com/databricks/cli/releases).
