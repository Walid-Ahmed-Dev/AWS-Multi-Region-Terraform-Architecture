# Multi-Region AWS Infrastructure with Transit Gateway

> A production-grade, highly available AWS infrastructure spanning multiple regions, featuring Transit Gateway networking, centralized logging with automatic failover, and Aurora MySQL database deployment.

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Multi--Region-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

**Project Timeline:** 7 months ago (early learning phase, pre-certification)
**Current Status:** AWS Solutions Architect Associate & HashiCorp Terraform Associate certified

This project was built as a **learning exercise** to deeply understand AWS networking fundamentals—specifically how Transit Gateways, VPCs, and cross-region connectivity work. The infrastructure spans **Tokyo (ap-northeast-1)** and **N. Virginia (us-east-1)**, connected via Transit Gateway peering, with centralized logging and Aurora MySQL database.

**Primary Goal:** Understand how components connect, not build production-ready infrastructure. Security hardening and operational best practices came later as I gained experience.

### Key Features

- **Multi-Region Architecture:** Geographically distributed infrastructure across Asia-Pacific and North America
- **Transit Gateway Networking:** Hub-and-spoke topology with inter-region connectivity
- **High Availability:** Multi-AZ deployments, auto-scaling, and automated failover
- **Centralized Logging:** Syslog infrastructure with Route53 DNS-based failover
- **Infrastructure as Code:** 100% Terraform with reusable modules
- **Security:** Private subnets, security groups, Secrets Manager integration
- **Monitoring:** CloudWatch metrics, alarms, and health checks

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────┐
│  Tokyo Region (ap-northeast-1)                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ VPC: 10.150.0.0/16                             │     │
│  │  ┌──────────────┐  ┌──────────────┐            │     │
│  │  │ Public       │  │ Private      │            │     │
│  │  │ - ALB        │  │ - App Tier   │            │     │
│  │  │ - NAT GW     │  │ - ASG        │            │     │
│  │  └──────────────┘  │ - Syslog HA  │            │     │
│  │                    │ - Aurora DB  │            │     │
│  │                    └──────────────┘            │     │
│  └────────────────────────────────────────────────┘     │
│                          │                              │
│                     Transit Gateway                     │
└──────────────────────────┼──────────────────────────────┘
                           │
                  TGW Peering Connection
                           │
┌──────────────────────────┼──────────────────────────────┐
│                     Transit Gateway                     │
│  ┌────────────────────────────────────────────────┐     │
│  │ VPC: 10.151.0.0/16                             │     │
│  │  ┌──────────────┐  ┌──────────────┐            │     │
│  │  │ Public       │  │ Private      │            │     │
│  │  │ - ALB        │  │ - App Tier   │            │     │
│  │  │ - NAT GW     │  │ - ASG        │            │     │
│  │  └──────────────┘  └──────────────┘            │     │
│  └────────────────────────────────────────────────┘     │
│  Virginia Region (us-east-1)                            │
└─────────────────────────────────────────────────────────┘
```

### Infrastructure Components

| Component | Tokyo | Virginia | Purpose |
|-----------|-------|----------|---------|
| **VPC** | 10.150.0.0/16 | 10.151.0.0/16 | Network isolation |
| **Public Subnets** | 2 AZs | 2 AZs | ALB, NAT Gateway |
| **Private Subnets** | 4 subnets | 2 subnets | App, Database, Syslog |
| **Transit Gateway** | Yes | Yes | Cross-region routing |
| **Application Load Balancer** | Yes | Yes | HTTP traffic distribution |
| **Auto Scaling Group** | 1-x instances | 1-x instances | Horizontal scaling |
| **Aurora MySQL** | 1 cluster | - | Centralized database |
| **Syslog Servers** | 2 (HA) | - | Centralized logging |
| **Route53** | Private Zone | Private Zone | DNS, failover |

## Project Structure

```
.
├── main.tf                    # Root configuration, module orchestration
├── variables.tf               # Input variables (empty, using hardcoded values)
├── outputs.tf                 # Output values (ALB DNS, keys, IDs)
├── backend.tf                 # S3 remote state configuration
├── Route 53.tf                # DNS, hosted zones, failover records
├── Health.check.tf            # Route53 health check (CloudWatch-based)
├── CloudWatch.tf              # Alarms for syslog failover
├── Database.tf                # Aurora MySQL cluster and Secrets Manager
│
├── modules/
│   ├── vpc/                   # VPC, subnets, IGW, NAT, TGW attachment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── infrastructure/        # ALB, ASG, Launch Template, security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── user_data.sh       # Instance bootstrap script
│   │
│   └── TGW/                   # Transit Gateway, route tables, attachments
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── docs/
    ├── ARCHITECTURE.md        # Detailed architecture documentation
    ├── DESIGN_DECISIONS.md    # Trade-offs and rationale
    ├── LESSONS_LEARNED.md     # Reflections and growth
    ├── DEPLOYMENT.md          # Step-by-step deployment guide
    └── TROUBLESHOOTING.md     # Common issues and solutions
