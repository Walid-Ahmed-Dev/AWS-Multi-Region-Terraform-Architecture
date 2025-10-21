# Design Decisions & Trade-offs

## Context

This project was built 7 months ago as a learning exercise to understand AWS networking fundamentals. Many decisions prioritized **learning** over production best practices.

## Key Design Choices

### 1. Transit Gateway vs VPC Peering

**Chosen:** Transit Gateway

| Transit Gateway | VPC Peering |
|----------------|-------------|
| $72/month (2 TGW + peering) | Free |
| Hub-spoke topology | Mesh topology |
| Scalable (easy to add regions) | Complex at scale |

**Rationale:** Wanted to learn TGW specifically. Cost wasn't a concern for a learning project.

---

### 2. Route53 Failover vs Network Load Balancer

**Chosen:** Route53 DNS failover

| Route53 Failover | NLB |
|------------------|-----|
| $0.50/month | $16/month |
| 60-90s RTO (TTL-based) | 5s RTO |
| Simple | More robust |

**Rationale:** Learning objective was DNS-based HA patterns. NLB would have worked better but taught less.

**Innovation:** Used CloudWatch metric health check to monitor private instances.

---

### 3. Single NAT Gateway per Region

**Chosen:** Single NAT (cost optimization)

**Trade-off:** Not HA—if NAT's AZ fails, private instances lose internet access.

**Rationale:** $32/month savings. Acceptable for learning environment.

---

### 4. Database Security Group

**Initial Implementation:** Allowed 0.0.0.0/0 on port 3306

**Why:** Primary goal was **standing up Aurora for the first time**—understanding cluster vs instance, Secrets Manager integration, multi-AZ configuration. Security hardening was secondary.

**Current Implementation:** Restricted to application tier and syslog security groups only (fixed for portfolio).

**Learning:** Focus on one thing at a time when learning. Get it working, then secure it.

---

### 5. Aurora MySQL vs RDS MySQL

**Chosen:** Aurora MySQL

| Aurora | RDS MySQL |
|--------|-----------|
| $60/month | $30/month |
| 5x performance | Baseline |
| Auto-scaling storage | Manual |
| 15 read replicas | 5 read replicas |

**Rationale:** Wanted to learn Aurora specifically—more complex, more capabilities, cloud-native database.

---

### 6. Centralized Syslog vs Regional Logging

**Chosen:** Centralized in Tokyo

**Trade-off:** Violates strict data residency (Virginia logs buffered locally before forwarding).

**Rationale:**
- Simpler architecture (one place to check logs)
- Learning objective was cross-region routing via TGW
- Real solution would use CloudWatch Logs with direct streaming

**Lesson:** Some requirements are harder than they appear. OS always logs locally.

---

### 7. Terraform Modules

**Chosen:** Create custom modules for VPC, Infrastructure, TGW

**Alternative:** Flat configuration (no modules)

**Rationale:** First project using Terraform modules—wanted to learn module design patterns.

**Benefits Realized:**
- 50% code reduction
- Consistent configuration across regions
- Learned module dependency management

---

## Recognized Limitations

### Security (Learning Phase Decisions)

**Original State (7 months ago):**
- Database SG: 0.0.0.0/0 ❌
- SSH access: 0.0.0.0/0 ❌
- No HTTPS ❌
- No IAM roles on instances ❌

**Why:** Focused on core learning objectives (networking, TGW, database deployment). Security was "I'll learn that next."

**Current Understanding:** Security should be built-in, not bolted on. Now implement security-first in new projects.

**Portfolio Fix:** Database SG now restricted to application tier + syslog servers.

---

### Data Residency Gap

**Issue:** Logs stored locally on Virginia instances before forwarding to Tokyo.

**Root Cause:**
- rsyslog buffers logs before sending
- OS system logs always write to `/var/log/`
- No way to prevent without breaking core functionality

**Better Solution (Now Know):**
- CloudWatch Logs agent with Tokyo region configured
- Logs stream directly, no local persistence
- VPC Endpoints for private connectivity

**Lesson:** Some requirements have physical limitations. Document honestly.

---

### Operational Gaps

**Missing:**
- CI/CD pipeline (manual terraform apply)
- Automated testing
- Staging environment
- Comprehensive monitoring

**Why:** Hadn't learned CI/CD or Kubernetes yet. Those came later.

**Current Practice:** All new projects include GitHub Actions, proper environments, full observability.

---

## What I'd Do Differently Now

Given current knowledge (AWS SAA + HCP Terraform certified):

1. **Security-first approach**
   - Restrict all SGs from day 1
   - Use SSM Session Manager (not SSH)
   - HTTPS with ACM certificates
   - IAM roles for service access

2. **Better logging architecture**
   - CloudWatch Logs with cross-region replication
   - No local log storage
   - Centralized in S3 with lifecycle policies

3. **Cost optimization**
   - VPC Endpoints for AWS services
   - Reserved Instances for predictable workloads
   - Cost Explorer enabled from start

4. **Infrastructure pipeline**
   - GitHub Actions for terraform apply
   - Plan on PR, apply on merge
   - Staging environment for testing

5. **Monitoring from start**
   - CloudWatch dashboard
   - SNS alerts for failures
   - Custom metrics for application health

---

## Trade-off Summary

Every decision balanced **learning objectives** vs **production readiness**:

- Chose TGW over VPC Peering → Learn advanced networking (cost be damned)
- Chose Route53 failover → Learn DNS-based HA (slower than NLB)
- Single NAT → Save money (sacrifice HA)
- Aurora over RDS → Learn cloud-native database (pay more)
- Permissive SGs initially → Focus on getting it working first

**Result:** Achieved learning objectives. Recognized gaps. Addressed in subsequent projects.

---

## Key Takeaway

This project represents a **learning journey**, not a production blueprint. The decisions made sense for the learning phase—understand the fundamentals first, optimize later.

**Growth demonstrated:** Recognizing what I didn't know then, what I learned during the project, and what I know now.
