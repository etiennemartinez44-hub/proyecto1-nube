#!/bin/bash
# Despliegue del servidor web de Librería Tinta
set -euo pipefail
export AWS_PAGER=""

REGION="us-east-1"
SUBNET_ID="subnet-0ae7ba236083d9532"
VPC_ID="vpc-0abdb17f107c74ce6"
MI_IP="84.120.29.102/32"
ALUMNO="Etienne Martinez"

# 1. Buscar la AMI de Amazon Linux 2023
AMI_ID=$(aws ssm get-parameters --region "$REGION" \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameters[0].Value" --output text)

# 2. Crear el grupo de seguridad
SG_ID=$(aws ec2 create-security-group --region "$REGION" \
  --group-name libreria-web-cli-sg \
  --description "Web Libreria Tinta (CLI)" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" --output text)

# Permitir visitas a la web
aws ec2 authorize-security-group-ingress --region "$REGION" \
  --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0

# Permitir SSH solo desde mi IP
aws ec2 authorize-security-group-ingress --region "$REGION" \
  --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MI_IP"

# 3. Crear la instancia con el script de la web
INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name vockey \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --user-data file://user-data1.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=libreria-web-cli},{Key=Proyecto,Value=P1},{Key=Alumno,Value=$ALUMNO}]" \
  --query "Instances[0].InstanceId" --output text)

echo "Instancia creada: $INSTANCE_ID"

# 4. Esperar al arranque y obtener la IP pública
aws ec2 wait instance-running --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

IP=$(aws ec2 describe-instances --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Abre en el navegador: http://$IP"
echo "La instalación de Nginx puede necesitar uno o dos minutos más."