# Lessons Learned

## Project Context

**Timeline:** 7 months ago (early AWS/Terraform learning phase)
**Goal:** Understand how networking components connect at a fundamental level
**Status:** Pre-certification (now hold AWS SAA & HashiCorp Terraform Associate)

This was one of my first deep dives into AWS networking. The primary objective was learning how Transit Gateways, VPCs, and cross-region connectivity work—not building production-ready infrastructure.

## Learning Objectives & Achievements

### 1. Transit Gateway Multi-Region Networking ✓
**Challenge:** Connect two regions with private network connectivity

**Key Learnings:**
- TGW peering requires explicit route table management (VPC routes → TGW attachments → TGW route tables → static routes)
- Default route table associations must be disabled for custom routing
- Both association AND static route required for peering to work
- Spent 3-4 hours debugging routing—learned more than any tutorial could teach

### 2. Terraform Modules ✓
**Challenge:** Deploy identical infrastructure without code duplication

**Achievement:**
- Created 3 reusable modules (VPC, Infrastructure, TGW)
- Achieved 50% code reduction through reuse
- Learned module dependency management with null_resource triggers

**Best Pattern Discovered:**
```hcl
variable "dependency_trigger" {
  description = "Forces dependency ordering"
  type = string
}

resource "null_resource" "dependency" {
  triggers = { always_run = var.dependency_trigger }
}
```
This solved DNS race condition where instances started before Route53 records existed.

### 3. Aurora MySQL Deployment ✓
**Challenge:** Stand up a managed database for the first time

**Learnings:**
- Cluster vs Instance distinction (cluster = storage layer, instance = compute)
- Multi-AZ subnet groups required
- Secrets Manager integration for credential management
- **Note:** Initial security group was overly permissive (0.0.0.0/0) because the focus was just getting the database running. Fixed post-project for portfolio.

### 4. DNS-Based Failover ✓
**Innovation:** Route53 + CloudWatch health check integration

Discovered that Route53 can monitor CloudWatch alarms to health-check private resources:
```
Route53 Health Check → CloudWatch Alarm → EC2 CPU Metric
```
This enabled failover for syslog servers in private subnets without needing a load balancer.

**Limitation Discovered:** Route53 failover doesn't automatically fail back to primary (AWS design, not a bug).

## Key Technical Challenges

### Challenge 1: TGW Peering Not Working
**Problem:** Cross-region ping failing despite peering established

**Debugging Process:**
1. Verified peering state: ✓ available
2. Checked route table associations: ✗ using default table
3. Realized: TGW attachments auto-associate to default route table
4. Solution: Disabled default association, created custom route tables

**Lesson:** AWS defaults aren't always what you need. Read the fine print.

### Challenge 2: Syslog DNS Race Condition
**Problem:** Application instances launching before DNS records created → rsyslog fails to resolve `wally.com` → no logs

**Solution:** Dependency trigger to ensure Route53 record exists before infrastructure module deploys

### Challenge 3: Data Residency Reality Check
**Requirement:** "All sensitive data must stay in Japan region"

**Reality:**
- rsyslog buffers logs locally before forwarding
- OS always writes to `/var/log/`
- Application logs cached on disk
- No way to prevent without breaking functionality

**Takeaway:** Documented limitation honestly. Proposed alternatives (CloudWatch Logs direct streaming). Learned that some requirements are harder than they appear and real-world systems have trade-offs.

## Growth: Before vs After

**Before (7 months ago):**
- Basic AWS (EC2, S3)
- Simple Terraform (single resources)
- No networking knowledge beyond subnets
- No certifications

**After This Project:**
- Multi-region architecture design
- Transit Gateway expertise
- Terraform modules & state management
- Aurora database deployment
- DNS failover patterns

**Current (Today):**
- AWS Solutions Architect Associate ✓
- HashiCorp Terraform Associate ✓
- Multiple production-level projects completed
- CI/CD pipeline experience
- Kubernetes fundamentals

## Honest Assessment

### What Went Well
- Successfully connected two regions via TGW peering
- Built working DNS-based failover without NLB
- Created reusable Terraform modules
- Learned by debugging real problems

### What I'd Do Differently Now
1. **Security-first:** Restrict security groups from day 1
2. **Use SSM Session Manager:** Not SSH with 0.0.0.0/0
3. **HTTPS from start:** Not "I'll add it later"
4. **Smaller scope:** Single region first, then expand
5. **Cost monitoring:** Enable Cost Explorer on day 1

### Recognized Growth Opportunities
This project exposed several areas where I lacked knowledge at the time:
- **Security hardening** (overly permissive SGs, no HTTPS, no IAM roles)
- **CI/CD** (manual terraform apply—now use GitHub Actions)
- **Monitoring** (minimal CloudWatch—now implement full observability)
- **Cost optimization** (learned the hard way with $300+ bills)

These gaps motivated me to pursue certifications and more advanced projects.

## Project Value

**What This Demonstrates:**
- Ability to learn complex technologies independently
- Problem-solving through debugging (not just tutorials)
- Honest acknowledgment of limitations
- Growth mindset (recognizing areas for improvement)

---

**Bottom Line:** This was a learning project that achieved its goal—deep understanding of AWS networking fundamentals. Security and production-readiness came later as I gained experience.
