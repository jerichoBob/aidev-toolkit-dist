---
name: aws-costs
tier: extended
description: Show AWS spend by service, daily trend, and active resources across one or all profiles.
argument-hint: "[--profile <name>] [--all-profiles]"
allowed-tools: Bash(aws:*), Read
model: haiku
---

# AWS Costs

Show current AWS spend broken down by service, daily trend, and active running resources.

## Arguments

- **(empty)**: Default AWS profile
- **`--profile <name>`**: Specific named profile from `~/.aws/config`
- **`--all-profiles`**: All configured profiles, combined summary with per-profile breakdown

## Instructions

### Step 1: Parse Arguments

Check `$ARGUMENTS`:

- If contains `--all-profiles`: set mode = `all`
- If contains `--profile <name>`: set mode = `single`, profile = extracted name
- Otherwise: set mode = `single`, profile = default (no `--profile` flag)

### Step 2: Check Prerequisites

```bash
aws --version 2>/dev/null
```

If command not found:

```text
Error: AWS CLI not installed.
Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

Stop here.

For each profile to query, verify credentials:

```bash
aws sts get-caller-identity [--profile <name>] 2>&1
```

If this fails, report:

```text
Error: Profile '<name>' is not authenticated or does not exist.
Run: aws configure [--profile <name>]
```

Skip unauthenticated profiles (continue to next profile in `--all-profiles` mode).

### Step 3: Determine Date Range

Current month start and today's date:

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  [--profile <name>] 2>&1
```

### Step 4: Query Current Month by Service

Run the cost-by-service query for each target profile. Parse the JSON output:

- Extract `Groups[].Keys[0]` (service name) and `Groups[].Metrics.BlendedCost.Amount` (cost)
- Sort descending by cost
- Filter out services with $0.00 spend
- Format as table

Output format per profile:

```text
AWS Costs — <profile> — <YYYY-MM-01> to <today>
================================================

Service                          This Month
-------------------------------- ----------
Amazon EC2                          $12.34
Amazon S3                            $1.23
AWS Lambda                           $0.45

Total: $14.02
```

### Step 5: Daily Trend (Last 7 Days)

```bash
aws ce get-cost-and-usage \
  --time-period Start=<7_days_ago>,End=<today> \
  --granularity DAILY \
  --metrics BlendedCost \
  [--profile <name>] 2>&1
```

Calculate 7-days-ago date: `$(date -v-7d +%Y-%m-%d)` (macOS) or `$(date -d '7 days ago' +%Y-%m-%d)` (Linux).

Parse and display:

```text
Daily Trend (last 7 days)
-------------------------
2026-04-11   $1.23  ↑
2026-04-12   $0.98  ↓
2026-04-13   $1.45  ↑
...
```

Show ↑/↓ delta indicator vs prior day. Show `—` if cost is $0.00.

### Step 6: Active Resources

Query running resources for each profile, pulling `Name`, `Project`, `Environment`, and `Owner` tags:

```bash
# EC2 running instances (with tags)
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Project`].Value|[0],Tags[?Key==`Environment`].Value|[0],Tags[?Key==`Owner`].Value|[0]]' \
  --output json [--profile <name>] 2>&1

# NAT Gateways (with tags)
aws ec2 describe-nat-gateways \
  --filter Name=state,Values=available \
  --query 'NatGateways[].[NatGatewayId,Tags[?Key==`Project`].Value|[0],Tags[?Key==`Environment`].Value|[0],Tags[?Key==`Owner`].Value|[0]]' \
  --output json [--profile <name>] 2>&1

# ALBs (with tags via separate call)
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].[LoadBalancerName,LoadBalancerArn]' \
  --output json [--profile <name>] 2>&1
# Then for each ALB ARN, fetch tags:
aws elbv2 describe-tags \
  --resource-arns <arn> \
  --query 'TagDescriptions[].Tags' \
  --output json [--profile <name>] 2>&1

# RDS instances (with tags)
aws rds describe-db-instances \
  --query 'DBInstances[?DBInstanceStatus==`available`].[DBInstanceIdentifier,DBInstanceClass,TagList[?Key==`Project`].Value|[0],TagList[?Key==`Environment`].Value|[0],TagList[?Key==`Owner`].Value|[0]]' \
  --output json [--profile <name>] 2>&1
```

**Group resources by `Project` tag.** For each project group, list its resources with type, ID, instance size, environment, and estimated hourly cost. Resources missing a `Project` tag go in an `[untagged]` group flagged with ⚠️.

Display:

```text
Active Resources — by Project
------------------------------
[llm-gateway]
  EC2:  i-0abc123  t3.medium   [env:prod]     ~$0.041/hr
  ALB:  llm-gateway-alb        [env:prod]     ~$0.008/hr
  RDS:  llm-gateway-db  db.t4g.micro          ~$0.015/hr

[welo]
  EC2:  i-0a10d9e5  t3.medium  [env:staging]  ~$0.041/hr
  NAT:  nat-0cf093  (1 gateway)               ~$0.045/hr

[untagged]  ⚠️  these resources have no Project tag — review for shutdown
  NAT:  nat-0xyz  (no tags)                   ~$0.045/hr
```

If a query fails (insufficient permissions), show `[permission denied]` for that resource type and continue.

Note in output: `Hourly rates are estimates based on us-east-1 on-demand pricing.`

### Step 7: Threshold Alert

Check for config file:

```bash
cat ~/.aws-costs-config.json 2>/dev/null
```

If file exists and `alertThreshold` is set, compare current month total against it. If exceeded, prepend the output with:

```text
⚠️  ALERT: Current month spend ($XX.XX) exceeds threshold ($YY.YY)
```

### Step 8: All-Profiles Mode

If mode = `all`:

1. Parse profile names from `~/.aws/config`:

   ```bash
   grep '^\[profile ' ~/.aws/config 2>/dev/null | sed 's/\[profile //;s/\]//'
   ```

   Also include `default` profile.

2. For each profile, run Steps 2–7 (skip unauthenticated ones with a warning).

3. After individual profile outputs, show a combined summary:

```text
Combined Summary — All Profiles
================================
Profile         This Month
--------------- ----------
default              $14.02
work                  $8.75
personal              $0.12

Grand Total:         $22.89
```

## Notes

- Cost Explorer API has a small per-request cost (~$0.01). Results are not cached.
- All costs are in USD. `BlendedCost` metric is used (reflects actual billed amount).
- Cost Explorer must be enabled in the AWS account (one-time setup, free tier available).
- Active resource hourly estimates are approximate; label accordingly.
