# Terraform Lambda Deploy

## 概要

Infrastructure as Code（IaC）ツールで AWS Lambda をデプロイ

## 前提条件

- Terraform CLI
- AWS CLI
- 適切な IAM 権限

## 実務レベルのセットアップ

### 1. プロジェクト構造

```project
my-lambda-terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
├── modules/
│   ├── lambda/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── api-gateway/
│   ├── dynamodb/
│   └── monitoring/
├── lambda/
│   ├── users/
│   │   ├── src/
│   │   ├── package.json
│   │   └── tests/
│   └── orders/
├── scripts/
│   ├── deploy.sh
│   └── destroy.sh
├── .github/workflows/
└── terraform.tf
```

### 2. メインテラフォーム設定（environments/prod/main.tf）

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

# Backend設定（別ファイル backend.tf）
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "lambda/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "Terraform"
      Owner         = var.owner
      CostCenter    = var.cost_center
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Data（既存VPC使用の場合）
data "aws_vpc" "main" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnets" "private" {
  count = var.vpc_id != "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Type = "Private"
  }
}

# KMS Key for encryption
resource "aws_kms_key" "lambda" {
  description             = "KMS key for Lambda functions"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/${var.project_name}-${var.environment}-lambda"
  target_key_id = aws_kms_key.lambda.key_id
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.environment}-dlq"
  message_retention_seconds = 1209600  # 14 days
  kms_master_key_id        = aws_kms_key.lambda.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-dlq"
  }
}

# Lambda Function Module
module "user_lambda" {
  source = "../../modules/lambda"

  function_name = "${var.project_name}-${var.environment}-user"
  source_dir    = "../../lambda/users"
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_config.memory_size
  timeout       = var.lambda_config.timeout

  environment_variables = merge(
    var.common_env_vars,
    {
      USER_TABLE    = module.dynamodb.user_table_name
      ENVIRONMENT   = var.environment
      LOG_LEVEL     = var.log_level
    }
  )

  # VPC Configuration
  vpc_id             = var.vpc_id
  subnet_ids         = var.vpc_id != "" ? data.aws_subnets.private[0].ids : []
  security_group_ids = var.security_group_ids

  # DLQ Configuration
  dead_letter_target_arn = aws_sqs_queue.dlq.arn

  # Reserved Concurrency
  reserved_concurrent_executions = var.lambda_config.reserved_concurrency

  # Environment
  environment = var.environment
  kms_key_arn = aws_kms_key.lambda.arn

  depends_on = [module.dynamodb]
}

# DynamoDB Module
module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name           = "${var.project_name}-${var.environment}-users"
  billing_mode         = var.dynamodb_config.billing_mode
  read_capacity        = var.dynamodb_config.read_capacity
  write_capacity       = var.dynamodb_config.write_capacity
  point_in_time_recovery = var.dynamodb_config.point_in_time_recovery

  hash_key  = "userId"
  range_key = "createdAt"

  attributes = [
    {
      name = "userId"
      type = "S"
    },
    {
      name = "createdAt"
      type = "S"
    },
    {
      name = "email"
      type = "S"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  global_secondary_indexes = [
    {
      name            = "email-index"
      hash_key        = "email"
      projection_type = "ALL"
    },
    {
      name            = "status-index"
      hash_key        = "status"
      range_key       = "createdAt"
      projection_type = "ALL"
    }
  ]

  environment = var.environment
  kms_key_arn = aws_kms_key.lambda.arn
}

# API Gateway Module
module "api_gateway" {
  source = "../../modules/api-gateway"

  api_name        = "${var.project_name}-${var.environment}-api"
  stage_name      = var.environment
  lambda_functions = {
    user = {
      function_arn  = module.user_lambda.function_arn
      function_name = module.user_lambda.function_name
    }
  }

  # Cognito Authorizer
  cognito_user_pool_arn = var.cognito_user_pool_arn

  # CORS Configuration
  cors_configuration = {
    allow_origins = var.api_cors_origins
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key"]
  }

  environment = var.environment
}

# CloudWatch Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment

  # Terraform Lambda Deploy

## 概要
Infrastructure as Code（IaC）ツールでAWS Lambdaをデプロイ

## 前提条件
- Terraform CLI
- AWS CLI

## セットアップ

### 1. プロジェクト構造
```

my-lambda-terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── lambda/
│ └── index.js
└── terraform.tfvars

````

### 2. main.tf
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# zipファイルの作成
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda_function.zip"
}

# IAMロール
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda関数
resource "aws_lambda_function" "main" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  memory_size     = var.memory_size
  timeout         = var.timeout

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = var.environment_variables
  }
}
````

### 3. variables.tf

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "memory_size" {
  description = "Memory size for Lambda"
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Timeout for Lambda"
  type        = number
  default     = 30
}

variable "environment_variables" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}
```

### 4. outputs.tf

```hcl
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}
```

### 5. terraform.tfvars

```hcl
function_name = "my-lambda-function"
memory_size   = 256
timeout       = 30

environment_variables = {
  ENV = "production"
}
```

## デプロイ手順

### 1. 初期化

```bash
terraform init
```

### 2. プランの確認

```bash
terraform plan
```

### 3. デプロイ

```bash
terraform apply
```

## 便利なコマンド

### 状態の確認

```bash
terraform show
terraform state list
```

### 削除

```bash
terraform destroy
```

### フォーマット

```bash
terraform fmt
terraform validate
```

## メリット・デメリット

**メリット**: 多クラウド対応、状態管理、プランニング機能、宣言的  
**デメリット**: AWS 特化機能への対応が遅い、学習コストが高い
