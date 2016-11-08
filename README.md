# MariaDb Galera Cluster

This Docker container is based on the official Docker `mariadb:10.1` image and is designed to be
compatible with auto-scheduling systems, specifically Docker Swarm Mode (1.12+) and Kontena (1.11).
However, it could also work with manual scheduling (`docker run`) by specifying the correct
environment variables.

It takes as a command one of the following:

 - "seed" - Used only to initialize a new cluster and after initialization and other nodes are joined
   the "seed" container should be stopped and replaced with a "node" container using the same volume.
 - "node" - Join an existing cluster. Takes as a second argument a comma-separated list of IPs or
   hostnames to resolve which are used to build the `--wsrep_cluster_address` option for joining a cluster.
 - "no-galera" - Start server with Galera disabled. Useful for maintenance tasks like performing mysql_upgrade
   and resetting root credentials.
 - "sleep" - Start the container but not the server. Runs "sleep infinity". Useful just to get volumes
   initialized or if you want to `docker exec` without the server running.
 
The main feature over the official maraiadb image is that DNS-resolution is used to discover other nodes
so they don't have to be specified explicitly. Works with any system with DNS-based service discovery such
as Kontena, Docker Swarm Mode, Consul, etc.

### Example (Docker 1.12 Swarm Mode)

```bash
 $ docker service create --name galera-seed --replicas 1 [OPTIONS] [IMAGE] seed
 $ docker service create --name galera --replicas 2 [OPTIONS] [IMAGE] node tasks.galera-seed,tasks.galera
 $ docker service rm galera-seed
 $ docker service scale galera=3
```

### Environment Variables

 - `XTRABACKUP_PASSWORD` (required)
 - `CLUSTERCHECK_PASSWORD` (optional - defaults to hash of `XTRABACKUP_PASSWORD`)
 - `CLUSTER_NAME` (optional)
 - `NODE_ADDRESS` (optional - defaults to ethwe, then eth0)

Additional variables for "seed":

 - `MYSQL_ROOT_PASSWORD` (optional)
 - `MYSQL_DATABASE` (optional)
 - `MYSQL_USER` (optional)
 - `MYSQL_PASSWORD` (optional)

Additional variables for "node":

 - `GCOMM_MINIMUM` (optional - defaults to 2)

### More Info

 - XtraBackup is used for state transfer and MariaDb now supports `pc.recovery` so the correct node should
   automatically become master in the case of all nodes being down.
 - A go server runs within the cluster exposing an http service on port 8080 which is used by the
   Docker 1.12 HEALTHCHECK feature and also can be used by any other health checking node in the network
   such as HAProxy or Consul.
 - By default the healthcheck is only healthy when Galera state is Synced or Donor so this is a better
   check than simply connecting to port 3306.
 - If your container network uses something other than `ethwe*` or `eth0` then you need to specify `NODE_ADDRESS`
   as either the name of the interface to listen on or a grep pattern to match one of the container's IP addresses.
   E.g.: `NODE_ADDRESS='^10.0.1.*'`
 - When using DNS for node address discovery the container entrypoint script will wait indefinitely for
   `GCOMM_MINIMUM` IP addresses to resolve before trying to start `mysqld` in case some containers are starting
   slower than others to increase the chance of a healthy recovery. Scenarios where not enough IPs would resolve
   might include:
    - Some nodes may finish pulling container images from remote repositories sooner than others
    - Schedulers may not be launching nodes quickly enough
    - Service discovery systems may be slow to propagate updates via DNS
 - If the file `/usr/local/lib/startup.sh` exists it will be sourced in the start.sh script.

### Credit

 - Forked from ["jakolehm/docker-galera-mariadb-10.0"](https://github.com/jakolehm/docker-galera-mariadb-10.0)
   - Forked from ["sttts/docker-galera-mariadb-10.0"](https://github.com/sttts/docker-galera-mariadb-10.0)
 - galera-healthcheck go binary from ["sttts/galera-healthcheck"](https://github.com/sttts/galera-healthcheck)

### Changes

 - Rebase on official Docker mariadb:10.1 image and fix for new 10.1 changes.
 - Add support for Docker Swarm Mode by falling back to eth0 if no ethwe adapter found.
 - Support any adapter/IP by specifying `NODE_ADDRESS=<interface|pattern>`.
 - Fix running mysqld as root using `gosu mysql mysqld.sh`.
 - Add support for HEALTHCHECK for Docker 1.12.
 - Delay starting mysqld until at least one other node is up when using DNS resolution for node list.
 - Bundle galera-healthcheck binary.
 - Fix bugs in mysqld startup.
 - Add sourcing of /usr/local/lib/startup.sh for easier entrypoint extension.
 - Add 'sleep' and 'no-galera' modes for easier maintenance.
