terraform {
    backend "s3" {
        bucket = "walid-backend-089.com"
        key = "terraformv2.tfstate" #name of the state file that
        region = "us-east-1"  
    }

}