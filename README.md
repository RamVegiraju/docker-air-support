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

## Files

- `Dockerfile` adds River to the AIR base image and copies `train.py` into the image.
- `train.py` trains and evaluates the small classifier.
- `workload.yaml.template` defines the AIR compute and command; `run.sh` fills in the image name and submits it with the [updated `databricks air` CLI](https://docs.databricks.com/aws/en/machine-learning/ai-runtime/cli/).
