# Trade-offs and Decision Log

Each decision follows the format: **Decision** / Options Considered / Chosen / Rationale.

---

## af-south-1 Region Selection

**Options**: af-south-1 (Cape Town) vs us-east-1 (Virginia)
**Chosen**: af-south-1
**Rationale**: Assessment requires actual tests, use developers existing account for speed. RSS latency (~250-350ms to US) is a known limitation; the newsfeed service's hardcoded 1s timeout may cause partial results. Quotes page is unaffected.

## Public Subnets for All Instances

**Options**: Public subnets vs private subnets + NAT gateway
**Chosen**: Public subnets
**Rationale**: Simplicity within time constraint. Security groups enforce port-level access. Private subnets + NAT documented as future work.

## All Instances in Same AZ (af-south-1a)

**Options**: Spread across AZs vs single AZ
**Chosen**: Single AZ (af-south-1a)
**Rationale**: Eliminates cross-AZ latency for frontend-to-backend calls. ALB still spans 2 AZs (AWS requirement). Multi-AZ with ASG documented as future work.

## SSM for Token (Security Pattern vs Actual Secret)

**Options**: Hardcode in user data vs SSM Parameter Store
**Chosen**: SSM Parameter Store
**Rationale**: Demonstrates production-correct secrets management pattern even though the token is hardcoded in `newsfeed/core.clj` source.

## Remote State in af-south-1 (vs us-east-1)

**Decision**: S3 state bucket + DynamoDB lock table, both in af-south-1.

**Options considered**:
- S3 + DynamoDB lock table (chosen)
- S3 with native locking via `use_lockfile = true` (available in Terraform >= 1.10, stabilized in 1.11+)
- S3 without locking (risky for teams, acceptable for solo dev)

**Chosen**: S3 + DynamoDB in af-south-1.

**Rationale**:
- `use_lockfile = true` is available in Terraform >= 1.10 for native S3 locking and is the recommended approach for new projects. DynamoDB locking is officially deprecated but still functional.
- DynamoDB chosen here for explicit lock visibility and backward compatibility with existing workflows
- DynamoDB PAY_PER_REQUEST keeps cost near-zero for a demo workload
- Keeping state in the same region as infrastructure simplifies operations
- Trade-off: if af-south-1 has an outage, both infra and state are inaccessible. For a single-region dev environment, this is acceptable.

**Alternative**: Migrate to `use_lockfile = true` (removes DynamoDB dependency). Also acceptable to skip locking entirely for solo developer demos.

## Artifact Bucket: force_destroy Enabled

**Decision**: `force_destroy = true` on the S3 artifact bucket.

**Rationale**: Allows `terraform destroy` to succeed even when the bucket contains uploaded JARs and static assets. Without this, teardown would require manual bucket emptying. The state bucket intentionally omits this (`prevent_destroy = true`) to protect Terraform state from accidental deletion.

## t3.small Instance Type

**Options**: t3.micro vs t3.small vs t3.medium
**Chosen**: t3.small (2 GiB RAM)
**Rationale**: Comfortable headroom for JVM + OS. JVM heap bounded to 512m via `-Xmx512m -XX:+UseSerialGC`. t3.micro (1 GiB) risks OOM with JVM + nginx + OS overhead.

## HTTP Only (No TLS)

**Options**: HTTP only vs HTTPS with ACM
**Chosen**: HTTP only
**Rationale**: Sufficient for dev/test verification within a time-boxed demo. TLS termination at ALB with ACM certificate documented as future work.

## SSM SecureString: Default AWS Managed KMS Key

**Decision**: Use default `alias/aws/ssm` key for SSM SecureString parameter.

**Options considered**:
- Default AWS managed key (chosen)
- Customer-managed KMS key (more control over rotation/auditing)

**Chosen**: Default AWS managed key.

**Rationale**:
- Avoids creating and managing a KMS key resource
- No extra `kms:Decrypt` permission needed in the IAM policy -- instances can decrypt with just `ssm:GetParameter`
- Trade-off: less control over key rotation schedule and access auditing
- Acceptable for a time-boxed demo; customer-managed KMS documented as future improvement

## IAM Inline Policy vs Managed Policy

**Decision**: Use `aws_iam_role_policy` (inline) instead of `aws_iam_policy` + `aws_iam_role_policy_attachment`.

**Rationale**: The permissions policy is specific to the app instance role and won't be reused across roles. Inline policy simplifies the module (fewer resources) and the policy lifecycle is tied to the role. For production with multiple roles sharing policies, managed policies would be preferred.

## Terraform-Generated SSH Key Pair

**Options**: Terraform-generated TLS key vs pre-existing key vs SSM Session Manager only
**Chosen**: Terraform-generated `tls_private_key` (RSA 4096) + `aws_key_pair`
**Rationale**: Enables quick SSH debugging during demo without external key management. Private key ends up in Terraform state (unencrypted). Production should use SSM Session Manager or pre-existing keys distributed out-of-band. The `tls_private_key` resource security warning is acceptable for a time-boxed dev environment.

## ALB Health Check on Port 80 (nginx) vs Port 8080 (JVM)

**Options**: Health check on port 80 (nginx proxy) vs port 8080 (JVM direct)
**Chosen**: Port 80 (matches target group traffic port)
**Rationale**: Validates the full stack (nginx -> JVM). If nginx is down but JVM is up, health checks on 8080 would incorrectly report healthy while traffic on port 80 would fail. Checking port 80 ensures the entire request path works.

## ALB Deregistration Delay: 30s vs 300s Default

