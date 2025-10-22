# Terraform Lambda Deploy

## 概要

Infrastructure as Code（IaC）ツールでAWS Lambdaをデプロイ。

## 前提条件

- Terraform CLI
- AWS CLI

## 基本セットアップ

### main.tf

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
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
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

  tracing_config {
    mode = "Active"
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "users" {
  name           = "${var.function_name}-users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"

  attribute {
    name = "userId"
    type = "S"
  }
}

# DynamoDB権限
resource "aws_iam_policy" "dynamodb_policy" {
  name = "${var.function_name}-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      Resource = aws_dynamodb_table.users.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}
```

### variables.tf

```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "function_name" {
  type = string
}

variable "memory_size" {
  type    = number
  default = 256
}

variable "timeout" {
  type    = number
  default = 30
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}
```

### terraform.tfvars

```hcl
function_name = "my-lambda-function"
memory_size   = 256
timeout       = 30

environment_variables = {
  ENV = "production"
}
```

## デプロイ

```bash
# 初期化
terraform init

# プランの確認
terraform plan

# デプロイ
terraform apply

# 削除
terraform destroy
```

## ワークスペース管理

```bash
# 環境別ワークスペース
terraform workspace new dev
terraform workspace new prod

# ワークスペースの切り替え
terraform workspace select dev
terraform apply

terraform workspace select prod
terraform apply
```

## メリット・デメリット

**メリット**: 多クラウド対応、状態管理、プランニング機能、宣言的
**デメリット**: AWS特化機能への対応が遅い、学習コスト高
