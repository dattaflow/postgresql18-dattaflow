FROM postgres:18

RUN apt-get update \
  && apt-get install -y --no-install-recommends pgbackrest ca-certificates \
  && rm -rf /var/lib/apt/lists/*