```

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[Architecture Overview](docs/ARCHITECTURE.md)**: Deep dive into system design, components, data flows, and security
- **[Design Decisions](docs/DESIGN_DECISIONS.md)**: Trade-off analysis, alternatives considered, and technical debt
- **[Lessons Learned](docs/LESSONS_LEARNED.md)**: Personal reflections, challenges faced, and career growth
- **[Deployment Guide](docs/DEPLOYMENT.md)**: Prerequisites, step-by-step deployment, verification, and cleanup
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Common issues, debugging methodology, and solutions

## Quick Start

### Prerequisites

- **Terraform** 1.0+ ([Download](https://www.terraform.io/downloads))
- **AWS CLI** 2.0+ ([Download](https://aws.amazon.com/cli/))
- **AWS Account** with administrator access
- **S3 Bucket** for Terraform state storage

### Installation

**1. Clone the repository**
```bash
git clone <your-repo-url>
cd AWS-Multi-Region-Terraform-Architecture
```

**2. Configure AWS credentials**
```bash
aws configure
# Enter your AWS Access Key ID and Secret Access Key
```

**3. Create S3 bucket for state**
```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

**4. Update backend configuration**

Edit `backend.tf` and replace the bucket name:
```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"  # CHANGE THIS
    key    = "terraformv2.tfstate"
    region = "us-east-1"
  }
}
```

**5. Initialize Terraform**
```bash
terraform init
```

**6. Review the plan**
```bash
terraform plan
# Review ~80-100 resources to be created
```

**7. Deploy infrastructure**
```bash
terraform apply
# Type 'yes' to confirm
# Wait 15-20 minutes for complete deployment
```

**8. Access outputs**
```bash
# Tokyo application URL
terraform output ALB-DNS

# Virginia application URL
terraform output ALB-DNS-NewYork

# SSH private keys (sensitive)
terraform output -raw private_key-japan > tokyo-key.pem
chmod 600 tokyo-key.pem
```

For detailed deployment instructions, see **[Deployment Guide](docs/DEPLOYMENT.md)**.

## Key Technical Implementations

### 1. Transit Gateway Multi-Region Networking

**Challenge:** Connect two regions with private network connectivity for centralized logging

**Solution:** Transit Gateway peering with custom route tables

```hcl
# Peering requestor (Tokyo)
resource "aws_ec2_transit_gateway_peering_attachment" "Japan_NewYork_Peer_Request" {
  transit_gateway_id      = module.TGW_japan.TGW_id
  peer_transit_gateway_id = module.TGW_NewYork.TGW_id
  peer_region             = "us-east-1"
}

# Peering acceptor (Virginia)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "NewYork_Japan_Peer_Accepter" {
  provider                      = aws.us-east-1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.Japan_NewYork_Peer_Request.id
}

# Route table associations and static routes on both sides
resource "aws_ec2_transit_gateway_route" "Japan_to_NewYork_Route" {
  transit_gateway_route_table_id = module.TGW_japan.TGW_route_table_id
  destination_cidr_block         = "10.151.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.NewYork_Japan_Peer_Accepter.id
}
```

**Key Learnings:**
- Peering requires explicit acceptance (cross-region provider)
- Custom route tables prevent default associations
- Both association AND static route required
- Route tables needed at both TGW and VPC level

