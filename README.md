# helm-charts

The Helm charts for the Pi agent platform. One chart installs town, pestilence and scarab.

## How it fits together

- **town** provides sign-in and the web interface.
- **pestilence** manages workspace lifecycles and cluster access.
- **scarab** runs the agent inside each workspace.
- **helm-charts** holds the charts that deploy them.

Each component repository builds and publishes an image. This repository holds the charts, and each component chart names the image version it deploys.

## Installing

```sh
helm install platform oci://ghcr.io/gobackto-work/charts/platform --version 1.0.0
```

Two objects must exist before anyone can sign in. Both are specific to a deployment, so they are scripts in the town repository, not chart values:

- the assertion key pair, from `cluster-setup-scripts/generate-keys.sh`
- the GitHub client and session secrets, from `cluster-setup-scripts/create-secrets.sh`

See [town's cluster setup](https://github.com/gobackto-work/town/blob/main/cluster-setup-scripts/README.md).

## Layout

| Path | Contents |
|---|---|
| `charts/platform` | the chart you install; it contains the other three |
| `charts/platform/charts/town` | the management interface |
| `charts/platform/charts/pestilence` | the control plane, its RBAC, and the shared edge |
| `charts/platform/charts/scarab` | the broker namespace and the tenant pod policy |

The dependencies carry no `repository`. The subcharts are directories under `charts/`, so nothing is fetched, vendored, or locked.

## Configuration

`charts/platform/values.yaml` is the single place the platform is configured. Each top-level key is a component.

## Releasing a component

The components version independently. town 1.2.0 can run against pestilence 1.1.0. When a component publishes an image, move the version here:

Renovate opens the pull request. It keys every statement of a component's version to
that component's image in GHCR, so the image tag, the chart's `version` and
`appVersion`, and the platform's dependency declaration all move in one PR. The gate
fails if they ever disagree.

There is no script for this, and no version to edit by hand.

## Releasing the chart

The platform chart's own version is the one number Renovate does not move: it
describes the chart, not a component. Edit `charts/platform/Chart.yaml`, then tag:

```sh
git add charts/platform/Chart.yaml
git commit -m "platform 1.0.1"
git tag v1.0.1
git push origin main v1.0.1
```

The tag must match the platform version. The release workflow also checks that every image it deploys exists in GHCR, so a component that has not been released is caught before install time.

## Project status

The chart renders the whole platform and packages as one artifact. It has not been installed on a cluster yet.

See [the platform chart](charts/platform/README.md) for what it creates.
