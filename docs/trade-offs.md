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

**Decision**: S3 state bucket in af-south-1 with native S3 locking (`use_lockfile = true`).

**Options considered**:
- S3 + DynamoDB lock table (legacy Terraform pattern, pre-1.10)
- S3 with native locking in af-south-1 (chosen)
- S3 with native locking in us-east-1 (cross-region state)

**Chosen**: S3 in af-south-1 with `use_lockfile = true` (native S3 locking).

**Rationale**:
- Terraform 1.10+ supports native S3 state locking via S3 conditional writes -- DynamoDB is deprecated and will be removed in a future Terraform release
- Fewer resources to manage (no DynamoDB table), lower cost, simpler architecture
- Keeping state in the same region as infrastructure simplifies operations
- Trade-off: if af-south-1 has an outage, both infra and state are inaccessible. For a single-region dev environment, this is acceptable.

**Alternative**: DynamoDB lock table -- only needed for teams on Terraform < 1.10 or needing cross-tool lock visibility. Not applicable here (Terraform v1.14.8 installed).

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
