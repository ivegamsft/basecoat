terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "basecoat-portal"
    hostname     = "app.terraform.io"

    workspaces {
      prefix = "basecoat-"
    }
  }
}

provider "aws" {
  region = var.aws_primary_region

  assume_role {
    role_arn = var.aws_role_arn
  }

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.aws_secondary_region

  assume_role {
    role_arn = var.aws_role_arn
  }

  default_tags {
    tags = local.common_tags
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    virtual_machine {
      graceful_shutdown = true
    }
  }

  skip_provider_registration = false
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_primary_region
}

provider "google" {
  alias   = "secondary"
  project = var.gcp_project_id
  region  = var.gcp_secondary_region
}
