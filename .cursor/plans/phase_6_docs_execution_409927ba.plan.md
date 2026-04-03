---
name: Phase 6 Docs Execution
overview: "Comprehensive execution plan for Phase 6 (Documentation and Future Work) of the Melio IaC assessment. Creates a feature branch, audits Phases 1-5 implementation, then writes production-quality documentation across 4 files: README.md (appended), docs/architecture.md, docs/trade-offs.md, and docs/future-work.md."
todos:
  - id: create-branch
    content: Create feature/phase-6-docs branch from Feature/Iac-implementation (ensure Phases 1-5 complete)
    status: pending
  - id: audit-p1-p5
    content: "Audit Phases 1-5 implementation: verify all modules, scripts, outputs match master plan; document discrepancies"
    status: pending
  - id: write-readme
    content: "Append infrastructure deployment sections to README.md (12 sections: story refinement, prerequisites, quick start, variables, architecture, secrets, verification, limitations, teardown, cost, further reading)"
    status: pending
  - id: write-architecture
    content: Replace all HTML comment placeholders in docs/architecture.md with full content (overview, comprehensive mermaid diagram, services, networking, security model, data flow, boot sequence)
    status: pending
  - id: write-tradeoffs
    content: Fill all 7 trade-off records in docs/trade-offs.md with structured decision records + add 2 new decisions (Docker build, nginx proxy)
    status: pending
  - id: write-futurework
    content: Fill all 9 future-work items in docs/future-work.md with substantive descriptions, priority labels, and implementation notes
    status: pending
  - id: validate-commit
    content: Verify markdown rendering (mermaid, tables, links), run terraform fmt/validate if needed, commit with 'docs:' prefix, push branch
    status: pending
isProject: false
---

# Phase 6: Documentation and Future Work -- Execution Plan

## Pre-Execution: Branch and Audit

### Step 0.1 -- Create Feature Branch

```bash
git checkout Feature/Iac-implementation
git pull origin Feature/Iac-implementation
git checkout -b feature/phase-6-docs
```

Branch from `Feature/Iac-implementation` (which should contain completed Phases 1-5).

### Step 0.2 -- Audit Phases 1-5 Implementation

Before writing docs, validate that the infrastructure code matches the master plan. Check for alignment issues across all modules. This is a **quality gate** -- docs must accurately reflect what was built.

**Audit checklist:**

- **Bootstrap** ([terraform/bootstrap/main.tf](terraform/bootstrap/main.tf)): S3 state bucket (versioned, encrypted, native S3 locking), S3 artifact bucket -- all in af-south-1
- **Root Terraform**: [terraform/providers.tf](terraform/providers.tf) has AWS `~> 6.0` with `default_tags`, [terraform/backend.tf](terraform/backend.tf) points to S3 state bucket, [terraform/variables.tf](terraform/variables.tf) has `region`, `project_name`, `environment`, `instance_type`, `aws_profile`, `ssh_cidr`
- **Networking** ([terraform/modules/networking/](terraform/modules/networking/)): VPC `10.0.0.0/16`, 2 public subnets (af-south-1a `10.0.1.0/24`, af-south-1b `10.0.2.0/24`), IGW, route tables
- **Security** ([terraform/modules/security/](terraform/modules/security/)): 4 SGs (alb, frontend, backend, ssh), IAM role with S3+SSM policies, instance profile, SSM parameter
- **Compute** ([terraform/modules/compute/](terraform/modules/compute/)): 3 EC2 t3.small (AL2023), user data templates (frontend.sh.tpl, quotes.sh.tpl, newsfeed.sh.tpl, nginx.conf.tpl), key pair
- **ALB** ([terraform/modules/alb/](terraform/modules/alb/)): ALB in 2 AZs, target group port 80, health check GET /ping on port 80, HTTP listener
- **Scripts** ([scripts/](scripts/)): build-docker.sh, build-local.sh, deploy.sh, teardown.sh, Dockerfile.build
- **Outputs** ([terraform/outputs.tf](terraform/outputs.tf)): ALB DNS, instance IPs, SSH key path

**If discrepancies are found**: Document them in the plan file, fix critical issues on this branch, and note corrections in trade-offs.md. Minor naming differences are acceptable; structural/architectural deviations are not.

