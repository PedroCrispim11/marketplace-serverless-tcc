terraform {

  cloud {
    organization = "pedro-crispim"

    workspaces {
      name = "marketplace-serverless-prod"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Projeto    = "Marketplace-B2B-TCC"
      Ambiente   = "MVP"
      Gerenciado = "Terraform"
    }
  }
}

# ==========================================
# BANCO DE DADOS (Amazon DynamoDB)
# ==========================================
# Tabela única (Single-Table Design) para armazenar 
# tanto as cotações abertas quanto as respostas da IA.

resource "aws_dynamodb_table" "marketplace_db" {
  name         = "Marketplace-Core-Table"
  billing_mode = "PAY_PER_REQUEST" # Fundamental: Garante custo zero sob demanda
  hash_key     = "PK"              # Chave de Partição
  range_key    = "SK"              # Chave de Ordenação

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  tags = {
    Name  = "Tabela-Core-Marketplace"
    Teste = "AprovacaoCICD"
  }
}

# ==========================================
# MENSAGERIA (Amazon SQS)
# ==========================================
# Fila para absorver os pedidos do painel web e 
# evitar perda de dados antes do disparo no WhatsApp.

resource "aws_sqs_queue" "order_queue" {
  name                      = "marketplace-order-queue"
  delay_seconds             = 0
  max_message_size          = 262144 # 256 KB (Tamanho padrão)
  message_retention_seconds = 345600 # Retém a mensagem por até 4 dias caso dê erro
  receive_wait_time_seconds = 0

  tags = {
    Name = "Fila-Pedidos-Marketplace"
  }
}

# 1. Empacota o código Python automaticamente
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/lambda_ingestao.py"
  output_path = "${path.module}/lambda_ingestao.zip"
}

# 2. Cria o "Crachá" de permissão para a Lambda (IAM Role)
resource "aws_iam_role" "lambda_exec_role" {
  name = "role_lambda_cotacoes"

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

# 3. Define exatamente o que o crachá pode acessar (DynamoDB e SQS)
resource "aws_iam_policy" "lambda_policy" {
  name        = "policy_lambda_cotacoes"
  description = "Permite a Lambda acessar o DynamoDB e SQS do TCC"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem"]
        
        Resource = aws_dynamodb_table.Marketplace-Core-Table.arn 
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        
        Resource = aws_sqs_queue.marketplace-order-queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 4. Amarra o crachá na permissão
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# 5. Cria a Lambda em si e injeta as Variáveis de Ambiente
resource "aws_lambda_function" "ingestao_api" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  function_name    = "IngestaoCotacoesAAA"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_ingestao.lambda_handler"
  runtime          = "python3.10" # Versão moderna e estável

  environment {
    variables = {
      # O Terraform vai descobrir o nome da tabela e fila e injetar aqui
      DYNAMODB_TABLE = aws_dynamodb_table.Marketplace-Core-Table.name
      SQS_QUEUE_URL  = aws_sqs_queue.marketplace-order-queue.url
    }
  }
}