---
name: Phase 4 Compute Evaluation
overview: Comprehensive evaluation of Phase 4 (Compute Module) implementation against its execution plan, identifying 1 critical bug, 2 high-priority design concerns, and several moderate/low improvements -- with specific file paths and remediation actions.
todos:
  - id: fix-retry-guard
    content: "CRITICAL: Add file existence guard after each S3 download retry loop in all 3 user data templates (5 download locations total)"
    status: completed
  - id: add-public-ip
    content: "HIGH: Add associate_public_ip_address = true to all 3 aws_instance resources in compute/main.tf"
    status: completed
  - id: port-consistency
    content: "HIGH: Resolve port hardcoding mismatch between security module (hardcoded 8082/8083) and compute module (configurable variables)"
    status: completed
  - id: update-plan-escaping
    content: "MODERATE: Update Phase 4 plan Step 4d to correct the $$NEWSFEED_TOKEN claim -- single $ is correct for bare variables in templatefile()"
    status: completed
  - id: update-tradeoffs
    content: "LOW: Add IMDSv2 note and port-hardcoding rationale to docs/trade-offs.md"
    status: completed
isProject: false
---

# Phase 4 Compute Module -- Implementation Evaluation

## Verdict: Solid implementation with 1 critical bug and 2 design concerns

The compute module is well-structured and follows conventions. Template escaping, dependency ordering, IAM wiring, and module interfaces are all correct. The critical bug is in the S3 download retry logic across all three user data templates.

---

## CRITICAL: S3 Download Retry Loop Silently Continues on Total Failure

**Files affected:**
- [terraform/modules/compute/templates/quotes.sh.tpl](terraform/modules/compute/templates/quotes.sh.tpl)
- [terraform/modules/compute/templates/newsfeed.sh.tpl](terraform/modules/compute/templates/newsfeed.sh.tpl)
- [terraform/modules/compute/templates/frontend.sh.tpl](terraform/modules/compute/templates/frontend.sh.tpl) (x3 downloads: front-end.jar, static.tgz)

**The bug:** All templates use this pattern:
```bash
for i in 1 2 3; do
  aws s3 cp "s3://${artifact_bucket}/quotes.jar" /opt/app/quotes.jar && break || sleep 10
done
```

If all 3 attempts fail, the `for` loop exits normally. Despite `set -e` being active, commands in conditional contexts (`&&`, `||`) do NOT trigger `set -e`. The script continues, writes the systemd unit, enables the service, and prints **"User data complete"** -- even though the JAR was never downloaded. systemd then loops indefinitely trying to start a non-existent JAR.

**Impact:** Misleading cloud-init logs (shows success), difficult to debug, wasted time during demo.

**Fix:** Add a file existence guard after each download loop:
```bash
for i in 1 2 3; do
  aws s3 cp "s3://${artifact_bucket}/quotes.jar" /opt/app/quotes.jar && break || sleep 10
done
[ -f /opt/app/quotes.jar ] || { echo "FATAL: Failed to download quotes.jar" >&2; exit 1; }
```

This applies to **all 5 download loops** (quotes.jar, newsfeed.jar, front-end.jar, static.tgz in frontend).

---

## HIGH: Missing `associate_public_ip_address` on EC2 Instances

**File:** [terraform/modules/compute/main.tf](terraform/modules/compute/main.tf)

**Issue:** The plan (Step 5d) specifies `associate_public_ip_address = true` on all EC2 instances. The implementation omits it, relying instead on `map_public_ip_on_launch = true` from the [networking module](terraform/modules/networking/main.tf) (line 17). This works but creates a fragile implicit contract -- if the subnet config changes, instances silently lose public IPs and all S3/SSM calls in user data fail.

**Recommendation:** Add `associate_public_ip_address = true` to all 3 `aws_instance` resources. This makes the internet access requirement self-documenting within the compute module and provides defense-in-depth.

---

## HIGH: Hardcoded Ports in Security Groups vs Configurable Compute Ports