---

## File 1: README.md (Append Below Original Content)

Keep all original content (lines 1-60) intact. Append a horizontal rule `---` followed by the new infrastructure deployment documentation.

### Sections to Append (in order):

**1. Infrastructure Deployment (heading)**

Brief intro: "This section documents the AWS infrastructure-as-code (Terraform) deployment of the 3-service Clojure MVP to AWS af-south-1 (Cape Town)."

**2. Story Refinement**

This is a **scored assessment criterion**. Include:
- The original user story (quoted)
- Refined scope (bulleted: single region, HTTP only, public subnets, no CI/CD, no monitoring, cleanup included)
- Out of scope items (cross-reference to [docs/future-work.md](docs/future-work.md))

**3. Prerequisites**

Bulleted list:
- Terraform >= 1.9 (tested with v1.14.8)
- AWS CLI v2
- Docker Desktop (primary build method) OR Java 17 + Leiningen 2.12
- AWS profile `charteracademy` with af-south-1 region enabled
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`

**4. Quick Start**

Numbered step-by-step commands:
1. Bootstrap (state + artifact bucket): `cd terraform/bootstrap && terraform init && terraform apply`
2. Build JARs: `./scripts/build-docker.sh`
3. Upload artifacts: `./scripts/deploy.sh`
4. Deploy infrastructure: `cd terraform && terraform init && terraform apply`
5. Wait 2-3 min, then open ALB DNS URL from terraform output

**5. Terraform Variables**

Table format referencing [terraform/terraform.tfvars.example](terraform/terraform.tfvars.example):
- `region` (default: af-south-1)
- `project_name` (default: melio-devops)
- `environment` (default: dev)
- `instance_type` (default: t3.small)
- `aws_profile` (default: charteracademy)
- `ssh_cidr` (optional, default: none)

**6. Architecture**

Embed the comprehensive mermaid diagram from the master plan (the full version with S3, SSM, IGW, nginx detail on FE, port annotations on all services). Link to [docs/architecture.md](docs/architecture.md) for detailed description.

**7. Secrets Handling**

Explain:
- `NEWSFEED_SERVICE_TOKEN` stored in SSM Parameter Store (SecureString)
- Read at boot via IAM role attached to instance profile
- Never in `.tf` files or `terraform.tfvars`
- Note: token value is in application source code (`newsfeed/core.clj`) -- SSM demonstrates the production-correct pattern

**8. Verification**

Commands:
- `curl -s http://$(terraform output -raw alb_dns_name)/ping` -- expect HTTP 200
- Open ALB DNS in browser -- verify quotes sidebar + newsfeed list
- Note: newsfeed may show partial/empty results due to af-south-1 to US RSS latency (~250-350ms)

**9. Known Limitations**

Bulleted:
- RSS feed latency from af-south-1 (partial/empty newsfeed results)
- Boot timing (frontend may start before backends; refresh after 30-60s)
- No HA (single instance per service, single AZ for compute)
- HTTP only (no TLS)

**10. Teardown**

`./scripts/teardown.sh` -- describe what it does (terraform destroy for main + bootstrap, verify no lingering resources). Note `prevent_destroy` on state bucket is removed during teardown.

**11. Cost Estimate**

Table with af-south-1 rates for a 2-3 hour demo (~$0.23 total).

**12. Further Reading**

Links to:
- [docs/architecture.md](docs/architecture.md) -- Detailed architecture
- [docs/trade-offs.md](docs/trade-offs.md) -- Design decisions and rationale
- [docs/future-work.md](docs/future-work.md) -- Production improvements

---

## File 2: docs/architecture.md (Full Rewrite)

Replace all HTML comment placeholders with substantive content. Keep the existing section structure but fill every section.

### Section Content:

**Overview**: 3-service Clojure MVP (frontend, quotes, newsfeed) deployed to AWS af-south-1 on 3 EC2 instances (t3.small, AL2023) with an ALB. Frontend uses nginx as reverse proxy. Artifacts stored in S3, secrets in SSM.

**Architecture Diagram**: Replace simplified mermaid with the comprehensive version from the master plan (includes S3State, DDB, SSM, IGW, nginx:80 detail, port annotations, artifact pull dotted lines, RSS outbound).

