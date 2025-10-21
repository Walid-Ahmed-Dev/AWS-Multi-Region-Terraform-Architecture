# Troubleshooting Guide

## Table of Contents
- [General Debugging Methodology](#general-debugging-methodology)
- [Terraform Issues](#terraform-issues)
- [Network Connectivity](#network-connectivity)
- [Application Issues](#application-issues)
- [Database Issues](#database-issues)
- [Syslog and Logging](#syslog-and-logging)
- [Security and Access](#security-and-access)
- [Performance Issues](#performance-issues)
- [Cost Optimization](#cost-optimization)

## General Debugging Methodology

### The 5-Step Debugging Process

**1. Identify the Problem**
```
- What is the expected behavior?
- What is the actual behavior?
- When did it start happening?
- What changed recently?
```

**2. Gather Information**
```
- Check AWS console
- Review Terraform state
- Examine CloudWatch logs
- Check security groups
- Review route tables
```

**3. Form a Hypothesis**
```
- What could cause this?
- What are the most likely causes?
- How can I test each hypothesis?
```

**4. Test the Hypothesis**
```
- Make one change at a time
- Document what you try
- Revert if it doesn't work
```

**5. Document the Solution**
```
- What was the root cause?
- How did you fix it?
- How can you prevent it?
```

### Essential Tools

```bash
# AWS CLI
aws --version

# Check AWS credentials
aws sts get-caller-identity

# Terraform
terraform version
terraform state list
terraform show

# Network debugging
ping, traceroute, dig, nslookup, curl, netcat

# System logs
journalctl, tail, grep
```

## Terraform Issues

### Issue: "Error acquiring the state lock"

**Symptom:**
```
Error: Error acquiring the state lock
Error message: ConditionalCheckFailedException: The conditional
request failed
Lock Info:
  ID:        xxxxx-xxxx-xxxx-xxxx-xxxxx
  Path:      walid-backend-089.com/terraformv2.tfstate
  Operation: OperationTypePlan
  Who:       user@hostname
  Version:   1.6.0
  Created:   2024-01-15 10:30:00.000000000 +0000 UTC
```

**Cause:** Another Terraform operation is running, or a previous operation crashed without releasing the lock.

**Solution:**

**Step 1: Check if Terraform is actually running**
```bash
# On your machine
ps aux | grep terraform

# If found, let it finish or kill it
kill -9 <pid>
```

**Step 2: If no Terraform running, force unlock**
```bash
terraform force-unlock <Lock-ID>

# Example:
terraform force-unlock aaaaa-bbbb-cccc-dddd-eeee
```

**Prevention:**
- Don't interrupt Terraform operations
- Use `-lock=false` only in emergencies
- Consider using Terraform Cloud for better locking

---

### Issue: "Resource already exists"

**Symptom:**
```
Error: Error creating VPC: VpcLimitExceeded: The maximum
number of VPCs has been reached.
```

**Cause:**
1. Running `terraform apply` twice
2. Manual resources created in console
3. AWS service limits reached

**Solution:**

**Step 1: Check if resource exists**
```bash
# List VPCs
aws ec2 describe-vpcs --region ap-northeast-1

# Check against Terraform state
terraform state list | grep vpc
```

**Step 2: Import existing resource**
```bash
# Import VPC into Terraform state
terraform import module.vpc_japan.aws_vpc.vpc vpc-xxxxx

# Now Terraform manages the existing resource
```

**Step 3: Or increase AWS limits**
```bash
# Request limit increase via AWS Support
# Service Quotas → EC2 → VPCs per Region → Request increase
```

---

### Issue: "Provider configuration not found"

**Symptom:**
```
Error: Provider configuration not found
A provider configuration for "aws.us-east-1" was not found.
```

**Cause:** Using provider alias without defining it.

**Solution:**

**Check `main.tf` has provider definition:**
```hcl
provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
```

**Then re-initialize:**
```bash
rm -rf .terraform
terraform init
```

---

### Issue: "Cycle Error"

**Symptom:**
```
Error: Cycle: module.vpc_japan.aws_route_table.private,
  aws_ec2_transit_gateway.TGW1
```

**Cause:** Circular dependency (A depends on B, B depends on A).

**Solution:**

**Identify the cycle:**
```bash
terraform graph | dot -Tpng > graph.png
# Open graph.png to visualize dependencies
```

**Break the cycle:**
```hcl
# Before (cyclic):
resource "aws_route_table" "private" {
  route {
    transit_gateway_id = var.TGW_id  # Depends on TGW
  }
}

# After (use ignore_changes):
resource "aws_route_table" "private" {
  lifecycle {
    ignore_changes = [route]
  }
}

# Add route separately
resource "aws_route" "private_tgw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = var.TGW_id
}
```

---

### Issue: "Variables.tf not found"

**Symptom:**
```
Error: Failed to read module directory
Module directory does not exist: ./modules/vpc
```

**Cause:** Running Terraform from wrong directory.

**Solution:**
```bash
# Check current directory
pwd
# Should be: .../AWS-Multi-Region-Terraform-Architecture

# If in wrong directory:
cd /path/to/AWS-Multi-Region-Terraform-Architecture

# Verify modules exist
ls -la modules/
```

## Network Connectivity

### Issue: Can't Ping Across Regions

**Symptom:** `ping 10.151.11.x` from Tokyo instance times out.

**Debugging Steps:**

**Step 1: Verify TGW Peering State**
```bash
aws ec2 describe-transit-gateway-peering-attachments \
  --region ap-northeast-1 \
  --query 'TransitGatewayPeeringAttachments[*].{State:State,Accepter:AccepterTgwInfo,Requester:RequesterTgwInfo}'

# State should be: "available"
# If "pending", peer hasn't been accepted
# If "failed", check if TGWs exist in both regions
```

**Step 2: Check TGW Route Table Association**
```bash
# Get TGW route table ID
TGW_RTB=$(aws ec2 describe-transit-gateway-route-tables \
  --region ap-northeast-1 \
  --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' \
  --output text)

# Check associations
aws ec2 get-transit-gateway-route-table-associations \
  --transit-gateway-route-table-id $TGW_RTB \
  --region ap-northeast-1

# Should show peering attachment associated
```

**Step 3: Check TGW Route Table Routes**
```bash
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id $TGW_RTB \
  --filters "Name=type,Values=static" \
  --region ap-northeast-1

# Should show route: 10.151.0.0/16 → peering attachment
```

**Step 4: Check VPC Route Table**
```bash
# Get private route table
RTB_ID=$(aws ec2 describe-route-tables \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=app1-private" \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

# Check routes
aws ec2 describe-route-tables \
  --route-table-ids $RTB_ID \
  --region ap-northeast-1 \
  --query 'RouteTables[0].Routes'

# Should show: 10.0.0.0/8 → TGW
```

**Step 5: Check Security Groups**
```bash
# ICMP (ping) must be allowed
aws ec2 describe-security-groups \
  --region ap-northeast-1 \
  --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions[?IpProtocol==`icmp`]'

# If empty, add ICMP rule:
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol icmp \
  --port -1 \
  --cidr 10.0.0.0/8 \
  --region ap-northeast-1
```

**Step 6: Check NACLs (Network ACLs)**
```bash
# Get subnet's NACL
aws ec2 describe-network-acls \
  --region ap-northeast-1 \
  --filters "Name=association.subnet-id,Values=<subnet-id>"

# Default NACLs allow all traffic
# Custom NACLs may block traffic
```

**Common Routing Issues:**

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Ping works Tokyo→Tokyo | Local routing OK | - |
| Ping fails Tokyo→Virginia | TGW routing issue | Check TGW route tables |
| Ping works one direction only | Asymmetric routing | Check both VPC route tables |
| Intermittent connectivity | Peering not fully established | Wait 5 mins, check attachment state |

---

### Issue: DNS Resolution Failing

**Symptom:** `dig wally.com` returns NXDOMAIN or no answer.

**Debugging:**

**Step 1: Check Route53 Hosted Zone Exists**
```bash
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`wally.com.`]'

# Should return zone ID
```

**Step 2: Check VPC Association**
```bash
aws route53 get-hosted-zone --id <zone-id>

# Should show VPCs:
# - vpc-xxxxx (Tokyo)
# - vpc-yyyyy (Virginia)
```

**Step 3: Check DNS Records**
```bash
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Should show:
# - A record: wally.com → 10.150.11.x (PRIMARY)
# - A record: wally.com → 10.150.13.x (SECONDARY)
```

**Step 4: Test DNS from Instance**
```bash
# SSH to instance, test DNS
dig wally.com +short
# Should return: 10.150.11.x

# If returns nothing, check:
# 1. Instance is in correct VPC
# 2. VPC has DNS resolution enabled
# 3. Using VPC DNS server (10.150.0.2)
```

**Step 5: Check VPC DNS Settings**
```bash
aws ec2 describe-vpc-attribute \
  --vpc-id <vpc-id> \
  --attribute enableDnsSupport \
  --region ap-northeast-1

# Should be: true

aws ec2 describe-vpc-attribute \
  --vpc-id <vpc-id> \
  --attribute enableDnsHostnames \
  --region ap-northeast-1

# Should be: true
```

**Fix if DNS disabled:**
```bash
aws ec2 modify-vpc-attribute \
  --vpc-id <vpc-id> \
  --enable-dns-support

aws ec2 modify-vpc-attribute \
  --vpc-id <vpc-id> \
  --enable-dns-hostnames
```

---

### Issue: NAT Gateway Not Working

**Symptom:** Private subnet instances can't reach internet.

**Debugging:**

**Step 1: Check NAT Gateway State**
```bash
aws ec2 describe-nat-gateways \
  --region ap-northeast-1 \
  --query 'NatGateways[*].{ID:NatGatewayId,State:State,SubnetId:SubnetId}'

# State should be: "available"
# SubnetId should be a PUBLIC subnet
```

**Step 2: Check Elastic IP**
```bash
aws ec2 describe-nat-gateways \
  --region ap-northeast-1 \
  --query 'NatGateways[0].NatGatewayAddresses'

# Should show public IP attached
```

**Step 3: Check Private Route Table**
```bash
aws ec2 describe-route-tables \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=app1-private" \
  --query 'RouteTables[0].Routes'

# Should show: 0.0.0.0/0 → nat-xxxxx
```

**Step 4: Check Internet Gateway**
```bash
# NAT Gateway subnet needs IGW route
aws ec2 describe-route-tables \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=app1-public" \
  --query 'RouteTables[0].Routes'

# Should show: 0.0.0.0/0 → igw-xxxxx
```

**Step 5: Test from Instance**
```bash
# SSH to private instance
curl -I https://www.google.com

# If times out:
# Check security group allows outbound HTTPS (port 443)
# Check NACL allows outbound traffic
```

## Application Issues

### Issue: ALB Returns 503 Service Unavailable

**Symptom:**
```bash
curl http://<alb-dns>
# Returns: 503 Service Temporarily Unavailable
```

**Cause:** No healthy targets in target group.

**Debugging:**

**Step 1: Check Target Health**
```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --region ap-northeast-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region ap-northeast-1

# Look for:
# "State": "healthy" (good)
# "State": "unhealthy" (bad)
# "Reason": "Target.ResponseCodeMismatch" (health check failing)
# "Reason": "Target.Timeout" (health check timing out)
```

**Step 2: If No Targets Registered**
```bash
# Check if ASG has instances
aws autoscaling describe-auto-scaling-groups \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `app1`)].{Desired:DesiredCapacity,Current:Instances|length(@),Instances:Instances[*].InstanceId}'

# If Desired=1 but Current=0:
# - Check launch template is valid
# - Check ASG has capacity (min/max settings)
# - Check CloudWatch for scaling activities
```

**Step 3: If Targets Unhealthy**
```bash
# Check health check configuration
aws elbv2 describe-target-groups \
  --target-group-arn $TG_ARN \
  --region ap-northeast-1 \
  --query 'TargetGroups[0].HealthCheckPath'

# Should be: "/"

# SSH to instance, test health check endpoint
curl http://localhost/
# Should return 200 OK with HTML
```

**Step 4: Check Security Groups**
```bash
# Application security group must allow traffic FROM ALB security group

# Get ALB security group
ALB_SG=$(aws elbv2 describe-load-balancers \
  --region ap-northeast-1 \
  --query 'LoadBalancers[0].SecurityGroups[0]' \
  --output text)

# Get instance security group ingress rules
aws ec2 describe-security-groups \
  --region ap-northeast-1 \
  --group-ids <instance-sg-id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`]'

# Should show: source = ALB security group
```

**Step 5: Check Instance Health**
```bash
# SSH to instance
systemctl status httpd

# If not running:
systemctl start httpd
systemctl enable httpd

# Check logs
tail -f /var/log/httpd/error_log
```

**Common ALB Issues:**

| Error Code | Meaning | Fix |
|------------|---------|-----|
| 503 | No healthy targets | Register instances, fix health checks |
| 504 | Gateway timeout | Increase timeout, check app performance |
| 502 | Bad gateway | Check app is running, returns valid HTTP |
| 404 | Not found | Check ALB listener rules, target group path |

---

### Issue: Application Instances Not Launching

**Symptom:** ASG shows desired=1 but current=0.

**Debugging:**

**Step 1: Check ASG Activity**
```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --max-records 10 \
  --region ap-northeast-1

# Look for:
# "StatusCode": "Failed"
# "StatusMessage": "..." (error details)
```

**Common Launch Failures:**

**Insufficient Capacity**
```
StatusMessage: "We currently do not have sufficient t2.micro capacity
in the Availability Zone you requested"

Fix: Change instance type or AZ in launch template
```

**Invalid AMI**
```
StatusMessage: "The AMI ID 'ami-xxxxx' does not exist"

Fix: Use correct AMI for the region
aws ec2 describe-images --image-ids <ami-id> --region ap-northeast-1
```

**Security Group Not Found**
```
StatusMessage: "The security group 'sg-xxxxx' does not exist"

Fix: Ensure security group exists in same VPC
aws ec2 describe-security-groups --group-ids <sg-id> --region ap-northeast-1
```

**Subnet Not Found**
```
StatusMessage: "The subnet ID 'subnet-xxxxx' does not exist"

Fix: Check ASG subnet configuration matches VPC
```

**Step 2: Try Manual Launch**
```bash
# Get launch template
LT_ID=$(aws ec2 describe-launch-templates \
  --region ap-northeast-1 \
  --query 'LaunchTemplates[0].LaunchTemplateId' \
  --output text)

# Try launching manually
aws ec2 run-instances \
  --launch-template LaunchTemplateId=$LT_ID \
  --subnet-id <subnet-id> \
  --region ap-northeast-1

# Check for errors
```

## Database Issues

### Issue: Can't Connect to Aurora Database

**Symptom:**
```bash
mysql -h <endpoint> -u admin -p
# ERROR 2003 (HY000): Can't connect to MySQL server on '<endpoint>' (110)
```

**Debugging:**

**Step 1: Check Database Status**
```bash
aws rds describe-db-clusters \
  --db-cluster-identifier ultramarine \
  --region ap-northeast-1 \
  --query 'DBClusters[0].Status'

# Should be: "available"
# If "creating", wait (can take 10-15 minutes)
# If "failed", check CloudWatch logs for errors
```

**Step 2: Verify Endpoint**
```bash
aws rds describe-db-clusters \
  --db-cluster-identifier ultramarine \
  --region ap-northeast-1 \
  --query 'DBClusters[0].Endpoint'

# Use this endpoint for writer (read-write)

# For read-only:
aws rds describe-db-clusters \
  --db-cluster-identifier ultramarine \
  --region ap-northeast-1 \
  --query 'DBClusters[0].ReaderEndpoint'
```

**Step 3: Check Security Group**
```bash
# Get database security group
DB_SG=$(aws rds describe-db-clusters \
  --db-cluster-identifier ultramarine \
  --region ap-northeast-1 \
  --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

# Check inbound rules
aws ec2 describe-security-groups \
  --group-ids $DB_SG \
  --region ap-northeast-1 \
  --query 'SecurityGroups[0].IpPermissions'

# Should allow port 3306 from application security group or VPC CIDR
```

**Fix Security Group:**
```bash
# Allow from application security group
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG \
  --protocol tcp \
  --port 3306 \
  --source-group <app-sg-id> \
  --region ap-northeast-1
```

**Step 4: Check Network Path**
```bash
# Database should be in private subnet
aws rds describe-db-subnet-groups \
  --db-subnet-group-name japan \
  --region ap-northeast-1 \
  --query 'DBSubnetGroups[0].Subnets[*].{SubnetId:SubnetIdentifier,AZ:SubnetAvailabilityZone.Name}'

# Verify these subnets exist and are private
```

**Step 5: Test from Instance in Same VPC**
```bash
# SSH to EC2 instance in same VPC
telnet <db-endpoint> 3306

# If "Connected to...", network is OK
# If "Connection timed out", check security group or route table
# If "Connection refused", database not listening
```

**Step 6: Verify Credentials**
```bash
# Get credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id dbAdminPassword \
  --region ap-northeast-1 \
  --query 'SecretString' --output text | jq .

# Should show:
# {
#   "username": "admin",
#   "password": "xxxxxxxxxxxxxxxx"
# }

# Try connecting with these exact credentials
```

---

### Issue: Database Performance Issues

**Symptom:** Queries are slow, high latency.

**Debugging:**

**Step 1: Check CloudWatch Metrics**
```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=ultramarine \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 3600 \
  --statistics Average \
  --region ap-northeast-1

# If >80%: Scale up instance class

# Database Connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=ultramarine \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 3600 \
  --statistics Maximum \
  --region ap-northeast-1

# If >80% of max_connections: Investigate connection leaks
```

**Step 2: Enable Enhanced Monitoring**
```bash
# If not already enabled
aws rds modify-db-cluster \
  --db-cluster-identifier ultramarine \
  --enable-cloudwatch-logs-exports '["audit","error","general","slowquery"]' \
  --region ap-northeast-1
```

**Step 3: Check Slow Query Log**
```bash
# Download slow query log
aws rds download-db-log-file-portion \
  --db-instance-identifier ultramarine \
  --log-file-name slowquery/mysql-slowquery.log \
  --region ap-northeast-1

# Analyze slow queries, add indexes or optimize
```

## Syslog and Logging

### Issue: Logs Not Appearing on Syslog Server

**Symptom:** Application instances running, but logs not appearing in `/var/log/messages` on syslog server.

**Debugging:**

**Step 1: Test DNS Resolution**
```bash
# From application instance
dig wally.com +short

# Should return: 10.150.11.x (primary syslog server)
# Or: 10.150.13.x (if primary failed over)

# If returns nothing:
# - Check Route53 hosted zone exists
# - Check VPC is associated with hosted zone
# - Check DNS records exist
```

**Step 2: Test Network Connectivity**
```bash
# From application instance
nc -zv wally.com 514

# Or
telnet wally.com 514

# If "Connection refused": rsyslog not listening
# If "No route to host": routing issue
# If "Connection timed out": security group issue
```

**Step 3: Check rsyslog Client Configuration**
```bash
# On application instance
cat /etc/rsyslog.d/remote.conf

# Should contain:
# *.* @@wally.com:514

# @@ = TCP (reliable)
# @ = UDP (fast but lossy)

# Check rsyslog status
systemctl status rsyslog

# Check for errors
journalctl -u rsyslog -n 50
```

**Step 4: Check rsyslog Server Configuration**
```bash
# On syslog server
cat /etc/rsyslog.conf | grep -A 5 "module(load="

# Should show:
# module(load="imtcp")
# input(type="imtcp" port="514")
# module(load="imudp")
# input(type="imudp" port="514")

# Check rsyslog is listening
netstat -tuln | grep 514

# Should show:
# tcp   0.0.0.0:514   LISTEN
# udp   0.0.0.0:514
```

**Step 5: Check Security Group**
```bash
# Syslog server security group must allow port 514 (TCP/UDP)
aws ec2 describe-security-groups \
  --region ap-northeast-1 \
  --group-ids <syslog-sg-id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`514`]'

# Should show TCP and UDP rules
```

**Step 6: Test Manual Log**
```bash
# From application instance
logger "Test message from $(hostname) at $(date)"

# On syslog server (immediately after)
tail -f /var/log/messages | grep "Test message"

# Should appear within seconds
```

---

### Issue: Syslog Failover Not Working

**Symptom:** Primary syslog server down, but logs still trying to reach it.

**Debugging:**

**Step 1: Check Route53 Health Check**
```bash
# Get health check ID
HC_ID=$(aws route53 list-health-checks \
  --query 'HealthChecks[?HealthCheckConfig.AlarmIdentifier.Name==`syslog`].Id' \
  --output text)

# Check health status
aws route53 get-health-check-status \
  --health-check-id $HC_ID

# Should show:
# "StatusReport": {
#   "Status": "Unhealthy"  (if primary is down)
# }
```

**Step 2: Check CloudWatch Alarm**
```bash
aws cloudwatch describe-alarms \
  --alarm-names syslog \
  --region ap-northeast-1 \
  --query 'MetricAlarms[0].StateValue'

# If primary is down, should be: "ALARM"
# If primary is up, should be: "OK"
```

**Step 3: Check DNS Resolution**
```bash
# From application instance
dig wally.com +short

# Wait 60-90 seconds (DNS TTL + health check)
dig wally.com +short

# Should now return: 10.150.13.x (secondary)
```

**Step 4: Force DNS Cache Clear**
```bash
# On application instance
systemctl restart rsyslog

# This forces rsyslog to re-resolve DNS
```

**Known Limitation:**
```
Route53 failover does NOT automatically fail back to primary
once it recovers. DNS stays on secondary until secondary fails.

Workaround:
- Manually update health check to point to secondary
- Use weighted routing instead of failover
- Use Network Load Balancer for instant failover
```

## Security and Access

### Issue: Can't SSH to Instance

**Symptom:**
```bash
ssh -i key.pem ec2-user@<private-ip>
# Connection timed out
```

**Cause:** Instance is in private subnet, no direct internet access.

**Solutions:**

**Option 1: EC2 Instance Connect (Recommended)**
```bash
# List Instance Connect endpoints
aws ec2 describe-instance-connect-endpoints \
  --region ap-northeast-1

# Connect via endpoint
aws ec2-instance-connect ssh \
  --instance-id <instance-id> \
  --region ap-northeast-1
```

**Option 2: SSH via Bastion (If Deployed)**
```bash
# SSH to bastion in public subnet
ssh -i key.pem ec2-user@<bastion-public-ip>

# From bastion, SSH to private instance
ssh ec2-user@<private-ip>
```

**Option 3: Systems Manager Session Manager (Requires SSM Agent)**
```bash
aws ssm start-session \
  --target <instance-id> \
  --region ap-northeast-1

# No SSH key required, uses IAM authentication
```

---

### Issue: "Permission Denied (publickey)"

**Symptom:**
```bash
ssh -i key.pem ec2-user@<ip>
# Permission denied (publickey)
```

**Causes:**
1. Wrong key file
2. Wrong username
3. Wrong key permissions

**Solutions:**

**Check Key Permissions:**
```bash
ls -la key.pem
# Should be: -rw------- (600)

# Fix if wrong:
chmod 600 key.pem
```

**Verify Username:**
```bash
# Amazon Linux 2: ec2-user
# Ubuntu: ubuntu
# RHEL: ec2-user

# Try correct username:
ssh -i key.pem ec2-user@<ip>
```

**Verify Key Matches Instance:**
```bash
# Get instance key name
aws ec2 describe-instances \
  --instance-ids <instance-id> \
  --region ap-northeast-1 \
  --query 'Reservations[0].Instances[0].KeyName'

# Should match your key pair name
```

**Get Correct Key from Terraform:**
```bash
terraform output -raw private_key-japan > new-key.pem
chmod 600 new-key.pem
ssh -i new-key.pem ec2-user@<ip>
```

## Performance Issues

### Issue: High Latency for Cross-Region Requests

**Symptom:** Requests from Virginia to Tokyo database are slow.

**Expected:** Cross-region latency is inherent (~150ms US-Asia).

**Optimization:**

**Short Term:**
- Cache database queries in application
- Use ElastiCache for frequently accessed data
- Minimize cross-region database calls

**Long Term:**
- Deploy Aurora Global Database (cross-region read replicas)
- Use Virginia read replica for Virginia instances
- Implement application-level caching

**Measure Latency:**
```bash
# From Virginia instance
ping 10.150.11.x -c 10

# Typical latency:
# Same AZ: 0.5-1ms
# Same region, different AZ: 1-3ms
# Cross-region: 150-200ms (US-Asia)
```

---

### Issue: Auto Scaling Not Responding to Load

**Symptom:** High CPU but ASG not scaling out.

**Debugging:**

**Step 1: Check Scaling Policy**
```bash
aws autoscaling describe-policies \
  --auto-scaling-group-name <asg-name> \
  --region ap-northeast-1

# Check TargetValue (should be 75.0)
```

**Step 2: Check Current CPU**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name> \
  --start-time 2024-01-15T10:00:00Z \
  --end-time 2024-01-15T11:00:00Z \
  --period 300 \
  --statistics Average \
  --region ap-northeast-1

# If >75%, scaling should trigger
```

**Step 3: Check ASG Limits**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name <asg-name> \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity}'

# If Desired == Max, can't scale further
# Increase MaxSize in Terraform
```

**Step 4: Check Cooldown**
```bash
# Scaling policies have cooldown periods
# Default: 300 seconds (5 minutes)

# Check last scaling activity
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --max-records 5 \
  --region ap-northeast-1

# If recent activity, may be in cooldown
```

## Cost Optimization

### Issue: Unexpected High AWS Bill

**Investigation:**

**Step 1: Enable Cost Explorer**
```bash
# View costs by service
# Console: AWS Cost Management → Cost Explorer

# Via CLI (requires Cost Explorer API access)
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

**Step 2: Identify Top Cost Drivers**

Common culprits:
1. **NAT Gateway** ($32/month + data transfer)
2. **Transit Gateway** ($36/month per TGW + peering + data)
3. **RDS Aurora** ($50-100/month)
4. **Application Load Balancer** ($18/month each)
5. **Data Transfer** (cross-region, to internet)

**Step 3: Optimize**

**NAT Gateway:**
```bash
# Option 1: Use VPC Endpoints instead
aws ec2 create-vpc-endpoint \
  --vpc-id <vpc-id> \
  --service-name com.amazonaws.ap-northeast-1.s3 \
  --route-table-ids <rtb-id>

# Free for S3, saves NAT Gateway data charges

# Option 2: Single NAT (reduces HA)
# Remove second NAT Gateway
```

**Transit Gateway:**
```bash
# Consider VPC Peering instead (free)
# Only if you don't need hub-spoke topology
```

**Aurora:**
```bash
# Option 1: Smaller instance
aws rds modify-db-cluster-instance \
  --db-instance-identifier ultramarine \
  --db-instance-class db.t3.small \
  --region ap-northeast-1

# Option 2: Aurora Serverless v2
# Pay per second instead of per hour
```

**ALB:**
```bash
# If low traffic, consider:
# - Single ALB with host-based routing
# - Or use EC2 with Elastic IP (not recommended for production)
```

**Step 4: Set Up Budgets**
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

---

### Quick Reference: Resource Costs

| Resource | Unit Cost | Monthly (24/7) |
|----------|-----------|----------------|
| t2.micro | $0.0116/hr | $8.47 |
| t3.micro | $0.0104/hr | $7.59 |
| db.t3.medium | $0.082/hr | $59.86 |
| NAT Gateway | $0.045/hr | $32.85 |
| Transit Gateway | $0.05/hr | $36.50 |
| TGW Attachment | $0.05/hr | $36.50 |
| ALB | $0.0225/hr | $16.43 |
| Route53 Hosted Zone | - | $0.50 |
| Health Check | - | $0.50 |
| Data Transfer (out) | $0.09/GB | Variable |

**Estimated Total:** $240-350/month (depending on data transfer)

---

## Additional Resources

- **AWS Documentation:** https://docs.aws.amazon.com
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws
- **AWS Support:** https://console.aws.amazon.com/support
- **Stack Overflow:** Search for specific error messages

**For Issues Not Covered:**
1. Check AWS Service Health Dashboard
2. Review CloudTrail for API errors
3. Check Terraform state for drift: `terraform plan`
4. Enable debug logging: `TF_LOG=DEBUG terraform apply`

**Get Help:**
- Open an issue on GitHub (if this is open source)
- AWS Support (if you have a support plan)
- AWS Forums: https://forums.aws.amazon.com
- Reddit: r/aws, r/terraform
