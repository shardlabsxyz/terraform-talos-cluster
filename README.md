# Terraform Talos Cluster

<p align="center">
  <a href="https://github.com/shardlabsxyz/terraform-talos-cluster/actions/workflows/pre-commit.yml"><img alt="Pre-Commit" src="https://github.com/shardlabsxyz/terraform-talos-cluster/actions/workflows/pre-commit.yml/badge.svg"></a>
  <a href="https://github.com/shardlabsxyz/terraform-talos-cluster/actions/workflows/pr-title.yml"><img alt="Validate PR title" src="https://github.com/shardlabsxyz/terraform-talos-cluster/actions/workflows/pr-title.yml/badge.svg"></a>
  <a href="https://github.com/shardlabsxyz/terraform-talos-cluster/actions/workflows/release.yml"><img alt="Release" src="https://github.com/shardlabsxyz/terraform-talos-cluster/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://github.com/shardlabsxyz/terraform-talos-cluster/releases"><img alt="Latest Release" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fshardlabsxyz%2Fterraform-talos-cluster%2Freleases%2Flatest&amp;query=%24.tag_name&amp;label=release"></a>
  <a href="https://developer.hashicorp.com/terraform"><img alt="Terraform >= 1.13.0" src="https://img.shields.io/badge/Terraform-%3E%3D%201.13.0-844FBA?logo=terraform"></a>
  <a href="https://pre-commit.com/"><img alt="pre-commit enabled" src="https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
</p>

