[![build docker image](https://github.com/indigo-iam/egi-trust-anchors-container/actions/workflows/build-docker-image.yml/badge.svg)](https://github.com/indigo-iam/egi-trust-anchors-container/actions/workflows/build-docker-image.yml)

# EGI trust anchors container

This [container](https://hub.docker.com/r/indigoiam/egi-trustanchors) contains fetch-crl and other utilities
to provide an up-to-date trust anchors to relying applications, like Nginx, and to VOMS Attribute Authority service. When run,
the container updates 2 components:

- The system trust anchors, known as CA bundle, typically found in /etc/pki on an EL-based system
- The EGI trust anchors maintained by fetch-crl and typically found in /etc/grid-security/certificates in grid services

These 2 components are passed as 2 separate volumes to the container which will update them and used as volumes read by other
containers needing these informations.

The container is currently based on AlmaLinux 9.


## Configuration

The main configuration needed is the declaration of the 2 volumes. To avoid that the volumes are destroyed when the container is
deleted, and thus become unavailable to the containers using them, it is recommended to create the volumes before launching
the containers and to declare the volumes as `external` in the Docker/Podman configuration. It is typically done with (volume names are
free but must be consistent across the configuration):

```bash
# podman command can be used if using Podman instead of Docker
docker volume create cabundle
docker volume create trustanchors
```
The script behavior is controlled by several environment variables:

- `FETCH_CRL_TIMEOUT_SECS` (default 5 seconds): timeout of fetch-crl operations
- `FORCE_TRUST_ANCHORS_UPDATE` (default unset): **needs to be defined for the update to be executed**. If unset (or empty string) the script
exits immediately and doesn't do anything
- `TRUST_ANCHORS_TARGET` (default unset): **needs to be defined to properly update the trustanchors**. Location where the egi trustanchors
volume is mounted (where the container /etc/grid-security/certificates is rsync'ed)
- `CA_BUNDLE_TARGET` (default unset): **definition recommended to get the last version of the standard CA trust**. Location where the system CA
bundles are kept and where the container /etc/pki is rsync'ed, in particular
the bundle `tls-ca-bundle-all.pem` that contains the usual system bundle plus the egi trust-anchors
- `CA_BUNDLE_SECRET_TARGET` (default unset): an optional kubernetes secret including tls-ca-bundle-all.pem


## Compose file

Wheter using Docker or Podman, it is recommended to use a compose file to declare the container and how to run it. A typical
compose section for running this container would be:

```yaml
services:
    trustanchors:
        image: docker.io/indigoiam/egi-trustanchors:main
        pull_policy: always
        container_name: egi-trustanchors
        environment:
            - FORCE_TRUST_ANCHORS_UPDATE=1
            - TRUST_ANCHORS_TARGET=/egi-trustanchors
        volumes:
                - trustanchors:/egi-trustanchors
                - cabundle:/etc/pki

volumes:
    cabundle:
        external: true
    trustanchors:
        external: true


```

*Note: the parameters `external: true` in volumes is recommended if you use Docker or Podman to ensure that the volumes are not deleted once the container
is removed. If you run the container in the context of a CI, you may want to omit it so that the volume is created on the fly.*

## Cron job

The container exits after updating the trust anchors. It is necessary to have a mechanism to trigger its execution periodically. One way
to do it is to add a cron job that periodically recreates or restarts the container that has exited
(typically once a day). If the container has been created at startup, for example by executing the compose file, it is enough to
restart the container with an entry like:

```
# podman command can be used if using Podman instead of Docker
0 3 * * * root (date --iso-8601=seconds --utc; (/usr/bin/docker restart egi-trustanchors && /usr/bin/docker wait --interval 15s egi-trustanchors && /usr/bin/docker exec nginx-voms nginx -s reload)) >> /var/log/egi-trustanchors-update.log 2>&1
```
After an update of the CA bundle, it is necessary to reload Nginx as the CA bundle is loaded during Nginx startup. 

*Note: adapt the `egi-trustanchors` and `nginx-voms` container names to your configuration*
