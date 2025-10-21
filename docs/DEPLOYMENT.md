# Deployment Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Initial Setup](#initial-setup)
- [Deployment Steps](#deployment-steps)
- [Post-Deployment Verification](#post-deployment-verification)
- [Accessing Resources](#accessing-resources)
- [Common Issues](#common-issues)
- [Cleanup](#cleanup)

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| Terraform | 1.0+ | [terraform.io](https://www.terraform.io/downloads) |
| AWS CLI | 2.0+ | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Git | 2.0+ | [git-scm.com](https://git-scm.com/) |

**Verify installations:**
```bash
terraform version  # Should show v1.0 or higher
aws --version      # Should show aws-cli/2.x
git --version      # Should show git version 2.x
```

### AWS Account Requirements

**1. AWS Account with Administrator Access**
```
You'll need permissions to create:
- VPCs, subnets, route tables
- Transit Gateways and peering
- EC2 instances, Auto Scaling Groups, Load Balancers
- RDS Aurora clusters
- Route53 hosted zones and health checks
- CloudWatch alarms
- Secrets Manager secrets
- IAM roles and policies (future)
```

**2. AWS CLI Configuration**
```bash
# Configure AWS credentials
aws configure

# You'll be prompted for:
AWS Access Key ID: AKIA...
AWS Secret Access Key: ****
Default region name: ap-northeast-1
Default output format: json
```

**Verify access:**
```bash
aws sts get-caller-identity

# Should output:
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

**3. S3 Bucket for Terraform State**

This project uses remote state storage in S3. Create the bucket manually:

```bash
# Create S3 bucket (use your own unique name)
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning (important for state safety)
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

**4. SSH Key Pair (Optional)**

The project generates key pairs automatically via Terraform. However, if you want to use existing keys:

```bash
# List existing key pairs
aws ec2 describe-key-pairs --region ap-northeast-1
aws ec2 describe-key-pairs --region us-east-1

# If "key" doesn't exist, Terraform will create it
```

### Cost Considerations

**Estimated Monthly Cost:** $250-350

| Service | Quantity | Cost/Month |
|---------|----------|------------|
| EC2 Instances (t2.micro/t3.micro) | 4-6 | $30-50 |
| Application Load Balancers | 2 | $35 |
| Transit Gateways | 2 + peering | $108 |
| NAT Gateways | 2 | $65 |
| Aurora db.t3.medium | 1 cluster | $60 |
| Route53 (hosted zones + health checks) | 2 zones + 1 check | $1.50 |
| Data Transfer | Variable | $10-30 |

**To minimize costs:**
- Use AWS Free Tier (first 12 months): Covers some EC2, RDS usage
- Deploy only Tokyo region initially (cut costs in half)
- Use smaller instance types
- Delete resources when not in use

**Set up billing alerts:**
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json

# budget.json:
{
  "BudgetName": "Monthly-Infrastructure-Budget",
  "BudgetLimit": {
    "Amount": "300",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

## Pre-Deployment Checklist

Before running `terraform apply`, ensure:

- [ ] AWS CLI configured with valid credentials
- [ ] S3 bucket created for Terraform state
- [ ] Updated `backend.tf` with your S3 bucket name
- [ ] Reviewed `variables.tf` for any customizations needed
- [ ] Sufficient AWS service limits in both regions
- [ ] Budget alerts configured (optional but recommended)
- [ ] You understand the costs ($250-350/month)

**Check AWS Service Limits:**
```bash
# Check VPC limit (default: 5 per region)
aws ec2 describe-vpcs --region ap-northeast-1 --query 'Vpcs | length(@)'
aws ec2 describe-vpcs --region us-east-1 --query 'Vpcs | length(@)'

# Check EIP limit (default: 5 per region, need 2)
aws ec2 describe-addresses --region ap-northeast-1 --query 'Addresses | length(@)'
aws ec2 describe-addresses --region us-east-1 --query 'Addresses | length(@)'
```

## Initial Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd AWS-Multi-Region-Terraform-Architecture
```

### 2. Configure Backend

Edit `backend.tf` with your S3 bucket name:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"  # CHANGE THIS
    key    = "terraformv2.tfstate"
    region = "us-east-1"
  }
}
```

### 3. Review Variables (Optional)

Check `variables.tf` to see if any customizations are needed. Current variables are hardcoded in the module calls in `main.tf`.

**To make configurable:**
```hcl
# Add to variables.tf:
variable "tokyo_cidr" {
  description = "CIDR block for Tokyo VPC"
  default     = "10.150.0.0/16"
}

# Then use in main.tf:
module "vpc_japan" {
  cidr_block = var.tokyo_cidr
}
```

### 4. Initialize Terraform

```bash
terraform init

# Expected output:
# Initializing modules...
# Initializing the backend...
# Initializing provider plugins...
# Terraform has been successfully initialized!
```

**If initialization fails:**
```bash
# Clear cached plugins and try again
rm -rf .terraform
rm .terraform.lock.hcl
terraform init
```

## Deployment Steps

### Step 1: Validate Configuration

```bash
terraform validate

# Expected output:
# Success! The configuration is valid.
```

**If validation fails:**
- Check syntax errors in .tf files
- Ensure all required variables are set
- Verify module paths are correct

### Step 2: Plan Deployment

```bash
terraform plan -out=tfplan

# This will:
# 1. Show all resources to be created (~80-100 resources)
# 2. Save the plan to a file for consistent apply
```

**Review the plan carefully:**
- Check resource counts (should be ~80-100 resources)
- Verify regions are correct (ap-northeast-1, us-east-1)
- Ensure CIDR blocks don't overlap (10.150.x vs 10.151.x)
- Look for any warnings or errors

**Expected resource counts:**
```
Plan: ~85 to add, 0 to change, 0 to destroy.

Resources include:
- 2 VPCs (Tokyo, Virginia)
- 8+ subnets
- 2 Transit Gateways + peering
- 2 ALBs
- 2 Auto Scaling Groups
- 2 Syslog servers
- 1 Aurora cluster
- Route53 zones and records
- Security groups
- CloudWatch alarms
- Secrets Manager secrets
- And more...
```

### Step 3: Apply Configuration

```bash
terraform apply tfplan

# Or interactively:
terraform apply
```

**Timeline:**
```
0:00  - Start
0:30  - VPCs and networking created
2:00  - Transit Gateways created
3:00  - TGW peering established
5:00  - EC2 instances launching
7:00  - ALBs becoming healthy
10:00 - Aurora cluster creating
15:00 - Complete!
```

**What to watch for:**
- No red ERROR messages
- Yellow warnings are usually okay (deprecation notices)
- Progress will seem slow during Aurora creation (10+ minutes)

**If deployment fails mid-way:**
```bash
# Terraform will show you the error
# Fix the issue, then run again
terraform apply

# Terraform will pick up where it left off (stateful)
```

### Step 4: Save Outputs

```bash
# View all outputs
terraform output

# Save specific outputs
terraform output ALB-DNS > tokyo-alb.txt
terraform output ALB-DNS-NewYork > virginia-alb.txt
terraform output -raw private_key-japan > keys/tokyo-key.pem
terraform output -raw private_key-NewYork > keys/virginia-key.pem

# Set proper permissions on keys
chmod 600 keys/*.pem
```

**Important outputs:**
- `ALB-DNS`: Tokyo Application Load Balancer URL
- `ALB-DNS-NewYork`: Virginia Application Load Balancer URL
- `private_key-japan`: SSH key for Tokyo instances (sensitive)
- `private_key-NewYork`: SSH key for Virginia instances (sensitive)
- `vpc_id`: Tokyo VPC ID
- Various subnet IDs and security group IDs

## Post-Deployment Verification

### 1. Verify VPC Connectivity

**Check VPC creation:**
```bash
# Tokyo VPC
aws ec2 describe-vpcs \
  --region ap-northeast-1 \
  --filters "Name=tag:Service,Values=J-Tele-Doctor" \
  --query 'Vpcs[0].{VpcId:VpcId,CIDR:CidrBlock}'

# Virginia VPC
aws ec2 describe-vpcs \
  --region us-east-1 \
  --filters "Name=tag:Service,Values=J-Tele-Doctor" \
  --query 'Vpcs[0].{VpcId:VpcId,CIDR:CidrBlock}'
```

### 2. Verify Transit Gateway Peering

```bash
# Check TGW peering status (should be "available")
aws ec2 describe-transit-gateway-peering-attachments \
  --region ap-northeast-1 \
  --query 'TransitGatewayPeeringAttachments[0].State'

# Should output: "available"
```

### 3. Test Application Endpoints

**Tokyo Application:**
```bash
# Get ALB DNS
TOKYO_ALB=$(terraform output -raw ALB-DNS)

# Test HTTP endpoint
curl http://$TOKYO_ALB

# Should return HTML page with instance metadata
```

**Virginia Application:**
```bash
# Get ALB DNS
VIRGINIA_ALB=$(terraform output -raw ALB-DNS-NewYork)

# Test HTTP endpoint
curl http://$VIRGINIA_ALB

# Should return HTML page with instance metadata
```

**Expected response:**
```html
<!doctype html>
<html>
  <h1>When TSA Keisha sees a Passportbro</h1>
  <p><b>Instance Private Ip Address:</b> 10.15x.xx.xx</p>
  <p><b>Availability Zone:</b> ap-northeast-1a</p>
  <p><b>Virtual Private Cloud (VPC):</b> vpc-xxxxx</p>
</html>
```

### 4. Verify Auto Scaling Groups

```bash
# Tokyo ASG
aws autoscaling describe-auto-scaling-groups \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `app1`)].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Current:Instances|length(@)}'

# Virginia ASG
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `app1`)].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Current:Instances|length(@)}'
```

**Expected:** Desired=1, Current=1 for both

### 5. Verify Database

```bash
# Check Aurora cluster status
aws rds describe-db-clusters \
  --region ap-northeast-1 \
  --db-cluster-identifier ultramarine \
  --query 'DBClusters[0].{Status:Status,Endpoint:Endpoint,Engine:Engine}'

# Status should be: "available"
```

**Test database connectivity (from Tokyo instance):**
```bash
# Connect to Tokyo instance via Instance Connect
# Then test MySQL connection:
mysql -h <cluster-endpoint> -u admin -p

# Get password from Secrets Manager:
aws secretsmanager get-secret-value \
  --secret-id dbAdminPassword \
  --region ap-northeast-1 \
  --query 'SecretString' --output text | jq -r '.password'
```

### 6. Verify Syslog Failover

**Check Route53 health check:**
```bash
# Get health check ID
aws route53 list-health-checks \
  --query 'HealthChecks[?HealthCheckConfig.AlarmIdentifier.Name==`syslog`].Id' \
  --output text

# Check health status
aws route53 get-health-check-status \
  --health-check-id <health-check-id>

# Status should show "Healthy"
```

**Test DNS resolution:**
```bash
# From a Tokyo instance:
dig @10.150.0.2 wally.com +short

# Should return primary syslog IP: 10.150.11.x
```

**Test log forwarding:**
```bash
# From an application instance:
logger "Test message from $(hostname)"

# On syslog server:
tail -f /var/log/messages | grep "Test message"
```

### 7. Verify Cross-Region Connectivity

**From Virginia instance, ping Tokyo instance:**
```bash
# Get instance IPs
TOKYO_IP=$(aws ec2 describe-instances \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=*app1*" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

VIRGINIA_IP=$(aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=*app1*" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# From Virginia instance, test connectivity
ping -c 3 $TOKYO_IP

# Should succeed if TGW routing is correct
```

## Accessing Resources

### Accessing EC2 Instances

**Method 1: EC2 Instance Connect (Recommended)**

The project deploys an EC2 Instance Connect Endpoint in Tokyo:

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=syslog-server" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Connect via Instance Connect
aws ec2-instance-connect ssh \
  --region ap-northeast-1 \
  --instance-id $INSTANCE_ID
```

**Method 2: SSH with Generated Key**

```bash
# Get private key
terraform output -raw private_key-japan > tokyo-key.pem
chmod 600 tokyo-key.pem

# Get instance IP (must be reachable - use public IP if available)
INSTANCE_IP=$(aws ec2 describe-instances \
  --region ap-northeast-1 \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# SSH to instance
ssh -i tokyo-key.pem ec2-user@$INSTANCE_IP
```

**Method 3: Systems Manager Session Manager (Future Enhancement)**

Not currently implemented, but recommended for production:
```bash
# Requires SSM agent installed and IAM role attached
aws ssm start-session --target $INSTANCE_ID --region ap-northeast-1
```

### Accessing the Database

**From an EC2 instance in the same VPC:**

```bash
# Get database endpoint
DB_ENDPOINT=$(aws rds describe-db-clusters \
  --region ap-northeast-1 \
  --db-cluster-identifier ultramarine \
  --query 'DBClusters[0].Endpoint' \
  --output text)

# Get password
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id dbAdminPassword \
  --region ap-northeast-1 \
  --query 'SecretString' \
  --output text | jq -r '.password')

# Connect
mysql -h $DB_ENDPOINT -u admin -p$DB_PASSWORD
```

**From your local machine:**

Aurora is in a private subnet and not publicly accessible (by design). To connect:

1. **SSH tunnel through a bastion:**
```bash
# Forward local port 3306 to Aurora through Tokyo instance
ssh -i tokyo-key.pem -L 3306:$DB_ENDPOINT:3306 ec2-user@<bastion-ip>

# Then connect to localhost
mysql -h 127.0.0.1 -u admin -p
```

2. **Or temporarily allow public access (NOT RECOMMENDED for production):**
```bash
aws rds modify-db-cluster \
  --db-cluster-identifier ultramarine \
  --publicly-accessible \
  --region ap-northeast-1
```

### Viewing Logs

**Application instance logs:**
```bash
# SSH to instance, then:
sudo tail -f /var/log/httpd/access_log    # HTTP access logs
sudo tail -f /var/log/httpd/error_log     # HTTP error logs
sudo tail -f /var/log/messages             # System logs
```

**Syslog server logs:**
```bash
# SSH to syslog server, then:
sudo tail -f /var/log/messages

# You should see logs from all application instances:
# "Nov 16 12:34:56 app1-instance systemd: Started httpd"
```

**CloudWatch Logs (if configured):**
```bash
aws logs tail /aws/ec2/app1 --follow --region ap-northeast-1
```

## Common Issues

### Issue 1: Terraform Plan Shows Many Changes on Second Run

**Symptom:**
```
terraform plan
# Shows changes even though nothing was modified
```

**Causes:**
- Computed values (instance IDs, ARNs)
- Resource drift (manual changes in console)
- Version upgrades (Terraform or providers)

**Solution:**
```bash
# Refresh state to sync with reality
terraform refresh

# If still shows changes, investigate specific resources
terraform plan | grep "# forces replacement"
```

### Issue 2: Transit Gateway Peering Not Working

**Symptom:** Can't ping across regions

**Checklist:**
1. [ ] Peering attachment state is "available"
2. [ ] Both TGWs have route table associations
3. [ ] Both TGW route tables have static routes
4. [ ] VPC route tables point to TGW for 10.0.0.0/8
5. [ ] Security groups allow ICMP (ping)
6. [ ] NACLs allow traffic (default: allow all)

**Debug commands:**
```bash
# Check TGW peering
aws ec2 describe-transit-gateway-peering-attachments --region ap-northeast-1

# Check TGW route tables
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id <tgw-rtb-id> \
  --filters "Name=type,Values=static" \
  --region ap-northeast-1

# Check VPC route tables
aws ec2 describe-route-tables \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=app1-private"
```

### Issue 3: ALB Returns 503 Service Unavailable

**Symptom:** `curl http://<alb-dns>` returns 503

**Causes:**
1. No healthy targets in target group
2. Security group blocking ALB → instance traffic
3. Instance httpd not running
4. Health check failing

**Debug:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --region ap-northeast-1

# Should show:
# "State": "healthy"

# If unhealthy, check:
# 1. Instance security group allows port 80 from ALB SG
# 2. httpd is running: ssh to instance → systemctl status httpd
# 3. Health check path exists: curl http://localhost/
```

### Issue 4: Database Connection Timeout

**Symptom:** `mysql -h <endpoint>` times out

**Causes:**
1. Security group blocking port 3306
2. Wrong subnet (database in private, connecting from public)
3. Database not fully initialized

**Debug:**
```bash
# Check database status
aws rds describe-db-clusters \
  --db-cluster-identifier ultramarine \
  --region ap-northeast-1 \
  --query 'DBClusters[0].Status'

# Should be: "available"

# Check security group
aws ec2 describe-security-groups \
  --group-ids <db-sg-id> \
  --region ap-northeast-1 \
  --query 'SecurityGroups[0].IpPermissions'

# Should show port 3306 allowed from application SG or VPC CIDR
```

### Issue 5: Syslog Logs Not Appearing

**Symptom:** Application logs not showing on syslog server

**Debug:**
```bash
# On application instance:
# Check DNS resolution
dig wally.com +short
# Should return: 10.150.11.x (primary) or 10.150.13.x (secondary)

# Check rsyslog config
cat /etc/rsyslog.d/remote.conf
# Should contain: *.* @@wally.com:514

# Check rsyslog status
systemctl status rsyslog

# Test manual log
logger "Test from $(hostname)"

# On syslog server:
tail -f /var/log/messages | grep "Test from"
```

### Issue 6: High AWS Costs

**Symptom:** Bill is higher than expected

**Investigation:**
```bash
# Check resource counts
terraform state list | wc -l

# Check NAT Gateway data transfer
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=<nat-gw-id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum \
  --region ap-northeast-1

# Enable Cost Explorer for detailed breakdown
```

**Mitigation:**
- Delete non-essential resources: `terraform destroy -target=module.vpc_NewYork`
- Stop instances when not in use
- Use smaller instance types
- Remove NAT Gateway if not needed

## Cleanup

### Full Cleanup (Delete Everything)

**WARNING:** This will delete all resources. Data will be lost!

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing: yes
```

**Expected timeline:**
- 0-5 min: ALBs, EC2 instances terminating
- 5-10 min: Database cluster deleting (slowest)
- 10-15 min: TGW peering and networking cleanup
- 15-20 min: Complete

**Manual cleanup required:**
```bash
# Terraform doesn't delete the S3 state bucket
aws s3 rb s3://your-terraform-state-bucket --force

# May need to manually delete Route53 hosted zones if issues
aws route53 delete-hosted-zone --id <zone-id>
```

### Partial Cleanup (Keep Tokyo, Remove Virginia)

```bash
# Destroy only Virginia resources
terraform destroy \
  -target=module.vpc_NewYork \
  -target=module.infrastructure_NewYork \
  -target=module.TGW_NewYork \
  -target=aws_ec2_transit_gateway_peering_attachment.Japan_NewYork_Peer_Request

# Note: This may require manual cleanup of peering connections
```

### Troubleshooting Cleanup Issues

**Issue: "VPC has dependencies and cannot be deleted"**
```bash
# Find and delete ENIs
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --region ap-northeast-1

# Delete each ENI
aws ec2 delete-network-interface --network-interface-id <eni-id> --region ap-northeast-1

# Then retry destroy
terraform destroy
```

**Issue: "Database cluster has snapshot protection"**
```bash
# Skip final snapshot (data loss!)
terraform destroy -var="skip_final_snapshot=true"

# Or manually delete cluster first
aws rds delete-db-cluster \
  --db-cluster-identifier ultramarine \
  --skip-final-snapshot \
  --region ap-northeast-1
```

## Next Steps

After successful deployment:

1. **Review Architecture Documentation:**
   - Read `docs/ARCHITECTURE.md` for detailed design
   - Read `docs/DESIGN_DECISIONS.md` for trade-off analysis
   - Read `docs/LESSONS_LEARNED.md` for reflections

2. **Implement Security Improvements:**
   - Restrict database security group to application tier only
   - Remove SSH access, implement Systems Manager
   - Enable HTTPS on ALBs with ACM certificates

3. **Set Up Monitoring:**
   - Create CloudWatch dashboard
   - Configure CloudWatch Logs forwarding
   - Set up SNS alerts for critical alarms

4. **Test Failure Scenarios:**
   - Terminate primary syslog server, verify failover
   - Terminate application instance, verify ASG recovery
   - Simulate Aurora failover

5. **Document Custom Changes:**
   - If you modify the infrastructure, update documentation
   - Keep README.md synchronized with actual deployment
   - Add any custom configurations to this guide

## Support and Resources

- **Terraform Documentation:** https://www.terraform.io/docs
- **AWS Documentation:** https://docs.aws.amazon.com
- **Project Issues:** [GitHub Issues](your-repo-url/issues)
- **AWS Support:** https://console.aws.amazon.com/support

---

**Deployment complete!** Your multi-region infrastructure is now running.
