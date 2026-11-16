# PostgreSQL service

The `charts/postgres` chart installs one PostgreSQL instance in `platform-data`.
A persistent volume stores the database. The deployment uses `openebs-hostpath`.
The service does not provide high availability.

The instance listens on TCP port `5432`. The network policy admits Pestilence pods.
Other services need explicit network access and separate database roles.

## Secrets and certificates

The operator creates the `postgres-credentials` Secret before the database starts.
The Secret contains `admin-password` and `pestilence-password`.
The bootstrap script creates a separate Pestilence role and database.
The Pestilence role is not a PostgreSQL superuser.

Cert-manager issues the server certificate and a dedicated certificate authority (CA).
The CA certificate must also exist in the Pestilence namespace as `ConfigMap/postgres-ca`.
The `pestilence-postgres` Secret holds the connection URL in the `url` key.
The URL must use `sslmode=verify-full` and the mounted CA certificate.

The operator must coordinate CA rotation with every database client.
Restart PostgreSQL after its server certificate changes.

## Data protection

Back up the PostgreSQL database and test the restore procedure.
The Pestilence SQLite volume remains in place for migration rollback.
The SQLite volume does not contain changes made after the PostgreSQL cutover.
