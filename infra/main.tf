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