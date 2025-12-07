# kyc-aml-automation-iac
This repository contains Terraform and GitHub Actions configuration to provision a Google Cloud Platform (GCP) developer VM and related networking for the KYC‑AML automation solution.

**Purpose:** bring up a single VM (developer workstation) with common developer tooling installed using a startup script, and manage lifecycle with Terraform. The repository includes a CI workflow that runs Terraform in GitHub Actions.

**Guardrail:** The Terraform configuration is written to avoid creating duplicate VMs with the same name — the workflow and variables should be used consistently and existing instances should be imported into Terraform state when appropriate.

---

**Contents**
- `terraform/` — Terraform code (providers, variables, main resources, outputs, startup script)
- `.github/workflows/terraform-apply.yml` — GitHub Actions workflow that runs `terraform init` and `terraform apply` for `main` branch or manual dispatch

**High-level resources created**
- VPC default network (uses existing default network)
- Firewall rules for SSH and HTTP/HTTPS (configurable `source_ranges`)
- A single `google_compute_instance` VM with a startup script that installs developer tooling (Python, pip, venv, git, Docker, Docker Compose plugin, build tools, curl/wget; optional Tesseract)

**Startup script**
- `terraform/startup.sh` is executed by the instance on first boot. It installs packages idempotently and non‑interactively, adds common users to the `docker` group, configures UFW, and enables services.
- To enable optional Tesseract OCR installation, pass metadata/variable `INSTALL_TESSERACT=1` (see Variables section).
- Use a secured SSH entry point (Cloud IAP, bastion host, or a narrow IP allowlist) instead of exposing SSH to the internet.

---

**Provisioned Software**
The VM startup script installs a set of developer tools and runtime dependencies to make the instance a usable developer workstation. The table below summarizes what is provisioned and why.

| Package / Component | Category | Why |
|---|---|---|
| `python3`, `pip3` | Base tooling | Run Python applications and install Python packages |
| `python3-venv` | Base tooling | Create isolated Python virtual environments |
| `git` | Dev support | Clone and manage source repositories |
| `docker` (engine) | Deployment | Build, run and test containers locally |
| `docker compose` (CLI plugin) | Deployment | Orchestrate multi-container apps and microservices |
| `tesseract-ocr` (optional) | System dependency | OCR support for image-to-text processing (installable via metadata flag) |
| `build-essential` | Dev support | Compiler toolchain for building native Python extensions and C/C++ dependencies (e.g., numpy) |
| `curl`, `wget` | Base tools | Fetch remote installers and assets |
| `nginx` | Web server / reverse proxy | Optional static hosting / reverse proxy for local services |
| `ufw`, `fail2ban`, `unattended-upgrades` | Security & hardening | Basic host firewall, brute-force protection and auto-updates |


**Variables & how to set them**
- `terraform/variables.tf` defines the variables used by the configuration. Important variables:
	- `project_id` — GCP project id (default: `kyc-aml-automation` in this repo)
	- `region`, `zone` — GCP location values
        - `vm_name` — name of the compute instance
        - `machine_type` — VM machine type
- `allowed_ssh_source_ranges` — CIDRs allowed to reach SSH. Defaults include the Cloud IAP TCP forwarding range `35.235.240.0/20` **and** Cloud Shell egress `35.235.0.0/16` so you can connect either with `gcloud compute ssh --tunnel-through-iap` or directly from Cloud Shell without editing CIDRs. Adjust to add your admin CIDRs and keep personal IPs in a local `terraform.tfvars` (do not change the repository default). `0.0.0.0/0` is rejected unless you set `allowed_ssh_worldwide_override=true`.
- `allowed_ssh_worldwide_override` — opt-out flag to permit `0.0.0.0/0` in `allowed_ssh_source_ranges` for exceptional cases.
- `allowed_web_source_ranges` — lists of CIDRs allowed to reach HTTP/HTTPS (default: `0.0.0.0/0`).
- `instance_metadata` — optional metadata map you can provide; add `{ INSTALL_TESSERACT = "1" }` to install Tesseract via startup script

