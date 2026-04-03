# Trade-offs and Decision Log

Each decision follows the format: **Decision** / Options Considered / Chosen / Rationale.

---

## af-south-1 Region Selection

<!-- Options: af-south-1 (Cape Town) vs us-east-1 (Virginia) -->
<!-- Chosen: af-south-1 -->
<!-- Rationale: Assessment requirement; RSS latency (~250-350ms to US) is a known limitation -->

## Public Subnets for All Instances

<!-- Options: Public subnets vs private subnets + NAT gateway -->
<!-- Chosen: Public subnets -->
<!-- Rationale: Simplicity within time constraint; security groups enforce port-level access -->

## All Instances in Same AZ (af-south-1a)

<!-- Options: Spread across AZs vs single AZ -->
<!-- Chosen: Single AZ (af-south-1a) -->
<!-- Rationale: Eliminates cross-AZ latency; ALB still spans 2 AZs (AWS requirement) -->

## SSM for Token (Security Pattern vs Actual Secret)

<!-- Options: Hardcode in user data vs SSM Parameter Store -->
<!-- Chosen: SSM Parameter Store -->
<!-- Rationale: Demonstrates production-correct pattern even though token is in source code -->

## Remote State in af-south-1 (vs us-east-1)

**Decision**: S3 state bucket + DynamoDB lock table, both in af-south-1.

**Options considered**:
- S3 + DynamoDB lock table (chosen)
- S3 with native locking via `use_lockfile` (OpenTofu only -- NOT available in HashiCorp Terraform)
- S3 without locking (risky for teams, acceptable for solo dev)

**Chosen**: S3 + DynamoDB in af-south-1.

**Rationale**:
- `use_lockfile = true` is an **OpenTofu-only feature** (v1.10+), widely misattributed to HashiCorp Terraform in blog posts. Verified via official HashiCorp GitHub releases -- no such parameter exists in Terraform v1.14.8 or any prior version.
- DynamoDB PAY_PER_REQUEST keeps cost near-zero for a demo workload
- Keeping state in the same region as infrastructure simplifies operations
- Trade-off: if af-south-1 has an outage, both infra and state are inaccessible. For a single-region dev environment, this is acceptable.

**Alternative**: Skip locking entirely (omit `dynamodb_table`) -- acceptable for solo developer demos but NOT for team environments.

## Artifact Bucket: force_destroy Enabled

**Decision**: `force_destroy = true` on the S3 artifact bucket.

**Rationale**: Allows `terraform destroy` to succeed even when the bucket contains uploaded JARs and static assets. Without this, teardown would require manual bucket emptying. The state bucket intentionally omits this (`prevent_destroy = true`) to protect Terraform state from accidental deletion.

## t3.small Instance Type

<!-- Options: t3.micro vs t3.small vs t3.medium -->
<!-- Chosen: t3.small (2 GiB RAM) -->
<!-- Rationale: Comfortable headroom for JVM + OS; JVM heap bounded to 512m -->

## HTTP Only (No TLS)

<!-- Options: HTTP only vs HTTPS with ACM -->
<!-- Chosen: HTTP only -->
<!-- Rationale: Sufficient for dev/test verification; TLS documented as future work -->
