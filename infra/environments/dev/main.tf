module "network" { #tfsec:ignore:aws-iam-no-policy-wildcards
  source = "../../modules/network"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  kms_key_arn = module.kms.key_arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


module "edge" {
  source = "../../modules/edge"

  project_name = var.project_name
  environment  = var.environment

  vpc_id   = module.network.vpc_id
  vpc_cidr = var.vpc_cidr

  public_subnet_ids = module.network.public_subnet_ids

  container_port = var.container_port

  acm_certificate_arn = var.acm_certificate_arn

  alb_logs_bucket = module.data.access_logs_bucket_name

  kms_key_arn = module.kms.key_arn
}


module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = "${var.project_name}-${var.environment}"

  # ======================================================
  # NETWORK
  # ======================================================

  vpc_id   = module.network.vpc_id
  vpc_cidr = var.vpc_cidr

  private_subnet_ids = module.network.private_subnet_ids

  # ======================================================
  # ALB / EDGE
  # ======================================================

  alb_security_group_id = module.edge.alb_security_group_id
  target_group_arn      = module.edge.target_group_arn

  # ======================================================
  # ECS
  # ======================================================

  container_image = var.container_image
  container_port  = var.container_port
  desired_count   = var.desired_count

  # ======================================================
  # KMS / REGION
  # ======================================================

  kms_key_arn = module.kms.key_arn
  aws_region  = var.aws_region

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "random_password" "database" {
  length  = 32
  special = true
}


module "security_iam" {
  source = "../../modules/security-iam"

  project_name = var.project_name
  environment  = var.environment
}


module "kms" {
  source = "../../modules/kms"

  project_name = var.project_name
  environment  = var.environment

  kms_admin_role_arns = [
    module.security_iam.kms_admin_role_arn
  ]

  kms_user_role_arns = [
    module.security_iam.kms_user_role_arn
  ]
}


module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  application_security_group_id = (
    module.compute.ecs_security_group_id
  )

  kms_key_arn = module.kms.key_arn

  db_name     = "sentinelpay"
  db_username = "sentinelpay_admin"
  db_password = random_password.database.result
}


module "secrets_rotation" {
  source = "../../modules/secrets-rotation"

  project_name = var.project_name
  environment  = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  rds_security_group_id = module.rds.security_group_id

  kms_key_arn = module.kms.key_arn

  db_host = module.rds.endpoint
  db_port = module.rds.port

  db_name     = "sentinelpay"
  db_username = "sentinelpay_admin"
  db_password = random_password.database.result

  rotation_lambda_zip = (
    "${path.root}/../../lambda/postgres-rotation.zip"
  )
}


data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


locals {
  github_deployment_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ECRAuthentication"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },

      {
        Sid    = "ECRImageManagement"
        Effect = "Allow"

        Action = [
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]

        Resource = [
          "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${var.environment}-payments-api",
          "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${var.environment}-kyc-api"
        ]
      },

      {
        Sid    = "ECSDeploy"
        Effect = "Allow"

        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]

        Resource = [
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/${var.project_name}-${var.environment}/*"
        ]
      },

      {
        Sid    = "ECSTaskDefinitionManagement"
        Effect = "Allow"

        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]

        Resource = "*"
      },

      {
        Sid    = "PassECSTaskRoles"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-payments-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-kyc-*"
        ]

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}


module "github_oidc" {
  source = "../../modules/github-oidc"

  project_name           = var.project_name
  environment            = var.environment
  github_organization    = var.github_organization
  github_repository      = var.github_repository
  deployment_policy_json = local.github_deployment_policy
}


#trivy:ignore:AVD-AWS-0089
module "data" { #tfsec:ignore:aws-s3-enable-bucket-logging
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  application_security_group_id = module.compute.ecs_security_group_id

  kms_key_arn = module.kms.key_arn
}


module "detection" {
  source = "../../modules/detection"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id = module.network.vpc_id

  kms_key_arn = module.kms.key_arn

  cloudtrail_retention_days = 365
  private_subnet_ids        = module.network.private_subnet_ids
  enable_eks_guardduty      = false
}