**Handling laptops or locations with changing IPs**
- Prefer Cloud IAP (identity-aware proxy) or a bastion host with a static egress IP so you do not have to open SSH to the internet. The default `allowed_ssh_source_ranges` already allows the Cloud IAP TCP forwarding range, so connect with `gcloud compute ssh --tunnel-through-iap`. If you are in Cloud Shell, you can also connect directly without extra flags because the Cloud Shell egress range `35.235.0.0/16` is allowlisted by default.
- If you must connect directly and your ISP IP changes, add your current public IP as a `/32` in `allowed_ssh_source_ranges` before each session (e.g., update `terraform.tfvars` with the latest `curl ifconfig.me` or a trusted IP lookup site such as https://whatismyipaddress.com/). Avoid committing personal IPs to version control; keep them in local `terraform.tfvars`.
- If your IP changes frequently, prefer Cloud IAP or use a VPN with a stable egress address so you can allowlist the VPN’s CIDR once and connect through it from wherever you are.

Set variables by one of the methods below (local or CI):
- `terraform.tfvars` file in the `terraform/` directory (recommended for local convenience; do not commit secrets)
- Environment variables: `TF_VAR_project_id`, `TF_VAR_vm_name`, etc.
- Command line: `terraform apply -var 'project_id=...'`

**Example local `terraform.tfvars` (do NOT commit secrets):**
```hcl
project_id = "my-gcp-project"
region = "us-central1"
zone = "us-central1-a"
vm_name = "kyc-onboarding-vm"
machine_type = "e2-micro"
allowed_ssh_source_ranges = ["203.0.113.5/32"]
instance_metadata = { INSTALL_TESSERACT = "1" }
```

---

**CI / GitHub Actions**
- The workflow file is at `.github/workflows/terraform-apply.yml`. It is triggered on `push` to `main` and by manual dispatch.
- Required repository secrets for the workflow:
	- `GCP_SERVICE_ACCOUNT` — Service account JSON used by `google-github-actions/auth` and Terraform provider
	- `GCP_PROJECT_ID` — The project id (used to populate `TF_VAR_project_id`)

Notes:
- Ensure the service account has the required IAM roles (compute admin, compute.networkAdmin, compute.securityAdmin, or a narrower set with compute.instances.create/list/get and firewall privileges).
- The workflow sets `GOOGLE_CREDENTIALS` and `TF_VAR_*` env variables before running Terraform.

---

**Security & production recommendations**
- Do NOT leave `allowed_ssh_source_ranges` as `0.0.0.0/0` for production. Limit SSH to admin IPs or use Cloud IAP / bastion host.
- The Terraform variable validation rejects `0.0.0.0/0` for SSH by default; if you must temporarily allow it, set `allowed_ssh_worldwide_override=true` explicitly.
- Consider removing `prevent_destroy` lifecycle only if you intend to allow destroy operations in CI.
- Use Terraform import to bring existing VMs into state instead of letting the configuration create duplicates. Example:
        ```bash
	terraform import google_compute_instance.vm projects/<project-id>/zones/<zone>/instances/<name>
	```

---

**How to run locally**
1. Install Terraform (>= 1.5.0) and `gcloud` CLI.
2. Authenticate locally (recommended) using:
	 ```bash
	 gcloud auth login
	 gcloud auth application-default login
	 ```
3. Create `terraform/terraform.tfvars` or export `TF_VAR_project_id` env var.
4. From `terraform/` directory:
	 ```bash
	 terraform init
	 terraform plan
	 terraform apply -auto-approve
	 ```

**Helpful tips**
- If the run fails because `project` or other variables are empty, confirm `TF_VAR_*` env vars or `terraform.tfvars` provide values; Terraform will use default values only if not overridden by env/CLI.
- To avoid accidental applies from CI, consider changing the workflow to run `plan` on PRs and `apply` only on merges to `main` or manual dispatch.

---

If you'd like, I can also add a short `terraform.tfvars.example` file, a README section with commands for importing existing instances into Terraform state, and a validation rule to prevent insecure defaults for `allowed_ssh_source_ranges`.