**Files:**
- [terraform/modules/security/main.tf](terraform/modules/security/main.tf) -- ports 8082/8083 hardcoded (lines 86-101)
- [terraform/modules/compute/variables.tf](terraform/modules/compute/variables.tf) -- `quotes_port` and `newsfeed_port` are configurable with defaults 8082/8083

**Issue:** If someone changes the port defaults in the compute module, the security group rules won't match. The security module has no port variables -- it hardcodes `from_port = 8082` and `from_port = 8083`.

**Recommendation:** Either:
- (A) Add `quotes_port` and `newsfeed_port` variables to the security module and pass them from root, OR
- (B) Remove the port variables from the compute module (lock them to fixed values since the security groups expect them)

Option B is simpler for demo scope and consistent with the "simplicity over perfection" rule.

---

## MODERATE Issues

### Plan vs Implementation: Template Escaping Discrepancy

**Plan (Step 4d) says:** "The NEWSFEED_SERVICE_TOKEN line must use bash `$$NEWSFEED_TOKEN`"
**Implementation uses:** `$NEWSFEED_TOKEN` (single dollar)

Per Perplexity validation: bare `$VARIABLE` (without curly braces) is NOT interpolated by Terraform's `templatefile()`. Only `${...}` and `%{...}` are. **The implementation is correct; the plan was overly cautious.** The plan document should be updated to reflect this.

### `rm -f /etc/nginx/conf.d/default.conf` is a No-Op on AL2023

Per Perplexity validation: AL2023's nginx package does NOT create a default server block in `conf.d/` or `sites-enabled/`. The removal lines in `frontend.sh.tpl` are harmless but unnecessary. Not a bug, just noise.

### Nginx Config Delivery Improved from Plan

The plan says `echo '${nginx_conf}' > ...`. The implementation uses a single-quoted heredoc, which is better for multi-line content. This is an improvement.

---

## LOW / Informational

- **No `metadata_options` for IMDSv2**: EC2 instances don't enforce `http_tokens = "required"`. Acceptable for demo; note in trade-offs.
- **No explicit `root_block_device`**: Default 8GB gp3 from AMI is sufficient.
- **`user_data` encoding**: Terraform AWS provider 6.x handles base64 encoding automatically for `user_data`. Correct usage.

---

## Positive Observations (What's Done Well)

- **Template escaping strategy** is correct: nginx.conf rendered separately via `locals` to avoid double-escaping between Terraform and bash/nginx variable syntax
- **EnvironmentFile pattern** for systemd is robust with special characters (the NEWSFEED_SERVICE_TOKEN contains `&` and `^`)
- **Implicit dependency chain** (frontend depends on quotes/newsfeed private IPs) is correct and Terraform resolves it automatically
- **IAM policy** is properly scoped: S3 GetObject + ListBucket on artifact bucket, SSM GetParameter on `/app/*`
- **`user_data_replace_on_change = true`** ensures immutable infrastructure pattern
- **TLS provider** (`~> 4.0`) correctly declared at root level in [providers.tf](terraform/providers.tf)
- **JVM flags** (`-Xmx512m -XX:+UseSerialGC`) applied consistently to all 3 services
- **DynamoDB lock table** in [backend.tf](terraform/backend.tf) matches user requirement
- **Interface contracts** for Phase 5 ALB are all satisfied: `frontend_instance_id`, `vpc_id`, `public_subnet_ids`, `alb_security_group_id` all correctly exposed
- **Static asset path chain** is correct: Makefile builds `css/` in tarball -> extracted to `/opt/app/static/` -> nginx `alias /opt/app/static/css/;` for `/css/` location

---

## Tools and MCPs Used

- **Perplexity MCP** (`perplexity_ask`): Validated AL2023 nginx default config (no server block in `nginx.conf` or `conf.d/`), validated Terraform `templatefile()` bare `$VARIABLE` passthrough behavior
- **Context7 MCP**: Not invoked (Perplexity covered all needed validations)
- **Codebase exploration subagents**: Full module review (compute, security, networking), source code env var analysis, Makefile static asset build verification
- **Built-in tools**: Read (all `.tf` files, templates, rules, plans), Glob (file discovery), Shell (not used -- readonly evaluation)
