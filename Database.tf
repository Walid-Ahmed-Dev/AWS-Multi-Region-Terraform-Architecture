resource "aws_secretsmanager_secret" "db_admin_password" { #Manages secret
  name        = "dbAdminPassword"
  description = "Admin password for RDS instance"
  kms_key_id  = "alias/aws/secretsmanager"  # default KMS key for RDS. The secret is encrypted using this KMS Key. This KMS Key encryts the Data Encryption Key (DEK). The DEK is used to encrypt the secret data. 
}
resource "aws_secretsmanager_secret_version" "db_admin_password_version" { # creates different versions of the secret data. The secret data is the JSON encoded username and password.
  secret_id     = aws_secretsmanager_secret.db_admin_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_admin_password.result
  })
}
resource "random_password" "db_admin_password" { 
  length  = 16
  special = true
}



resource "aws_rds_cluster" "aurora_cluster" { #the container for the database instances and manages shared settings
  cluster_identifier      = "ultramarine"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.05.2" #bash aws rds describe-db-engine-versions
  master_username         = jsondecode(aws_secretsmanager_secret_version.db_admin_password_version.secret_string)["username"] #bash aws secretsmanager get-secret-value --secret-id dbAdminPassword --query SecretString --output text
  master_password         = jsondecode(aws_secretsmanager_secret_version.db_admin_password_version.secret_string)["password"]
  # Lines 26 and 27: 1-Access the secret data stored in AWS Secrets Manager. 2-Use jsondecode to convert the JSON-encoded secret string into a map(similar to a dictionary). 3-Extract the "username" and "password" from the map.
  vpc_security_group_ids  = [aws_security_group.Aurora-japan.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  allow_major_version_upgrade = true
  skip_final_snapshot = true
}
resource "aws_rds_cluster_instance" "aurora_instances" { #the actual database servers that run the database engine.
  count                   = 1
  identifier              = "ultramarine"
  instance_class          = "db.t3.medium"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.05.2"
  cluster_identifier      = aws_rds_cluster.aurora_cluster.id
  publicly_accessible     = false
  apply_immediately       = true
  auto_minor_version_upgrade = true
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "japan"
  subnet_ids = [aws_subnet.private-ap-northeast-1d.id, aws_subnet.private-ap-northeast-1c-2.id]
}