**Services**:
- **Frontend**: nginx on port 80 proxies to frontend.jar on 8080. Serves static CSS at `/css/*` via nginx alias. Reads NEWSFEED_SERVICE_TOKEN from SSM at boot. Communicates with quotes (8082) and newsfeed (8083) via private IPs.
- **Quotes**: Standalone JAR on port 8082. Serves random quotes from embedded quotes.json. No external dependencies.
- **Newsfeed**: Standalone JAR on port 8083. Aggregates RSS feeds from external sources (Reddit, HN, etc.). Requires auth token. Subject to latency from af-south-1.

**Networking**: VPC `10.0.0.0/16` with 2 public subnets. All 3 EC2s in subnet-a (af-south-1a). ALB spans both subnets (AWS 2-AZ requirement). IGW + route tables for internet access. No NAT gateway needed (public subnets).

**Security Model**:
- Reproduce the SG matrix from the master plan (alb-sg, frontend-sg, backend-sg rules)
- IAM role with scoped S3 GetObject + SSM GetParameter policies
- Instance profile shared by all 3 instances
- Optional SSH via `ssh_cidr` variable (defaults to disabled)

**Data Flow**: End-to-end: Internet -> ALB:80 -> nginx:80 -> frontend.jar:8080 -> quotes:8082 / newsfeed:8083. At boot: EC2 user data pulls JARs from S3 with retry, installs Corretto 17, starts systemd services.

**EC2 Boot Sequence** (new section): Document the user data flow: set -euxo pipefail -> dnf install -> S3 artifact pull with retry -> systemd unit creation -> (frontend: nginx install + config) -> SSM secret read (frontend only) -> service start.

---

## File 3: docs/trade-offs.md (Fill Placeholders)

Replace all HTML comments with structured decision records. Keep the existing format header ("Decision / Options Considered / Chosen / Rationale").

Each of the 7 existing sections gets filled:

1. **af-south-1 Region Selection**: Options: af-south-1 vs us-east-1. Chosen: af-south-1. Rationale: assessment context. Consequence: RSS latency ~250-350ms to US feeds, 1s timeout in newsfeed/api.clj means partial results. Acceptable for dev/test.

2. **Public Subnets for All Instances**: Options: public vs private+NAT. Chosen: public. Rationale: simplicity within 4-hour time constraint. Mitigation: SGs enforce port-level access. Future: private subnets documented.

3. **All Instances in Same AZ**: Options: spread vs single AZ. Chosen: single AZ (af-south-1a). Rationale: eliminates cross-AZ latency for frontend-to-backend calls, simplifies debugging. ALB still spans both subnets.

4. **SSM for Token**: Options: hardcode in user data vs SSM. Chosen: SSM. Rationale: production-correct pattern. Note: token is in source code (newsfeed/core.clj) -- SSM is for demonstrating the pattern, not actual security.

5. **Remote State in af-south-1**: Options: af-south-1 vs us-east-1 for state bucket. Chosen: af-south-1. Rationale: co-located with infra, simpler. Trade-off: if region has issues, state is also inaccessible.

6. **t3.small Instance Type**: Options: t3.micro (1 GiB) vs t3.small (2 GiB) vs t3.medium (4 GiB). Chosen: t3.small. Rationale: comfortable headroom for JVM (heap bounded to 512m) + OS + nginx. t3.micro risks OOM; t3.medium is over-provisioned.

7. **HTTP Only (No TLS)**: Options: HTTP vs HTTPS with ACM. Chosen: HTTP. Rationale: sufficient for dev/test verification. ACM + HTTPS listener documented as future work.

**Add 2 new decisions** (not in template but important):

8. **Docker-based Build (Primary)**: Options: local Java/Lein vs Docker build. Chosen: Docker primary, local fallback. Rationale: reproducible builds with no host-side JDK/Lein dependency.

9. **nginx Reverse Proxy on Frontend**: Options: serve directly from JVM on port 80 vs nginx reverse proxy. Chosen: nginx. Rationale: production-standard pattern; serves static CSS efficiently; separates concerns.

---

## File 4: docs/future-work.md (Fill Placeholders)

