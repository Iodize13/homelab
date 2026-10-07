# Monitoring

The Hetzner k3s cluster sends metrics to **Grafana Cloud**, which runs outside this
cluster. If the cluster goes down, dashboards and alerts keep working and report it,
instead of going down with it.

## What runs in the cluster

| Component | Purpose |
|---|---|
| Grafana Alloy (DaemonSet) | Scrapes metrics and ships them to Grafana Cloud |
| Alloy operator | Manages the Alloy instance |
| kube-state-metrics | Pod, deployment and restart state |
| node-exporter | Node CPU, memory and disk |

The collection pipeline is configured remotely through Grafana Cloud Fleet Management.

## Why the lightweight profile

The node has 8 GB of RAM and already runs EN Workshop, Matrix, Stash and the Java guide
(~77% memory in use). Grafana's generated install used the `large` preset (1 GiB request,
2 GiB limit) plus Beyla, the SDK injector and log collection. This setup keeps metrics
only, with the `small` preset (128 MiB request, 512 MiB limit).

## Website and DNS checks

In-cluster metrics cannot see DNS or Cloudflare Tunnel failures, because the cluster
resolves names internally and a dead cluster cannot report on itself. Public endpoints are
checked by Grafana Cloud Synthetic Monitoring from probes on the internet, so a missing DNS
record, an expired certificate or a 5xx all show up as down.

The checks are defined as code in [`synthetics/main.tf`](synthetics/main.tf): one HTTP check per
site (EN Workshop, Stash, Java guide, homepage) from Singapore and Frankfurt every 5 minutes,
with an alert when executions fail.

```sh
cd monitoring/synthetics
TF_VAR_sm_access_token="$(cat ~/grafana/sm-token)" terraform apply
```

Terraform state holds the token in plain text, so `*.tfstate` is git-ignored.

## Install

```sh
GRAFANA_CLOUD_TOKEN=glc_... ./monitoring/install.sh
```

The token is passed at install time and is never stored in this repository.

## Uninstall

```sh
helm uninstall grafana-cloud -n monitoring
```

If the chart's pre-delete hook fails because the Alloy operator was never created
(for example after an interrupted first install), use `--no-hooks`.
