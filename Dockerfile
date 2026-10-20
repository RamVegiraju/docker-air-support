# AWS AIR base supplies Python, uv, CUDA, and the expected networking libraries.
FROM databricksruntime/air:dcs-base-aws-runtime

# River is an online machine learning library absent from the AIR base image.
ARG UV_INDEX_URL=https://pypi.org/simple
# Install into the base image's existing Python environment; pin for repeatability.
RUN uv pip install --no-cache river==0.22.0

# AIR ignores WORKDIR, so the workload uses the absolute /app/train.py path.
COPY train.py /app/train.py