### 2. Syslog High Availability with DNS Failover

**Challenge:** Centralized logging with automatic failover, without Network Load Balancer cost

**Solution:** Route53 private hosted zone with health check-based failover

```hcl
# Primary syslog record
resource "aws_route53_record" "syslog" {
  zone_id = aws_route53_zone.syslog.zone_id
  name    = "wally.com"
  type    = "A"
  ttl     = 30
  records = [aws_instance.syslog-server.private_ip]
  set_identifier = "primary-syslog-server"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.syslog.id
}

# Secondary syslog record (no health check - always healthy)
resource "aws_route53_record" "syslog2" {
  zone_id = aws_route53_zone.syslog.zone_id
  name    = "wally.com"
  type    = "A"
  ttl     = 30
  records = [aws_instance.syslog-server2.private_ip]
  set_identifier = "secondary-syslog-server"

  failover_routing_policy {
    type = "SECONDARY"
  }
}

# CloudWatch-based health check for private instance
resource "aws_route53_health_check" "syslog" {
  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.syslog.alarm_name
  cloudwatch_alarm_region         = "ap-northeast-1"
  insufficient_data_health_status = "Unhealthy"
}
```

**Key Learnings:**
- Route53 can monitor CloudWatch alarms (works for private resources)
- DNS TTL=30s balances failover speed vs. query load
- CPU < 0.0001% effectively detects instance termination
- Known limitation: No automatic failback to primary

### 3. Modular Terraform Design

**Challenge:** Deploy identical infrastructure in multiple regions without code duplication

**Solution:** Reusable modules with region-specific parameters

```hcl
# Tokyo deployment
module "vpc_japan" {
  source             = "./modules/vpc"
  region             = "ap-northeast-1"
  cidr_block         = "10.150.0.0/16"
  name               = "app1"
  service            = "J-Tele-Doctor"
  subnet1_cidr_block = "10.150.1.0/24"
  # ... more config
  TGW_id             = module.TGW_japan.TGW_id
}

# Virginia deployment (same module, different parameters)
module "vpc_NewYork" {
  source             = "./modules/vpc"
  region             = "us-east-1"
  cidr_block         = "10.151.0.0/16"
  # ... different CIDR blocks
  TGW_id             = module.TGW_NewYork.TGW_id
}
```

**Benefits:**
- 50% code reduction through reuse
- Consistent configuration across regions
- Bug fixes apply to all instances
- Easy to add new regions

### 4. Aurora MySQL with Secrets Manager

**Challenge:** Secure database credential management without hardcoding

**Solution:** AWS Secrets Manager with automatic secret generation

```hcl
# Generate random password
resource "random_password" "db_admin_password" {
  length  = 16
  special = true
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret_version" "db_admin_password_version" {
  secret_id = aws_secretsmanager_secret.db_admin_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_admin_password.result
  })
}

# Reference in Aurora cluster
resource "aws_rds_cluster" "aurora_cluster" {
  master_username = jsondecode(aws_secretsmanager_secret_version.db_admin_password_version.secret_string)["username"]
  master_password = jsondecode(aws_secretsmanager_secret_version.db_admin_password_version.secret_string)["password"]
  # ... more config
}
```

**Security Benefits:**
- No credentials in code or state file (encrypted)
- Rotation-ready (can enable automatic rotation)
- KMS envelope encryption
- Versioning for rollback capability

## Known Limitations (Learning Phase)

**Context:** This was built 7 months ago when I was just learning AWS networking. The focus was understanding how components connect—security hardening came later.

### Recognized Learning Gaps (Since Addressed)

1. **Database Security** ✅ Fixed
   - **Original:** Security group allowed 0.0.0.0/0 on port 3306
   - **Why:** Primary goal was standing up Aurora for the first time—learning cluster vs instance, Secrets Manager, multi-AZ config
   - **Current:** Restricted to application tier and syslog servers only (fixed for portfolio)

2. **Data Residency**
   - **Issue:** Logs buffer locally on Virginia instances before forwarding to Tokyo
   - **Reality:** OS always logs to `/var/log/`—no way to prevent without breaking functionality
   - **Better Solution:** CloudWatch Logs agent with direct streaming (now understand this approach)

