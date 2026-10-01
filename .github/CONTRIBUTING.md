# Contributing to terraform-talos-cluster

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

Please be respectful and constructive in all interactions. We're building something useful together.

## How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue templates** when available
3. **Provide context**: Terraform version, Talos version, cloud provider, error messages

### Pull Request Process

#### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/terraform-talos-cluster.git
cd terraform-talos-cluster
```

#### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

#### 3. Make Your Changes

- Follow existing code patterns and conventions
- Add/update documentation as needed
- Add examples if introducing new features

#### 4. Run Pre-Commit Checks

```bash
# Install pre-commit (one-time)
pip install pre-commit
pre-commit install

# Run checks
pre-commit run -a
```

This will run:
- `terraform fmt` - Code formatting
- `terraform-docs` - Documentation generation
- `tflint` - Linting
- Various other checks

#### 5. Commit Your Changes

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

| Prefix | Use for |
|--------|---------|
| `feat:` | New features |
| `fix:` | Bug fixes |
| `docs:` | Documentation only |
| `refactor:` | Code restructuring without behavior change |
| `test:` | Adding or updating tests |
| `ci:` | CI/CD changes |
| `chore:` | Maintenance tasks |

Examples:
```bash
git commit -m "feat: add Azure control-plane module"
git commit -m "fix: correct security group rule for Kubespan"
git commit -m "docs: improve AWS module examples"
```

#### 6. Submit Pull Request

1. Push your branch to your fork
2. Open a Pull Request against `main`
3. Fill out the PR template
4. Wait for CI checks to pass
5. Address any review feedback

### Dependency Updates and Automatic Merging

Renovate opens dependency PRs and adds update labels. Mergify handles approval and
merging, so Renovate's `automerge` and `platformAutomerge` settings stay disabled.

- GitHub Actions, mise tools, and pre-commit hooks receive `automerge-candidate`
  for minor, patch, digest, and digest-pinning updates.
- Terraform provider/module updates and major updates require human approval.
- Mergify approves eligible Renovate PRs only after `Pre-commit checks` and
  `Validate PR title` succeed. The pre-commit check requires directory discovery,
  the entire minimum-Terraform matrix, and maximum-Terraform checks to pass.
- Drafts, requested changes, and `do-not-merge` block automatic approval and
  merging. Removing `automerge-candidate`, or adding `update-major` or
  `breaking-change`, blocks merging through the Renovate rule. The general merge
  rule requires a human approval, so an earlier bot approval cannot bypass this.
- Approved PRs are squash-merged into `main`. PRs into `release` require the same
  checks and a human approval, and use rebase to retain individual commit messages.

To enforce CI for manual merges too, configure the GitHub ruleset for `main` and
`release` to require `Pre-commit checks` and `Validate PR title` from GitHub Actions
after these checks have run on each branch. Keep the existing approval requirement;
Mergify supplies that approval for eligible Renovate updates.

## Development Guidelines

### Module Structure

Each module should follow this structure:

```
modules/<type>/<provider>/
├── README.md           # Module documentation
├── main.tf             # Primary resources
├── variables.tf        # Input variables
├── outputs.tf          # Output values
├── versions.tf         # Provider requirements
└── *.tf                # Additional resource files
```

### Documentation Standards

#### README.md

Every module README should include:

1. **Title and description** - What the module does
2. **Usage example** - Minimal working example
3. **Inputs table** - All variables with descriptions
4. **Outputs table** - All outputs with descriptions
5. **Requirements** - Provider versions, dependencies

Use `terraform-docs` markers for auto-generated sections:
```markdown
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

#### Variables

Always include:
- `description` - Clear explanation of the variable's purpose
- `type` - Explicit type constraint
- `default` - When appropriate, with sensible defaults
- `validation` - Input validation blocks for critical variables

```hcl
variable "cluster_name" {
  description = "Name of the Talos cluster. Used as prefix for all resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}
```

#### Outputs

Always include `description`:

```hcl
output "kubernetes_api_url" {
  description = "Full URL for the Kubernetes API endpoint"
  value       = "https://${aws_lb.control_plane.dns_name}:6443"
}
```

### Code Style

#### Formatting

- Run `terraform fmt` before committing
- Use 2-space indentation (Terraform default)
- Keep lines under 120 characters when possible

#### Naming Conventions

| Item | Convention | Example |
|------|------------|---------|
| Resources | `snake_case` | `aws_instance.control_plane` |
| Variables | `snake_case` | `cluster_name` |
| Outputs | `snake_case` | `kubernetes_api_url` |
| Locals | `snake_case` | `control_plane_nodes` |
| Files | `kebab-case.tf` | `load-balancer.tf` |

#### Resource Organization

Group related resources in dedicated files:
- `main.tf` - Primary compute resources
- `networking.tf` or `security-groups.tf` - Network resources
- `iam.tf` - IAM roles and policies
- `outputs.tf` - All outputs
- `variables.tf` - All variables
- `versions.tf` - Provider requirements
- `locals.tf` - Local values

### Testing

Currently, testing is manual. When contributing:

1. Test your changes with a real deployment
2. Verify both `terraform plan` and `terraform apply` work
3. Test destruction with `terraform destroy`
4. Document any manual testing performed in the PR

### Adding a New Cloud Provider

To add support for a new cloud provider (e.g., Azure):

1. **Create module directories**:
   ```
   modules/control-plane/azure/
   modules/node-pools/azure/
   modules/cloud-images/azure/  # If applicable
   ```

2. **Follow existing patterns**:
   - Study the AWS and GCP modules
   - Use similar variable structures
   - Maintain consistent output naming

3. **Required features**:
   - Control plane with load balancer
   - Kubespan networking enabled
   - Talos machine configuration
   - Bootstrap automation

4. **Add an example**:
   ```
   examples/hybrid-azure/
   ```

5. **Update documentation**:
   - Update root README.md
   - Add module README.md files
   - Update supported providers table

## Semantic Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to module interfaces
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

Breaking changes include:
- Removing or renaming variables
- Changing variable types
- Removing outputs
- Changing default behavior significantly

## Questions?

- Open a [Discussion](https://github.com/shardlabsxyz/terraform-talos-cluster/discussions)
- Check existing [Issues](https://github.com/shardlabsxyz/terraform-talos-cluster/issues)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