Replace HTML comments with substantive descriptions. Add priority labels and brief implementation notes for each item.

### Items (prioritized):

1. **Multi-AZ with Auto Scaling Groups** [High Priority]
   - ASG per service, min 2 instances across af-south-1a and af-south-1b
   - Launch template from current EC2 config
   - ALB target group already supports multiple targets
   - Eliminates single-instance SPOF

2. **Private Subnets + NAT Gateway** [High Priority]
   - Move backend instances (quotes, newsfeed) to private subnets
   - NAT gateway in public subnet for outbound (RSS feeds, S3, SSM)
   - Frontend stays in public subnet (ALB target)
   - Cost: ~$32/month per NAT gateway

3. **TLS Termination (ACM)** [High Priority]
   - ACM certificate on ALB
   - HTTPS listener on port 443
   - HTTP -> HTTPS redirect rule
   - Requires a registered domain name

4. **CI/CD Pipeline** [Medium Priority]
   - GitHub Actions: build (Docker) -> test -> upload artifacts to S3 -> terraform plan -> manual approve -> terraform apply
   - Branch protection on main
   - Separate workflows for infra (Terraform) and app (build/deploy)

5. **Monitoring and Alerting** [Medium Priority]
   - CloudWatch alarms: CPU, memory (custom metric via CloudWatch agent), health check failures
   - CloudWatch Logs agent for application logs (journald -> CloudWatch)
   - Alternative: Prometheus + Grafana stack

6. **WAF / GuardDuty / AWS Config** [Medium Priority]
   - WAF on ALB for common web attack protection (SQLi, XSS)
   - GuardDuty for threat detection
   - AWS Config rules for compliance (e.g., all resources tagged, SGs not open to 0.0.0.0/0 on all ports)

7. **Multi-Environment Layout** [Low Priority]
   - Terraform workspaces or directory-per-env (dev, staging, production)
   - Separate tfvars per environment
   - Promotion pipeline: dev -> staging -> prod

8. **Container Migration (ECS/EKS)** [Low Priority]
   - Dockerfile per service (simple: FROM amazoncorretto:17, COPY jar, ENTRYPOINT java -jar)
   - ECS Fargate: no EC2 management, per-task IAM roles
   - EKS: for teams already using Kubernetes

9. **SSM Session Manager** [Low Priority]
   - Replace direct SSH with Session Manager
   - Audited, keyless access via IAM
   - Remove SSH security group rules entirely
   - Cost: free with existing IAM role

---

## Commit and Branch Strategy

### Single Commit

```
docs: add comprehensive README, architecture, and future work documentation
```

Conventional commit format per [.cursor/rules/project.mdc](.cursor/rules/project.mdc).

### Post-Commit

- Run `terraform fmt` and `terraform validate` (if any .tf files were touched -- unlikely for Phase 6 but verify)
- Verify markdown renders correctly (mermaid diagrams, tables, links)
- Push branch: `git push -u origin feature/phase-6-docs`

---

## Potential Issues and Mitigations

- **Stale content**: If Phases 1-5 deviated from the master plan, docs will be inaccurate. The Step 0.2 audit catches this.
- **Mermaid rendering**: GitHub renders mermaid natively. Verify diagram syntax is valid (no spaces in node IDs, quotes on special-char labels).
- **Secret in README**: The original README contains the token value. We do NOT repeat it in the appended sections -- we reference SSM instead. The original section stays as-is (append approach).
- **Link validation**: All cross-doc links (`docs/architecture.md`, etc.) must use relative paths that work from the repo root.
- **Table formatting**: Markdown tables must have consistent column counts. The SG matrix and variables table are the most complex.

---

## Tools and MCPs Used in Planning

- **Perplexity MCP** (`perplexity_search`): Researched Terraform IaC README documentation best practices (2026)
- **Codebase exploration subagents**: Full directory tree audit, all .tf file status, git branch/history analysis
- **Direct file reads**: All 4 target files (README.md, architecture.md, trade-offs.md, future-work.md), master plan, revised plan, cursor rules, .gitignore, Makefile, terraform.tfvars.example
- **Built-in tools**: Read, Glob, Grep, Shell (readonly), Task (explore subagents)