3. **Syslog Failover Behavior**
   - **Limitation:** Route53 stays on secondary after primary recovers (AWS design)
   - **Learning:** DNS-based failover has inherent limitations; NLB would be better for production

4. **Operational Gaps**
   - No HTTPS (didn't know ACM yet)
   - SSH from internet (hadn't learned SSM Session Manager)
   - No IAM roles (security wasn't the focus)
   - Manual terraform apply (CI/CD came later)

**Growth:** Now certified (AWS SAA + HCP Terraform) and implement security-first, CI/CD-driven infrastructure in all new projects.

For detailed analysis, see **[Design Decisions](docs/DESIGN_DECISIONS.md)**.

### What I'd Do Differently Now

Given current knowledge (certified + production experience):
- [x] HTTPS with ACM certificates
- [x] SSM Session Manager instead of SSH
- [x] CloudWatch Logs with direct streaming
- [x] GitHub Actions CI/CD pipeline
- [x] Full observability stack

**Note:** These represent growth areas since this project. New projects incorporate these from day 1.

## Cost Analysis

### Monthly Cost Breakdown

| Service | Quantity | Unit Cost | Monthly Cost |
|---------|----------|-----------|--------------|
| **Compute** | | | |
| EC2 Instances (t2.micro/t3.micro) | 4-6 | ~$8/ea | $32-48 |
| **Networking** | | | |
| Transit Gateways | 2 | $36/ea | $72 |
| TGW Peering | 1 | $36 | $36 |
| NAT Gateways | 2 | $32/ea | $64 |
| Application Load Balancers | 2 | $18/ea | $36 |
| **Database** | | | |
| Aurora MySQL (db.t3.medium) | 1 | ~$60 | $60 |
| **DNS & Monitoring** | | | |
| Route53 Hosted Zones | 2 | $0.50/ea | $1 |
| Health Checks | 1 | $0.50 | $0.50 |
| **Data Transfer** | Variable | - | $10-30 |
| **Total** | | | **$311.50-347.50** |

### Cost Optimization Strategies

1. **Use AWS Free Tier** (first 12 months)
   - 750 hours/month EC2 (t2.micro)
   - 750 hours/month RDS (db.t2.micro - requires downgrade)
   - Potential savings: ~$50/month

2. **Reserved Instances** (1-year term)
   - EC2: ~40% savings
   - RDS: ~35% savings
   - Requires commitment

3. **Single Region Deployment**
   - Deploy only Tokyo initially
   - Saves: ~$140/month (NAT, TGW, ALB in Virginia)

4. **VPC Endpoints for AWS Services**
   - S3 Gateway Endpoint (free)
   - Saves NAT Gateway data transfer costs

For more details, see **[Troubleshooting: Cost Optimization](docs/TROUBLESHOOTING.md#cost-optimization)**.

## Learning Outcomes

**Timeline:** 7 months ago → Present
**Growth:** No certs → AWS SAA + HCP Terraform certified

### Key Achievements

**1. Transit Gateway Mastery**
- Learned TGW peering requires explicit route table management at multiple levels
- Debugged cross-region connectivity for 3+ hours—learned more than any tutorial

**2. Terraform Modules**
- First project using modules—achieved 50% code reduction through reuse
- Learned dependency management patterns (null_resource triggers)

**3. Aurora MySQL**
- Successfully deployed managed database for the first time
- Understood cluster vs instance, Secrets Manager integration, multi-AZ requirements
- Initial focus was getting it working; security came later (learning approach)

**4. DNS-Based Failover**
- Discovered Route53 + CloudWatch health check integration for private resources
- Learned failover limitations (no auto-failback)

### Growth Since This Project

**Then:** Basic AWS knowledge, no certs, security as afterthought
**Now:** AWS SAA + HCP Terraform certified, security-first mindset, CI/CD workflows

For detailed reflection, see **[Lessons Learned](docs/LESSONS_LEARNED.md)**.

## Technologies Used

| Technology | Version | Purpose |
|------------|---------|---------|
| **Terraform** | ~1.0 | Infrastructure as Code |
| **AWS Provider** | ~5.0 | AWS resource management |
| **Amazon Linux 2** | Latest | EC2 instance OS |
| **Aurora MySQL** | 8.0 | Database engine |
| **rsyslog** | Latest | Log aggregation |
| **Apache httpd** | Latest | Web server |

## Security Considerations

### Current Security Measures

- **Network Isolation:** VPCs with public/private subnets
- **Security Groups:** Least privilege (with noted exceptions)
- **Secrets Management:** Secrets Manager with KMS encryption
- **Private Resources:** Database and syslog in private subnets
- **Encryption:** KMS encryption for secrets, Aurora storage encryption

### Security Status

**Learning Project Notice:** Built 7 months ago to understand networking fundamentals. Security hardening was not the primary objective.

**Original State:**
- Database SG: 0.0.0.0/0 (getting Aurora running was the goal)
- SSH: 0.0.0.0/0 (hadn't learned SSM yet)
- No HTTPS (didn't know ACM)
- No IAM roles (focus was on networking)

**Portfolio Update:**
- [x] Database SG restricted to application tier + syslog servers
- [ ] Other items remain as-is to show authentic learning progression

**Current Practice:** Now implement security-first in all new projects (AWS SAA certified).

For context, see **[Design Decisions](docs/DESIGN_DECISIONS.md)**.

## Testing

### Verification Steps

**1. Test Application Endpoints**
```bash
# Tokyo
curl http://$(terraform output -raw ALB-DNS)

# Virginia
curl http://$(terraform output -raw ALB-DNS-NewYork)
```

**2. Test Cross-Region Connectivity**
```bash
# From Tokyo instance, ping Virginia instance
ping 10.151.11.x
```

**3. Test Syslog Aggregation**
```bash
# From any application instance
logger "Test message from $(hostname)"

# On syslog server
tail -f /var/log/messages | grep "Test message"
```

**4. Test Failover**
```bash
# Terminate primary syslog server
aws ec2 terminate-instances --instance-ids <primary-instance-id> --region ap-northeast-1

# Wait 60-90 seconds, check DNS
dig wally.com +short
# Should now return secondary IP
```

For comprehensive testing procedures, see **[Deployment: Post-Deployment Verification](docs/DEPLOYMENT.md#post-deployment-verification)**.

## Troubleshooting

Common issues and solutions:

| Issue | Quick Fix |
|-------|-----------|
| **Terraform state locked** | `terraform force-unlock <lock-id>` |
| **Can't ping across regions** | Check TGW route tables and security groups |
| **ALB returns 503** | Check target health: `aws elbv2 describe-target-health` |
| **DNS not resolving** | Verify Route53 hosted zone VPC associations |
| **High AWS costs** | Enable Cost Explorer, check NAT/TGW data transfer |

For detailed troubleshooting, see **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**.

## Contributing

This is a personal learning project and portfolio piece. However, feedback and suggestions are welcome!

If you find issues or have improvement ideas:
1. Open an issue describing the problem/suggestion
2. For code contributions, fork the repo and submit a pull request
3. Ensure any changes pass `terraform validate` and `terraform plan`

## Cleanup

To avoid ongoing AWS charges, destroy all resources:

```bash
# Review what will be destroyed
terraform destroy -target=module.infrastructure_japan
terraform plan -destroy

# Destroy everything
terraform destroy

# Confirm by typing: yes
```

**Estimated destruction time:** 15-20 minutes

**Note:** Database deletion is the slowest part (~10 minutes).

For detailed cleanup instructions, see **[Deployment: Cleanup](docs/DEPLOYMENT.md#cleanup)**.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **AWS Documentation:** Comprehensive reference for all services
- **Terraform Registry:** AWS provider documentation and examples
- **Community:** Stack Overflow, Reddit r/aws, r/terraform for troubleshooting help

---

**Built 7 months ago as a learning exercise. Now certified and applying these lessons to production infrastructure.**

*This project shows authentic progression—from beginner debugging TGW routing to certified AWS Solutions Architect. The value isn't in perfection, but in demonstrating growth through honest reflection.*