Terraform modules for deploying **hybrid [Talos](https://www.talos.dev/) Kubernetes clusters** with a cloud-hosted control plane and worker node pools that can run across cloud providers or on your own infrastructure.

## Why This Project?

Managed Kubernetes services give you a stable cloud control plane, but they make it difficult to bring your own workers across clouds, edge locations, or bare metal. This project keeps the control-plane ergonomics of a managed service while leaving node placement under your control.

Talos provides an immutable, API-managed Kubernetes host OS. Kubespan provides WireGuard-based node-to-node networking, so nodes can join the same cluster without requiring cloud network peering or VPNs between every location.

## What You Get

- A decoupled control plane and node pool model, similar to managed Kubernetes.
- AWS and GCP control plane modules.
- AWS and GCP worker node pool modules.
- Official Talos cloud image lookup and custom image factory modules.
- Complete AWS and GCP examples with Cilium and common add-ons.
- Pre-commit, Renovate, Mergify, and GitHub Actions wiring for module maintenance.

## When To Use It

Use this project when you want a Talos Kubernetes cluster with a stable cloud control plane and the option to attach workers from other clouds, regions, edge sites, or bare metal.

This project is not trying to replace EKS or GKE feature-for-feature. Cloud-provider integrations such as load balancers, CSI drivers, and cluster autoscalers are still bound by each provider's regional and network assumptions.

## Architecture

### Key Design Decisions

| Decision                     | Rationale                                                                                                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Decoupled control plane**  | Control plane and node pools are separate modules, similar to managed Kubernetes. This allows node pools in different regions/clouds while maintaining a stable control plane. |
| **Kubespan mesh networking** | Built-in WireGuard-based mesh network connects all nodes regardless of network topology. No VPN or peering required between clouds.                                            |
| **Immutable infrastructure** | Talos OS is API-managed, read-only, and minimal. No SSH, no shell, no package manager = reduced attack surface.                                                                |

### Deployment Model

| Layer             | Responsibility                                                                 |
| ----------------- | ------------------------------------------------------------------------------ |
| Control plane     | Stable Talos control plane nodes, API load balancer, machine secrets, kubeconfig |
| Node pools        | Replaceable worker capacity for application workloads                          |
| Cloud integrations | Optional provider-specific controllers, storage drivers, load balancers       |
| Kubespan          | Encrypted node mesh for hybrid and cross-network connectivity                  |

## Supported Cloud Providers

| Provider   | Control Plane | Node Pools | Status                |
| ---------- | ------------- | ---------- | --------------------- |
| **AWS**    | ✅            | ✅         | Production-ready      |
| **GCP**    | ✅            | ✅         | Production-ready      |
| Azure      | ❌            | ❌         | Contributions welcome |
| Bare Metal | ❌            | ❌         | Contributions welcome |

## Prerequisites

### Requirements

| Tool                                                                            | Version  | Purpose                                |
| ------------------------------------------------------------------------------- | -------- | -------------------------------------- |
| [Terraform](https://www.terraform.io/downloads)                                 | >= 1.13.0 | Infrastructure provisioning           |
| [talosctl](https://www.talos.dev/latest/introduction/getting-started/#talosctl) | >= 1.6.0 | Talos cluster management               |
| [kubectl](https://kubernetes.io/docs/tasks/tools/)                              | >= 1.28  | Kubernetes management                  |
| [OpenSSL](https://www.openssl.org/)                                             | Any      | Required for IRSA key generation (AWS) |

This repository includes a [.mise.toml](./.mise.toml) file for local tool versions. If you use [mise](https://mise.jdx.dev/), run:

```bash
mise trust
mise install
```

## Quick Start

Choose the example closest to your target cloud, review its README, and create a Terraform plan:

```bash
cd examples/hybrid-aws
terraform init
terraform plan -out=tfplan
```

For GCP:

```bash
cd examples/hybrid-gcp
terraform init
terraform plan -out=tfplan
```

Review the plan before applying it. The examples create real cloud infrastructure and require provider credentials for the selected cloud.

## Modules

### Control Plane Modules

| Module                                           | Description                                                         | Documentation                                   |
| ------------------------------------------------ | ------------------------------------------------------------------- | ----------------------------------------------- |
| [control-plane/aws](./modules/control-plane/aws) | AWS control plane with NLB, IRSA support, and CloudWatch monitoring | [README](./modules/control-plane/aws/README.md) |
| [control-plane/gcp](./modules/control-plane/gcp) | GCP control plane with regional MIG and external load balancer      | [README](./modules/control-plane/gcp/README.md) |

### Node Pool Modules

| Module                                     | Description                                                                | Documentation                                |
| ------------------------------------------ | -------------------------------------------------------------------------- | -------------------------------------------- |
| [node-pools/aws](./modules/node-pools/aws) | AWS worker nodes with ASG, rolling updates, and Cluster Autoscaler support | [README](./modules/node-pools/aws/README.md) |
| [node-pools/gcp](./modules/node-pools/gcp) | GCP worker nodes with regional MIG                                         | [README](./modules/node-pools/gcp/README.md) |

### Utility Modules

| Module                                         | Description                                          | Documentation                                  |
| ---------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------- |
| [cloud-images/aws](./modules/cloud-images/aws) | Lookup official Talos AMI IDs by version and region  | [README](./modules/cloud-images/aws/README.md) |
| [factory](./modules/factory)                   | Build and upload custom Talos images with extensions | [README](./modules/factory/README.md)          |

## Examples

| Example                             | Description                                                                            |
| ----------------------------------- | -------------------------------------------------------------------------------------- |
| [hybrid-aws](./examples/hybrid-aws) | Complete AWS deployment with control plane, node pools, Cilium CNI, and common add-ons |
| [hybrid-gcp](./examples/hybrid-gcp) | Complete GCP deployment with multi-region node pools                                   |

## Hybrid Deployment Guidance

For the least surprising cloud-provider behavior:

- Run the control plane and primary cloud node pool in one region of the same provider.
- Use one region per additional cloud provider.
- Use secondary-region or bare-metal workers for stateless workloads unless you have validated storage, load balancer, and autoscaler behavior.

### AWS Multi-Region Caveats

While AWS node pools can technically run in multiple regions, cloud-provider-specific components are single-region by design:

- **AWS Cloud Controller Manager** targets one region.
- **AWS EBS CSI Driver** works with regional volumes.
- **AWS Load Balancer Controller** creates load balancers in one region and VPC.
- **Cluster Autoscaler** manages Auto Scaling Groups in its configured region.

Only the primary node pool will fully use those integrations. Secondary-region AWS workers should be treated as stateless capacity unless you provide separate workload-specific handling.

If you run AWS node pools in multiple regions, disable the AWS Cloud Controller Manager node lifecycle controller. Otherwise it can delete nodes it cannot find in its configured region.

### Cross-Cloud Node Pools

Running one AWS region and one GCP region is a better fit than multiple regions of the same cloud provider. Each cloud provider integration can operate in its own region while Kubespan carries the cluster node mesh.

## Post-Deployment

### Install a CNI (Required)

The cluster ships without a CNI, but Cilium deployments are present in the example folders.

### Verify Cluster Health

```bash
# Check Talos cluster health
talosctl --talosconfig talosconfig health

# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system
```

### Access Talos API

```bash
# Generate talosconfig
terraform output -raw talosconfig > talosconfig

# List nodes
talosctl --talosconfig talosconfig get members

# View logs
talosctl --talosconfig talosconfig logs kubelet

# Dashboard (interactive)
talosctl --talosconfig talosconfig dashboard
```

## Upgrading

The module and example defaults now target Talos **v1.14.6** and Kubernetes **v1.36.6**. Terraform **1.13.0** remains the minimum supported runtime; the development toolchain uses **1.17.2**.

Kubernetes 1.36 is within the tested compatibility range of [Cilium 1.20](https://github.com/cilium/cilium/blob/v1.20.2/Documentation/network/kubernetes/compatibility.rst), supplied by the example add-on release, and the [Talos 1.14 support matrix](https://docs.siderolabs.com/talos/v1.14/getting-started/support-matrix).

For existing clusters, explicitly set `talos_version` and `kubernetes_version` to your current versions before upgrading the modules. Review the Terraform plan and follow the Talos and Kubernetes supported upgrade sequence before advancing those inputs. Updating these defaults is not a substitute for upgrading the running nodes.

The GCP modules now require Google and Google Beta providers **8.12 or newer, below 9.0**, and use VM modules **15.4 or newer, below 16.0**. The examples use Kubernetes add-ons **v1.11.0**. The AWS example keeps Kubernetes provider **3.3.x** and kubectl provider **2.x** to satisfy that add-on release's constraints. Run `terraform init -upgrade` when adopting these dependency changes and review the resulting plan before applying it.

### Upgrade Talos OS

Talos 1.14 uses [Image Factory installer images](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/lifecycle-management/upgrading-talos). Replace `<schematic-id>` with the schematic used for the node's image to preserve its system extensions. For an image without customizations, use `376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba`.

```bash
# Upgrade control plane nodes (one at a time)
talosctl --talosconfig talosconfig upgrade \
  --nodes <node-ip> \
  --image "factory.talos.dev/metal-installer/<schematic-id>:v1.14.6"

# Upgrade worker nodes
talosctl --talosconfig talosconfig upgrade \
  --nodes <worker-ip> \
  --image "factory.talos.dev/metal-installer/<schematic-id>:v1.14.6"
```

### Upgrade Kubernetes

```bash
talosctl --talosconfig talosconfig upgrade-k8s \
  --to 1.36.6
```

## Security Considerations

| Feature                 | Implementation                                                  |
| ----------------------- | --------------------------------------------------------------- |
| **No SSH**              | Talos has no SSH daemon. All management via Talos API.          |
| **Mutual TLS**          | All Talos API calls use client certificates                     |
| **Encrypted at rest**   | Enable EBS encryption via `encrypted = true`                    |
| **IRSA**                | Native AWS IAM integration for pod-level permissions (AWS only) |
| **IMDSv2**              | Enforced by default (`http_tokens = "required"`)                |
| **Kubespan encryption** | All inter-node traffic encrypted with WireGuard                 |

## Contributing

Contributions are welcome! Please read our [Contributing Guide](./.github/CONTRIBUTING.md) before submitting a PR.

### Development Setup

```bash
# Install pre-commit hooks
pre-commit install

# Run checks
pre-commit run -a
```

### Adding a New Cloud Provider

1. Create `modules/control-plane/<provider>/`
2. Create `modules/node-pools/<provider>/`
3. Add example in `examples/`
4. Update this README

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

- [Talos Linux](https://www.talos.dev/) by Sidero Labs
- [terraform-aws-modules](https://github.com/terraform-aws-modules) for AWS patterns
- [terraform-google-modules](https://github.com/terraform-google-modules) for GCP patterns
