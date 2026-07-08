# Apache Spark MLlib comparison environment (Tier 2).
#
# Base: the official Spark image (Spark 3.5.1, Scala 2.12, Java 17,
# python3). pyspark.ml imports numpy, which the official image does not
# ship, so it is added here — that is the only change.
FROM spark:3.5.1-scala2.12-java17-python3-ubuntu

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-pip \
    && pip3 install --no-cache-dir numpy \
    && rm -rf /var/lib/apt/lists/*
