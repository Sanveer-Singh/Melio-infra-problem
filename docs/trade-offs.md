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

<!-- Options: State bucket in af-south-1 vs us-east-1 -->
<!-- Chosen: af-south-1 -->
<!-- Rationale: Simpler (everything one region); if region has issues, state is inaccessible -->

## t3.small Instance Type

<!-- Options: t3.micro vs t3.small vs t3.medium -->
<!-- Chosen: t3.small (2 GiB RAM) -->
<!-- Rationale: Comfortable headroom for JVM + OS; JVM heap bounded to 512m -->

## HTTP Only (No TLS)

<!-- Options: HTTP only vs HTTPS with ACM -->
<!-- Chosen: HTTP only -->
<!-- Rationale: Sufficient for dev/test verification; TLS documented as future work -->
