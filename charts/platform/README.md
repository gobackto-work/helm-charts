# platform

One chart for the whole Pi agent platform. It contains three component charts and one version of its own.

## What it creates

| From | Objects |
|---|---|
| `scarab` | the broker namespace, its network policy, and the tenant pod admission policies |
| `pestilence` | the control plane, its scoped RBAC and RBAC admission policies, the assertion public key, and the shared workspace edge |
| `town` | the management interface, its ingress, and the assertion private key |

Install order is not declared and does not need to be: Helm sorts every rendered object by kind across all subcharts, so all three Namespaces and all ClusterRoles are created before the RoleBindings and workloads that reference them.

The packaged chart embeds the three subcharts, so `helm pull` fetches one artifact.

## Versions

The components version independently. Each component chart names the image version it deploys in its own `values.yaml`, and the platform's `Chart.yaml` declares each chart's version. Nothing enforces a shared number.

Renovate moves a component's image tag, its chart `version` and `appVersion`, and this
chart's dependency declaration together, keyed to the image in GHCR. One component
release is one pull request, and the gate fails if the four ever disagree.

## Images

Every image is pinned to a version. A floating tag would make a rollback a coin toss, so the gate fails on `latest` or an empty tag.

The release workflow then checks each reference resolves in GHCR, which is the part that needs the network.

## Setting up a cluster

The chart installs the platform. It does not create the two objects that are specific to a deployment:

- the assertion key pair, from town's `cluster-setup-scripts/generate-keys.sh`
- the GitHub client and session secrets, from town's `cluster-setup-scripts/create-secrets.sh`

These are scripts rather than chart values because the key pair must exist in two namespaces at once, and Helm cannot derive an Ed25519 public key from a private one.
