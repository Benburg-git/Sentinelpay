# =========================================================
# AWS
# =========================================================

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "eu-west-1"
}


# =========================================================
# PROJECT
# =========================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "sentinelpay"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}


# =========================================================
# NETWORK
# =========================================================

variable "vpc_cidr" {
  description = "CIDR block of the VPC used to restrict ECS outbound traffic"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
}


# =========================================================
# GITHUB OIDC
# =========================================================

variable "github_organization" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the AWS role"
  type        = string
  default     = "main"
}


# =========================================================
# ALB / TLS
# =========================================================

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by the ALB HTTPS listener"
  type        = string
  default     = null
}


# =========================================================
# ECS / COMPUTE
# =========================================================

variable "container_image" {
  description = "Docker image used by the ECS task"
  type        = string
  default     = "nginx:alpine"
}

variable "container_port" {
  description = "Port exposed by the ECS container"
  type        = number
  default     = 80
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "name_prefix" {
  description = "Prefix used for naming compute resources"
  type        = string
  default     = null
}


# =========================================================
# COMMON TAGS
# =========================================================

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}
# =========================================================
# PAYMENTS API
# =========================================================

variable "payments_container_image" {
  description = "Docker image for the Payments API"
  type        = string
}

variable "payments_container_port" {
  description = "Container port for the Payments API"
  type        = number
  default     = 8001
}

variable "payments_desired_count" {
  description = "Desired number of Payments API ECS tasks"
  type        = number
  default     = 1

  validation {
    condition     = var.payments_desired_count >= 0
    error_message = "Payments desired count cannot be negative."
  }
}

# =========================================================
# KYC API
# =========================================================

variable "kyc_container_image" {
  description = "Docker image for the KYC API"
  type        = string
}

variable "kyc_container_port" {
  description = "Container port for the KYC API"
  type        = number
  default     = 8002
}

variable "kyc_desired_count" {
  description = "Desired number of KYC API ECS tasks"
  type        = number
  default     = 1

  validation {
    condition     = var.kyc_desired_count >= 0
    error_message = "KYC desired count cannot be negative."
  }
}