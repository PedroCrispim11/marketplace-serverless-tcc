import json
import boto3
import os
import uuid

# Inicializa os clientes da AWS (o Boto3 já vem instalado nativamente nas Lambdas)
dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    try:
        # 1. Captura os dados enviados pelo frontend (API)
        body = json.loads(event.get('body', '{}'))
        
        # Gera um ID único para este novo pedido de cotação
        pedido_id = str(uuid.uuid4())
        
        # Puxa os nomes dos recursos gerados pelo Terraform
        tabela_nome = os.environ['DYNAMODB_TABLE']
        fila_url = os.environ['SQS_QUEUE_URL']
        
        # 2. Salva o pedido no banco de dados (DynamoDB)
        table = dynamodb.Table(tabela_nome)
        table.put_item(
            Item={
                'id': pedido_id,
                'produto': body.get('produto', 'Não informado'),
                'quantidade': body.get('quantidade', 1),
                'status': 'PENDENTE_DE_COTACAO'
                
            }
        )
        
        # 3. Dispara a notificação para a mensageria (SQS)
        mensagem_sqs = {
            'pedido_id': pedido_id,
            'acao': 'PROCESSAR_NOVA_COTACAO'
        }
        sqs.send_message(
            QueueUrl=fila_url,
            MessageBody=json.dumps(mensagem_sqs)
        )
        
        # 4. Retorna sucesso para o frontend
        return {
            'statusCode': 201,
            'body': json.dumps({
                'message': 'Pedido registrado com sucesso na AAA IFTM!', 
                'pedido_id': pedido_id
            })
        }
        
    except Exception as e:
        # Retorna erro caso algo falhe
        print(f"Erro interno: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Erro ao processar a solicitação.'})
        }