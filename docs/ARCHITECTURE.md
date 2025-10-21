# Architecture Overview

## Table of Contents
- [Executive Summary](#executive-summary)
- [System Architecture](#system-architecture)
- [Network Topology](#network-topology)
- [Component Details](#component-details)
- [Data Flow](#data-flow)
- [Security Architecture](#security-architecture)
- [High Availability Design](#high-availability-design)

## Executive Summary

This project implements a multi-region, highly available AWS infrastructure for the J-Tele-Doctor telemedicine platform. The architecture spans two AWS regions (Tokyo and N. Virginia) connected via Transit Gateway peering, providing:

- **Geographic redundancy** across Asia-Pacific and North America
- **Centralized log aggregation** in the primary region (Japan)
- **Cross-region connectivity** via Transit Gateway underlay
- **High availability** through multi-AZ deployments
- **Automated failover** for critical logging infrastructure

### Architecture Highlights

```
┌─────────────────────────────────────────────────────────────┐
│  Primary Region: ap-northeast-1 (Tokyo)                     │
│  • VPC: 10.150.0.0/16                                       │
│  • Aurora Database Cluster                                  │
│  • Centralized Syslog Infrastructure                        │
│  • Application Tier (ALB + ASG)                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Transit Gateway Peering
                              │
┌─────────────────────────────────────────────────────────────┐
│  Secondary Region: us-east-1 (N. Virginia)                  │
│  • VPC: 10.151.0.0/16                                       │
│  • Application Tier (ALB + ASG)                             │
│  • Mirrors Tokyo infrastructure                             │
└─────────────────────────────────────────────────────────────┘
```

## System Architecture

### Regional Design Philosophy

The architecture follows a **hub-and-spoke model** with Tokyo as the primary hub:

**Tokyo (Hub Region):**
- Houses all persistent data (Aurora database)
- Centralized logging and monitoring
- Primary syslog collectors with automated failover
- Full application stack for local users

**N. Virginia (Spoke Region):**
- Application delivery for North American users
- Logs forwarded to Tokyo syslog servers
- No local data persistence (data sovereignty compliance)
- Connects to Tokyo via Transit Gateway peering

### Transit Gateway Architecture

```
                    Tokyo TGW                    Virginia TGW
                   ┌──────────┐                 ┌──────────┐
                   │ TGW1-JP  │◄──────Peer─────►│ TGW1-US  │
                   └────┬─────┘                 └────┬─────┘
                        │                            │
                   ┌────▼─────────┐           ┌──────▼───────┐
                   │ Route Table  │           │ Route Table  │
                   │ 10.151.0.0/16├─────┐─────│ 10.150.0.0/16│
                   └──────────────┘     │     └──────────────┘
                                        │
                            Cross-Region Routing
```

**Key Transit Gateway Features:**
- Custom route tables (not using default)
- Explicit route table associations
- Static routes for cross-region communication
- Peering attachment with both association and route definition

## Network Topology

### Tokyo Region (10.150.0.0/16)

```
┌─────────────────────────────────────────────────────────────────┐
│ VPC: 10.150.0.0/16                                              │
│                                                                 │
│  Public Subnets (IGW attached)                                  │
│  ├─ ap-northeast-1a: 10.150.1.0/24                              │
│  └─ ap-northeast-1c: 10.150.3.0/24                              │
│                                                                 │
│  Private Subnets (NAT Gateway routed)                           │
│  ├─ ap-northeast-1a: 10.150.11.0/24  (App + Syslog-Primary)     │
│  ├─ ap-northeast-1c: 10.150.13.0/24  (App + Syslog-Secondary)   │
│  ├─ ap-northeast-1c: 10.150.23.0/24  (Database)                 │
│  └─ ap-northeast-1d: 10.150.14.0/24  (Database)                 │
│                                                                 │
│  TGW Attachment: Private subnets 11.0/24, 13.0/24               │
└─────────────────────────────────────────────────────────────────┘
```

**Routing Configuration:**
- Public subnets: 0.0.0.0/0 → IGW
- Private subnets:
  - 0.0.0.0/0 → NAT Gateway
  - 10.0.0.0/8 → Transit Gateway

### N. Virginia Region (10.151.0.0/16)

```
┌─────────────────────────────────────────────────────────────────┐
│ VPC: 10.151.0.0/16                                              │
│                                                                 │
│  Public Subnets (IGW attached)                                  │
│  ├─ us-east-1a: 10.151.1.0/24                                   │
│  └─ us-east-1b: 10.151.2.0/24                                   │
│                                                                 │
│  Private Subnets (NAT Gateway routed)                           │
│  ├─ us-east-1a: 10.151.11.0/24  (Application)                   │
│  └─ us-east-1b: 10.151.12.0/24  (Application)                   │
│                                                                 │
│  TGW Attachment: Private subnets 11.0/24, 12.0/24               │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. VPC Module

**Purpose:** Creates isolated network environments in each region

**Resources Created:**
- VPC with DNS support and hostnames enabled
- 2 public subnets (different AZs)
- 2 private subnets (different AZs)
- Internet Gateway
- NAT Gateway with Elastic IP
- Route tables and associations
- Transit Gateway attachment

**Design Decisions:**
- Multi-AZ subnet distribution for HA
- Separate route tables for public/private traffic
- NAT Gateway in single AZ (cost optimization vs. HA trade-off)
- TGW attachment in private subnets only

### 2. Infrastructure Module

**Purpose:** Deploys application tier with auto-scaling capabilities

**Resources Created:**
- Application Load Balancer (ALB)
- Auto Scaling Group (ASG)
- Launch Template
- Target Group with health checks
- Security Groups (ALB, application servers)
- TLS key pair generation
- IAM roles and policies

**Configuration:**
- Min/Max/Desired: 1 instance (demonstration purposes)
- Health check: ELB-based
- Target tracking policy: 75% CPU utilization
- Instance types: t2.micro (cost-optimized)

**User Data Script:**
- Installs and configures Apache (httpd)
- Creates dynamic HTML page with instance metadata
- Configures rsyslog client
- Forwards all logs to wally.com:514 (Route53 DNS)

### 3. Transit Gateway Module

**Purpose:** Enables cross-region network connectivity

**Resources Created:**
- Transit Gateway
- VPC attachment (in private subnets)
- Custom route table
- Route table associations
- Route table propagations

**Key Configuration:**
```hcl
transit_gateway_default_route_table_association = false
transit_gateway_default_route_table_propagation = false
```
This prevents automatic associations, ensuring explicit routing control.

### 4. Centralized Logging Infrastructure

#### Syslog Servers

**Primary Syslog Server:**
- Location: 10.150.11.x (ap-northeast-1a)
- Instance: t3.micro
- Configuration: rsyslog with TCP/UDP listeners on port 514
- Monitoring: CloudWatch alarm on CPU utilization

**Secondary Syslog Server:**
- Location: 10.150.13.x (ap-northeast-1c)
- Instance: t3.micro
- Configuration: Identical to primary
- Role: Failover target (no health check - always available)

#### Route53 Failover Configuration

```
wally.com (Private Hosted Zone)
├─ PRIMARY Record → syslog-server (10.150.11.x)
│  └─ Health Check: CloudWatch Alarm
└─ SECONDARY Record → syslog-server2 (10.150.13.x)
   └─ No health check (always healthy)
```

**Health Check Logic:**
- Type: CloudWatch Metric
- Metric: EC2 CPU Utilization
- Threshold: < 0.0001% (effectively detects instance failure)
- Evaluation: 1 period of 60 seconds
- Missing data treatment: "breaching" (marks unhealthy)

**Failover Behavior:**
1. Primary healthy: All traffic → Primary
2. Primary fails: Health check fails → Route53 updates DNS → Traffic → Secondary
3. Primary recovers: Health check passes → Traffic stays on Secondary (limitation)
4. Secondary fails: Traffic returns to Primary (only if Secondary unhealthy)

### 5. Database Layer

**Aurora MySQL Cluster:**
- Engine: aurora-mysql 8.0.mysql_aurora.3.05.2
- Instance class: db.t3.medium
- Deployment: Multi-AZ (ap-northeast-1c, ap-northeast-1d)
- Instances: 1 writer (can be scaled)

**Security:**
- Credentials: AWS Secrets Manager
- Encryption: KMS (alias/aws/secretsmanager)
- Password: 16-character random generation
- Network: Private subnets only, security group restricted

**Secrets Manager Structure:**
```json
{
  "username": "admin",
  "password": "<randomly-generated-16-char>"
}
```

### 6. Security Groups

**Load Balancer SG:**
- Ingress: TCP 80 from 0.0.0.0/0
- Egress: All traffic

**Application Server SG:**
- Ingress:
  - TCP 80 from ALB security group
  - TCP/UDP 514 from anywhere (syslog)
- Egress: All traffic

**Syslog Server SG:**
- Ingress:
  - TCP 22 from anywhere (management)
  - TCP 514 from anywhere (syslog)
  - UDP 514 from anywhere (syslog)
- Egress: All traffic

**Aurora Database SG:**
- Ingress: TCP 3306 from 0.0.0.0/0 (should be restricted in production)
- Egress: All traffic

**EC2 Instance Connect Endpoint SG:**
- Ingress: TCP 22 from anywhere
- Egress: All traffic

## Data Flow

### 1. Application Request Flow

```
User → Internet → ALB (Public Subnet) → Target Group →
EC2 Instance (Private Subnet) → Application Response
```

### 2. Database Query Flow

```
EC2 Instance → Aurora Writer Endpoint → Database Subnet →
Query Processing → Response
```

### 3. Log Aggregation Flow

```
EC2 Instance (Any Region) → DNS Query: wally.com →
Route53 Private Zone → Syslog Server IP →
rsyslog forwarder → TCP/UDP 514 → Syslog Server →
/var/log/messages
```

**Cross-Region Log Flow:**
```
Virginia EC2 → wally.com:514 → Route53 → Primary Syslog IP →
Private Route Table → TGW Attachment → TGW Route Table →
TGW Peering → Tokyo TGW → Tokyo VPC → Syslog Server
```

### 4. Transit Gateway Communication

```
Tokyo VPC (10.150.0.0/16) →
├─ Route: 10.151.0.0/16 → TGW Attachment →
├─ TGW Route Table: 10.151.0.0/16 → Peering Attachment →
├─ TGW Peering →
└─ Virginia TGW → Virginia VPC (10.151.0.0/16)
```

## Security Architecture

### Network Security

**Defense in Depth:**
1. VPC isolation (separate VPCs per region)
2. Subnet segmentation (public/private)
3. Security groups (stateful firewall)
4. Network ACLs (default - stateless firewall)
5. Private subnets for sensitive resources

**Internet Access:**
- Public subnets: Direct via IGW (for ALB)
- Private subnets: Outbound via NAT Gateway
- No direct inbound to private resources

### Data Security

**Encryption at Rest:**
- Aurora: Automatic encryption with KMS
- Secrets Manager: KMS encryption (Data Encryption Key model)
- EBS volumes: Default encryption (best practice)

**Encryption in Transit:**
- ALB to EC2: HTTP (could be upgraded to HTTPS)
- EC2 to Aurora: MySQL native encryption (configurable)
- Syslog: Plaintext TCP/UDP (limitation)

**Secrets Management:**
- Database credentials: Secrets Manager with automatic rotation support
- SSH keys: Generated via Terraform (tls_private_key)
- Keys stored as sensitive outputs

### Identity and Access Management

**Principle of Least Privilege:**
- EC2 instances: No IAM roles attached (should be added)
- Auto Scaling: Service-linked roles (AWS managed)
- Secrets access: Could be restricted via IAM policies

## High Availability Design

### Multi-AZ Deployments

**Application Tier:**
- ASG spans 2 AZs (ap-northeast-1a, ap-northeast-1c)
- ALB listeners in 2 AZs
- Automatic instance replacement on failure

**Database Tier:**
- Aurora cluster spans 2 AZs (ap-northeast-1c, 1d)
- Automatic failover to standby
- Continuous backup to S3

**Syslog Tier:**
- 2 servers in different AZs
- Route53 DNS-based failover
- Automatic health monitoring

### Failover Mechanisms

**Application Failover:**
- Trigger: Instance health check failure
- Method: ASG automatic replacement
- RTO: ~5 minutes (health check + launch)
- RPO: None (stateless application)

**Database Failover:**
- Trigger: Writer instance failure
- Method: Aurora automatic promotion
- RTO: ~30-60 seconds
- RPO: Near-zero (synchronous replication)

**Syslog Failover:**
- Trigger: Primary server failure (CPU < 0.0001%)
- Method: Route53 DNS failover
- RTO: ~60-90 seconds (TTL=30s + DNS propagation)
- RPO: Logs in flight may be lost (UDP)

### Regional Redundancy

**Current State:**
- Application: Deployed in both regions
- Database: Only in Tokyo (single point of failure)
- Syslog: Only in Tokyo (by design for centralization)

**Disaster Recovery:**
- Cross-region TGW connectivity enables data replication
- Aurora supports cross-region read replicas (not implemented)
- Manual failover to Virginia region possible with data loss

## Scalability Considerations

### Horizontal Scaling

**Application Tier:**
- ASG can scale from 1 to unlimited (currently max=1)
- Target tracking based on CPU (75%)
- Can add additional scaling policies (memory, request count)

**Database Tier:**
- Aurora supports up to 15 read replicas
- Automatic read/write splitting possible
- Can add cross-region read replicas

**Syslog Tier:**
- Currently limited to 2 instances
- Could implement additional Route53 records with weights
- No automatic scaling (manual intervention required)

### Vertical Scaling

**Application:** Change instance type in launch template
**Database:** Modify instance class (requires brief downtime)
**Syslog:** Change instance type (requires failover)

## Monitoring and Observability

### Current Monitoring

**CloudWatch Metrics:**
- EC2: CPU, network, disk (automatic)
- ALB: Request count, latency, errors
- Aurora: CPU, connections, replication lag
- ASG: Instance counts, scaling activities

**CloudWatch Alarms:**
- Syslog server health (CPU < 0.0001%)
- ASG scaling triggers (CPU > 75%)

**Route53 Health Checks:**
- Primary syslog server availability
- Based on CloudWatch alarm state

### Monitoring Gaps

- No application-level monitoring
- No log analysis or alerting
- No performance metrics collection
- No distributed tracing
- Limited database query monitoring

### Recommended Enhancements

1. CloudWatch Logs agent on all EC2 instances
2. Custom metrics for application health
3. AWS X-Ray for distributed tracing
4. Enhanced Aurora monitoring
5. CloudWatch Insights for log analysis
6. SNS topics for alarm notifications

## Cost Optimization

### Current Cost Drivers

1. **Aurora Database:** ~$50-100/month (t3.medium)
2. **NAT Gateways:** ~$65/month (2 regions)
3. **EC2 Instances:** ~$20-30/month (4-6 t2.micro/t3.micro)
4. **Application Load Balancers:** ~$35/month (2 ALBs)
5. **Transit Gateway:** ~$70/month (2 TGW + data transfer)
6. **Data Transfer:** Variable ($0.01-0.09/GB)

**Estimated Monthly Cost:** $240-350/month

### Optimization Opportunities

- Use single NAT Gateway (reduces HA)
- Aurora Serverless v2 (pay per use)
- Reserved Instances for predictable workloads
- VPC Endpoints to avoid NAT Gateway data charges
- CloudWatch Logs retention policies

## Compliance and Governance

### Data Residency

**Requirement:** Sensitive data must remain in Japan

**Implementation:**
- Aurora database only in Tokyo region
- Logs centralized in Tokyo (but traverse network)
- Application data not persisted in Virginia

**Gaps:**
- Application logs stored locally before forwarding
- OS-level logs on Virginia instances
- Temporary data in memory/disk

### Tagging Strategy

**Current Tags:**
- Name: Resource identifier
- Service: "J-Tele-Doctor"

**Recommended Tags:**
- Environment: Production/Development
- Owner: Team identifier
- CostCenter: Billing allocation
- Compliance: Data classification

## Future Enhancements

### Short Term
1. Implement HTTPS on ALBs (ACM certificates)
2. Add IAM roles to EC2 instances
3. Restrict database security group to application tier
4. Implement CloudWatch Logs centralization
5. Add Route53 health check for secondary syslog

### Medium Term
1. Aurora cross-region read replica
2. CloudFront for content delivery
3. WAF for application protection
4. Secrets Manager automatic rotation
5. Enhanced monitoring with custom metrics

### Long Term
1. Multi-region database writes (Aurora Global Database)
2. Service mesh for microservices communication
3. Container orchestration (ECS/EKS)
4. Infrastructure as Code pipeline (CI/CD)
5. Compliance automation (AWS Config, Security Hub)
