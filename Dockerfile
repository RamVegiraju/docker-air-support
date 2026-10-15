FROM databricksruntime/air:dcs-base-aws-runtime

# River is an online machine learning library absent from the AIR base image.
ARG UV_INDEX_URL=https://pypi.org/simple
RUN uv pip install --no-cache river==0.22.0

COPY train.py /app/train.py
