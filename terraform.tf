terraform {
  required_version = "1.7.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.38.0"
    }
  }

  backend "s3" {
    region         = "ap-northeast-1"
    bucket         = "prepare-bucketterraformstates-p3c1oilnsc6q"
    key            = "cloud/tfstate.json"
    dynamodb_table = "prepare-TableTerraformLocks-67NUO49JYVQH"
  }
}

locals {
  region      = "ap-northeast-1"
  system_name = "cloud"
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      SystemName = local.system_name
    }
  }
}

module "common" {
  source = "./terraform_modules/common"

  slack_incoming_webhooks = [
    var.SLACK_INCOMING_WEBHOOK_01,
    var.SLACK_INCOMING_WEBHOOK_02,
  ]
}

variable "SLACK_INCOMING_WEBHOOK_01" {
  type     = string
  nullable = false
}

variable "SLACK_INCOMING_WEBHOOK_02" {
  type     = string
  nullable = false
}