**Options**: AWS default 300s vs reduced 30s
**Chosen**: 30s
**Rationale**: Dev/demo environment prioritizes fast iteration and teardown. The 300s default is designed for graceful connection draining in production. 30s is sufficient for the in-flight request load of a dev environment.

## Target Group Attachment Inside ALB Module vs Root Module

**Options**: `aws_lb_target_group_attachment` inside ALB module vs in root `main.tf`
**Chosen**: Inside ALB module
**Rationale**: Keeps the module self-contained for a single-frontend-instance demo. For multi-instance setups (ASG), the attachment would be managed by the compute/ASG module instead.

## No ALB Access Logs or WAF

**Decision**: ALB provisioned without S3 access logging or WAF integration.
**Rationale**: No access log bucket provisioned; WAF out of scope per master plan. Both documented as future work. Acceptable for a time-boxed dev environment.

## ALB Deletion Protection Explicitly Disabled

**Decision**: `enable_deletion_protection = false` set explicitly on the ALB.
**Rationale**: Must be false for `terraform destroy` to succeed during teardown. AWS default is already false, but explicit setting prevents a future default change from breaking the teardown script.

## EnvironmentFile vs Inline Environment= in Systemd

**Options**: `EnvironmentFile=/opt/app/<service>.env` vs `Environment=` directives in unit file
**Chosen**: EnvironmentFile
**Rationale**: More robust with special characters in values (e.g., NEWSFEED_SERVICE_TOKEN contains `&`, `^`). Easier to debug on-instance via `cat /opt/app/<service>.env`. Separates runtime config from service definition.

## Artifact Bucket Name Derived from ARN

**Decision**: Extract bucket name via `replace(var.artifact_bucket_arn, "arn:aws:s3:::", "")` in locals.
**Rationale**: Root module already has `artifact_bucket_arn` (from bootstrap). User data scripts need the bucket name for `aws s3 cp`. Deriving from ARN avoids adding a second variable and keeps the tfvars interface minimal. Trade-off: fragile if ARN format changes (extremely unlikely for S3).

## Service Ports as Compute-Module Locals (Not Variables)

**Options**: Configurable port variables on the compute module vs fixed locals
**Chosen**: Fixed locals in `compute/main.tf` (frontend=8080, quotes=8082, newsfeed=8083)
**Rationale**: The security module hardcodes these ports in its ingress rules. Exposing them as configurable variables on the compute module creates a hidden coupling -- changing a port default would silently break security group rules. Locking ports as locals prevents drift. If ports need to change in the future, both modules must be updated together.

## Nginx `default_server` Directive on AL2023

**Options**: `listen 80;` vs `listen 80 default_server;` in custom nginx config
**Chosen**: `listen 80 default_server;`
**Rationale**: AL2023's default nginx installation may include a server block listening on port 80 inside `/etc/nginx/nginx.conf`. Without `default_server`, the default nginx server takes priority (first-loaded wins) and serves requests from `/usr/share/nginx/html/` instead of proxying to the JVM. This would cause ALB health checks on `/ping` to receive 404 instead of 200, preventing the target from becoming healthy. Adding `default_server` explicitly claims priority regardless of load order. Harmless if the default server doesn't exist; essential if it does.

## IMDSv2 Not Enforced

**Options**: Default IMDS (v1 + v2) vs enforced IMDSv2 (`http_tokens = "required"`)
**Chosen**: Default (both v1 and v2 allowed)
**Rationale**: Enforcing IMDSv2 is a security best practice that mitigates SSRF-based credential theft. However, for a time-boxed demo with no sensitive workloads, the default is acceptable. Production deployments should set `metadata_options { http_tokens = "required" }` on all EC2 instances.

## Docker-based Build (Primary Build Method)

**Options**: Local Java 17 + Leiningen install vs Docker-based build container
**Chosen**: Docker as primary (`scripts/build-docker.sh`), local as fallback (`scripts/build-local.sh`)
**Rationale**: Docker build uses `clojure:temurin-17-lein` image which bundles JDK 17 and Leiningen 2.12.0. Eliminates host-side JDK/Lein version drift and "works on my machine" issues. The Makefile requires `make libs` before `make clean all` (the `all` target does NOT invoke `libs`); both build scripts enforce this ordering. Trade-off: Docker Desktop is a ~4GB dependency, but it's commonly pre-installed on dev machines.

## JAXB API Dependency for JDK 17 Compatibility

**Options**: Use JDK 8 for build+runtime vs add `javax.xml.bind/jaxb-api "2.3.1"` to all three project.clj files vs upgrade http-kit to 2.3.0+
**Chosen**: Add `javax.xml.bind/jaxb-api "2.3.1"` dependency
**Rationale**: `http-kit 2.1.18` uses `javax.xml.bind.DatatypeConverter` for base64 encoding, which was removed in JDK 11+. Adding the JAXB API as an explicit dependency is the most minimal fix -- it keeps JDK 17 everywhere (build + runtime), doesn't require upgrading http-kit (which could introduce regressions), and the JAXB jar is included in the uberjar for runtime availability.

## nginx Reverse Proxy on Frontend EC2

**Options**: Serve directly from JVM on port 80 vs nginx as reverse proxy on port 80
**Chosen**: nginx reverse proxy
**Rationale**: Production-standard pattern that separates concerns. nginx serves static CSS at `/css/*` efficiently (with caching headers) without JVM overhead. Proxies dynamic requests to `127.0.0.1:8080`. `STATIC_URL=""` means the Clojure templates emit relative `/css/...` paths that nginx intercepts. Also provides connection buffering, request queuing, and a layer of isolation between the internet-facing port and the JVM. The `listen 80 default_server` directive ensures our config takes priority over AL2023's default nginx server block.
