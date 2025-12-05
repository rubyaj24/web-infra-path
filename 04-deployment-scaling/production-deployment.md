# Production Deployment Guide for SaaS Applications

![Production Architecture](../images/production-architecture.png)
*High-availability production architecture with load balancers, auto-scaling, and monitoring*

## Overview

Deploying a SaaS application to production requires careful planning, robust infrastructure, and comprehensive monitoring. This guide covers production deployment strategies, infrastructure setup, security hardening, and operational best practices.

## Production Architecture Design

### 1. High-Availability Architecture

![HA Architecture](../images/ha-architecture.png)

```yaml
# Production architecture components
Infrastructure:
  Load Balancer:
    - AWS Application Load Balancer (ALB)
    - SSL termination
    - Health checks
    - Geographic routing
  
  Application Tier:
    - Auto Scaling Groups (ASG)
    - Multiple Availability Zones
    - Container orchestration (ECS/EKS)
    - Blue-Green deployments
  
  Database Tier:
    - RDS Multi-AZ deployment
    - Read replicas
    - Automated backups
    - Point-in-time recovery
  
  Caching Layer:
    - ElastiCache Redis cluster
    - Multi-AZ replication
    - Automatic failover
  
  Content Delivery:
    - CloudFront CDN
    - S3 for static assets
    - Edge locations worldwide
```

### 2. AWS Infrastructure Setup

```yaml
# infrastructure/cloudformation/main.yml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'SaaS Application Production Infrastructure'

Parameters:
  Environment:
    Type: String
    Default: production
    AllowedValues: [staging, production]
  
  VpcCidr:
    Type: String
    Default: '10.0.0.0/16'
  
  DatabasePassword:
    Type: String
    NoEcho: true
    MinLength: 8

Resources:
  # VPC and Networking
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-vpc'

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: '10.0.1.0/24'
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-public-subnet-1'

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: '10.0.2.0/24'
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-public-subnet-2'

  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: '10.0.3.0/24'
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-private-subnet-1'

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: '10.0.4.0/24'
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-private-subnet-2'

  # Internet Gateway
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-igw'

  InternetGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref InternetGateway
      VpcId: !Ref VPC

  # Application Load Balancer
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub '${Environment}-alb'
      Scheme: internet-facing
      Type: application
      Subnets:
        - !Ref PublicSubnet1
        - !Ref PublicSubnet2
      SecurityGroups:
        - !Ref ALBSecurityGroup

  # RDS Database
  DatabaseSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: Subnet group for RDS database
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-db-subnet-group'

  Database:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: !Sub '${Environment}-postgres'
      DBInstanceClass: db.r6g.large
      Engine: postgres
      EngineVersion: '15.3'
      AllocatedStorage: 100
      StorageType: gp3
      StorageEncrypted: true
      MultiAZ: true
      DBName: saasapp
      MasterUsername: postgres
      MasterUserPassword: !Ref DatabasePassword
      VPCSecurityGroups:
        - !Ref DatabaseSecurityGroup
      DBSubnetGroupName: !Ref DatabaseSubnetGroup
      BackupRetentionPeriod: 30
      PreferredBackupWindow: '03:00-04:00'
      PreferredMaintenanceWindow: 'sun:04:00-sun:05:00'
      DeletionProtection: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-database'

  # ElastiCache Redis
  RedisSubnetGroup:
    Type: AWS::ElastiCache::SubnetGroup
    Properties:
      Description: Subnet group for Redis cluster
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2

  RedisCluster:
    Type: AWS::ElastiCache::ReplicationGroup
    Properties:
      ReplicationGroupId: !Sub '${Environment}-redis'
      Description: Redis cluster for caching
      NodeType: cache.r6g.large
      Port: 6379
      NumCacheClusters: 2
      Engine: redis
      EngineVersion: '7.0'
      CacheSubnetGroupName: !Ref RedisSubnetGroup
      SecurityGroupIds:
        - !Ref RedisSecurityGroup
      AtRestEncryptionEnabled: true
      TransitEncryptionEnabled: true
      MultiAZEnabled: true
      AutomaticFailoverEnabled: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-redis'
```

### 3. Terraform Infrastructure Alternative

```hcl
# infrastructure/terraform/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "my-saas-terraform-state"
    key    = "production/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr
  
  azs             = data.aws_availability_zones.available.names
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true
  
  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
  
  enable_deletion_protection = var.environment == "production"
  
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Service
resource "aws_ecs_service" "backend" {
  name            = "${var.environment}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
  }
  
  network_configuration {
    security_groups  = [aws_security_group.backend.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 3000
  }
  
  depends_on = [aws_lb_listener.main]
}

# RDS Database
resource "aws_db_instance" "main" {
  identifier = "${var.environment}-postgres"
  
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  multi_az                = var.environment == "production"
  deletion_protection     = var.environment == "production"
  skip_final_snapshot     = var.environment != "production"
  final_snapshot_identifier = "${var.environment}-final-snapshot"
  
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn
  
  tags = {
    Name = "${var.environment}-database"
  }
}
```

## Container Orchestration with ECS/EKS

### 1. ECS Task Definition

```json
{
  "family": "saas-backend-production",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "your-registry.com/saas-backend:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:prod/database-url"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:prod/jwt-secret"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/saas-backend-production",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:3000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "essential": true
    }
  ]
}
```

### 2. Kubernetes Deployment (EKS)

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: saas-production
  labels:
    environment: production

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: saas-production
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  PORT: "3000"

---
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: saas-production
type: Opaque
data:
  DATABASE_URL: <base64-encoded-database-url>
  JWT_SECRET: <base64-encoded-jwt-secret>
  REDIS_URL: <base64-encoded-redis-url>

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: saas-production
  labels:
    app: backend
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: backend-service-account
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: backend
        image: your-registry.com/saas-backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          protocol: TCP
        envFrom:
        - configMapRef:
            name: backend-config
        - secretRef:
            name: backend-secrets
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL

---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: saas-production
  labels:
    app: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP

---
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: saas-production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

## CI/CD Pipeline Implementation

### 1. GitHub Actions Production Deployment

```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:

env:
  AWS_REGION: us-west-2
  ECS_CLUSTER: production-cluster
  ECS_SERVICE: production-backend
  CONTAINER_NAME: backend
  ECR_REPOSITORY: saas-backend

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
        env:
          NODE_ENV: test
      
      - name: Run security audit
        run: npm audit --audit-level high
      
      - name: Run linting
        run: npm run lint

  security-scan:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  build-and-deploy:
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Extract version
        id: version
        run: |
          if [[ $GITHUB_REF == refs/tags/v* ]]; then
            echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
          else
            echo "VERSION=${GITHUB_SHA:0:7}" >> $GITHUB_OUTPUT
          fi
      
      - name: Build and tag Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ steps.version.outputs.VERSION }}
        run: |
          docker build \
            --build-arg BUILD_VERSION=$IMAGE_TAG \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
      
      - name: Scan Docker image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: '${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ steps.version.outputs.VERSION }}'
          format: 'table'
          exit-code: '1'
          ignore-unfixed: true
          severity: 'CRITICAL,HIGH'
      
      - name: Push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ steps.version.outputs.VERSION }}
        run: |
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Download task definition
        run: |
          aws ecs describe-task-definition \
            --task-definition ${{ env.ECS_SERVICE }} \
            --query taskDefinition > task-definition.json
      
      - name: Update ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ steps.version.outputs.VERSION }}
      
      - name: Deploy to Amazon ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
          wait-for-minutes: 10
      
      - name: Verify deployment
        run: |
          # Wait for deployment to stabilize
          sleep 60
          
          # Health check
          ENDPOINT="${{ secrets.PRODUCTION_ENDPOINT }}/health"
          if curl -f "$ENDPOINT"; then
            echo "Deployment verification successful"
          else
            echo "Deployment verification failed"
            exit 1
          fi
      
      - name: Notify deployment success
        if: success()
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: "🚀 Production deployment successful! Version: ${{ steps.version.outputs.VERSION }}"
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
      
      - name: Notify deployment failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: "❌ Production deployment failed! Please check the logs."
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### 2. Blue-Green Deployment Strategy

```bash
#!/bin/bash
# scripts/blue-green-deploy.sh

set -e

# Configuration
CLUSTER_NAME="production-cluster"
SERVICE_NAME="saas-backend"
NEW_IMAGE="$1"
HEALTH_CHECK_URL="$2"

if [ -z "$NEW_IMAGE" ] || [ -z "$HEALTH_CHECK_URL" ]; then
    echo "Usage: $0 <new-image> <health-check-url>"
    exit 1
fi

echo "Starting blue-green deployment..."
echo "New image: $NEW_IMAGE"
echo "Health check URL: $HEALTH_CHECK_URL"

# Get current task definition
CURRENT_TASK_DEF=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --query 'services[0].taskDefinition' \
    --output text)

echo "Current task definition: $CURRENT_TASK_DEF"

# Create new task definition with new image
NEW_TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition $CURRENT_TASK_DEF \
    --query 'taskDefinition' \
    --output json | \
    jq --arg IMAGE "$NEW_IMAGE" \
    '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')

# Register new task definition
NEW_TASK_DEF_ARN=$(echo $NEW_TASK_DEF | aws ecs register-task-definition --cli-input-json file:///dev/stdin --query 'taskDefinition.taskDefinitionArn' --output text)

echo "New task definition registered: $NEW_TASK_DEF_ARN"

# Create green service
GREEN_SERVICE="${SERVICE_NAME}-green"
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $GREEN_SERVICE \
    --task-definition $NEW_TASK_DEF_ARN \
    --desired-count 2 \
    --load-balancers "$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].loadBalancers')" \
    --network-configuration "$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].networkConfiguration')"

echo "Green service created: $GREEN_SERVICE"

# Wait for green service to be stable
echo "Waiting for green service to stabilize..."
aws ecs wait services-stable --cluster $CLUSTER_NAME --services $GREEN_SERVICE

# Health check green service
echo "Performing health check on green service..."
for i in {1..30}; do
    if curl -f "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo "Health check passed"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "Health check failed after 30 attempts"
        echo "Rolling back..."
        aws ecs delete-service --cluster $CLUSTER_NAME --service $GREEN_SERVICE --force
        exit 1
    fi
    
    echo "Health check attempt $i failed, retrying in 10 seconds..."
    sleep 10
done

# Switch traffic to green service
echo "Switching traffic to green service..."

# Update load balancer target group
TARGET_GROUP_ARN=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --query 'services[0].loadBalancers[0].targetGroupArn' \
    --output text)

# Get green service task IPs
GREEN_TASK_ARNS=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $GREEN_SERVICE \
    --query 'taskArns[]' \
    --output text)

# Register green tasks with load balancer
for TASK_ARN in $GREEN_TASK_ARNS; do
    TASK_IP=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARN \
        --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
        --output text)
    
    aws elbv2 register-targets \
        --target-group-arn $TARGET_GROUP_ARN \
        --targets Id=$TASK_IP,Port=3000
done

# Wait for targets to be healthy
echo "Waiting for targets to be healthy..."
sleep 30

# Deregister blue service from load balancer
echo "Deregistering blue service from load balancer..."
BLUE_TASK_ARNS=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --query 'taskArns[]' \
    --output text)

for TASK_ARN in $BLUE_TASK_ARNS; do
    TASK_IP=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARN \
        --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
        --output text)
    
    aws elbv2 deregister-targets \
        --target-group-arn $TARGET_GROUP_ARN \
        --targets Id=$TASK_IP,Port=3000
done

# Delete blue service
echo "Deleting blue service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count 0

aws ecs delete-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME

# Rename green service to blue
echo "Renaming green service to production service..."
# Note: ECS doesn't support renaming services, so we update the original service
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $GREEN_SERVICE \
    --task-definition $NEW_TASK_DEF_ARN

echo "Blue-green deployment completed successfully!"
```

## Database Migration and Management

### 1. Database Migration Script

```javascript
// scripts/migrate-production.js
const { PrismaClient } = require('@prisma/client');
const { execSync } = require('child_process');

const prisma = new PrismaClient();

async function runMigration() {
    try {
        console.log('Starting database migration...');
        
        // Check database connectivity
        await prisma.$queryRaw`SELECT 1`;
        console.log('Database connection established');
        
        // Create backup before migration
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupFile = `backup-${timestamp}.sql`;
        
        console.log(`Creating backup: ${backupFile}`);
        execSync(`pg_dump ${process.env.DATABASE_URL} > ./backups/${backupFile}`);
        
        // Run migrations
        console.log('Running Prisma migrations...');
        execSync('npx prisma migrate deploy', { stdio: 'inherit' });
        
        // Verify migration
        console.log('Verifying migration...');
        const result = await prisma.$queryRaw`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `;
        
        console.log(`Migration completed successfully. Tables: ${result.length}`);
        
        // Update migration status
        await prisma.migrationStatus.create({
            data: {
                version: process.env.BUILD_VERSION || 'unknown',
                status: 'completed',
                backupFile: backupFile,
                completedAt: new Date()
            }
        });
        
    } catch (error) {
        console.error('Migration failed:', error);
        
        // Log failure
        await prisma.migrationStatus.create({
            data: {
                version: process.env.BUILD_VERSION || 'unknown',
                status: 'failed',
                error: error.message,
                completedAt: new Date()
            }
        }).catch(console.error);
        
        process.exit(1);
    } finally {
        await prisma.$disconnect();
    }
}

runMigration();
```

### 2. Backup and Recovery Scripts

```bash
#!/bin/bash
# scripts/backup-database.sh

set -e

# Configuration
BACKUP_DIR="/backups/postgresql"
RETENTION_DAYS=30
S3_BUCKET="my-saas-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Parse database URL
DB_URL=${DATABASE_URL}
DB_HOST=$(echo $DB_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_NAME=$(echo $DB_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
DB_USER=$(echo $DB_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')

# Create backup directory
mkdir -p $BACKUP_DIR

# Create backup
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"

echo "Creating database backup: $BACKUP_FILE"

PGPASSWORD=$DB_PASSWORD pg_dump \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    --verbose \
    --clean \
    --create \
    --format=custom \
    | gzip > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Backup completed successfully"
    
    # Upload to S3
    echo "Uploading to S3..."
    aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/postgresql/
    
    # Clean up old local backups
    find $BACKUP_DIR -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
    
    # Clean up old S3 backups
    aws s3 ls s3://$S3_BUCKET/postgresql/ | while read -r line; do
        backup_date=$(echo $line | awk '{print $1}')
        backup_file=$(echo $line | awk '{print $4}')
        
        # Calculate days difference
        if [ "$backup_date" ]; then
            days_diff=$(( ($(date +%s) - $(date -d "$backup_date" +%s)) / 86400 ))
            
            if [ $days_diff -gt $RETENTION_DAYS ]; then
                echo "Deleting old backup: $backup_file"
                aws s3 rm s3://$S3_BUCKET/postgresql/$backup_file
            fi
        fi
    done
    
    echo "Backup process completed"
else
    echo "Backup failed!"
    exit 1
fi
```

## ![Prometheus](../images/logos/prometheus.svg) Monitoring and Observability

### 1. ![Prometheus](../images/logos/prometheus.svg) Prometheus Configuration

```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'saas-backend'
    static_configs:
      - targets: ['backend:3000']
    metrics_path: '/metrics'
    scrape_interval: 10s
    
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
    
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
    
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: us-west-2
        port: 9100
        filters:
          - name: tag:Monitoring
            values: [enabled]
```

### 2. Alert Rules

```yaml
# monitoring/rules/saas-alerts.yml
groups:
  - name: saas-application
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }}s"

      - alert: DatabaseConnectionFailure
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failure"
          description: "PostgreSQL database is not reachable"

      - alert: RedisConnectionFailure
        expr: up{job="redis"} == 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Redis connection failure"
          description: "Redis cache is not reachable"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }}"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is {{ $value }}%"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk space is {{ $value }}% available"
```

## Security Hardening

### 1. Security Best Practices Checklist

```yaml
# Security hardening checklist
Network_Security:
  - ✅ VPC with private subnets for application and database
  - ✅ Security groups with minimal required access
  - ✅ NAT Gateway for outbound internet access
  - ✅ VPC Flow Logs enabled
  - ✅ AWS Shield Advanced for DDoS protection

Application_Security:
  - ✅ Container images scanned for vulnerabilities
  - ✅ Non-root user in containers
  - ✅ Read-only root filesystem
  - ✅ Resource limits and requests defined
  - ✅ Secrets management with AWS Secrets Manager

Database_Security:
  - ✅ Database in private subnet
  - ✅ Encryption at rest enabled
  - ✅ Encryption in transit enabled
  - ✅ Regular security updates
  - ✅ Database activity monitoring

Access_Control:
  - ✅ IAM roles with least privilege
  - ✅ Multi-factor authentication required
  - ✅ API authentication and authorization
  - ✅ Service-to-service authentication
  - ✅ Audit logging enabled

Monitoring:
  - ✅ CloudTrail for API logging
  - ✅ GuardDuty for threat detection
  - ✅ Security Hub for compliance monitoring
  - ✅ Config for configuration monitoring
  - ✅ Inspector for vulnerability assessments
```

### 2. WAF Configuration

```yaml
# WAF rules for application protection
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  WebACL:
    Type: AWS::WAFv2::WebACL
    Properties:
      Name: SaaS-Production-WebACL
      Scope: REGIONAL
      DefaultAction:
        Allow: {}
      Rules:
        - Name: AWSManagedRulesCommonRuleSet
          Priority: 1
          OverrideAction:
            None: {}
          Statement:
            ManagedRuleGroupStatement:
              VendorName: AWS
              Name: AWSManagedRulesCommonRuleSet
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: CommonRuleSetMetric

        - Name: AWSManagedRulesKnownBadInputsRuleSet
          Priority: 2
          OverrideAction:
            None: {}
          Statement:
            ManagedRuleGroupStatement:
              VendorName: AWS
              Name: AWSManagedRulesKnownBadInputsRuleSet
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: KnownBadInputsMetric

        - Name: RateLimitRule
          Priority: 3
          Action:
            Block: {}
          Statement:
            RateBasedStatement:
              Limit: 2000
              AggregateKeyType: IP
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: RateLimitMetric

      VisibilityConfig:
        SampledRequestsEnabled: true
        CloudWatchMetricsEnabled: true
        MetricName: SaaSWebACL

  WebACLAssociation:
    Type: AWS::WAFv2::WebACLAssociation
    Properties:
      ResourceArn: !Ref ApplicationLoadBalancer
      WebACLArn: !GetAtt WebACL.Arn
```

## Sources and References

### Official Documentation
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/) - AWS architecture best practices
- [ECS Best Practices Guide](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/) - Container orchestration best practices
- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/) - Production-ready Kubernetes
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) - Infrastructure as code

### Security Resources
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) - Web application security risks
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/) - Cloud security guidelines
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/) - Security configuration guidelines

### Books
- "Building Secure and Reliable Systems" by Google SRE Team
- "Site Reliability Engineering" by Google SRE Team
- "The DevOps Handbook" by Gene Kim, Jez Humble, Patrick Debois, John Willis

### Tools and Resources
- [AWS CLI](https://aws.amazon.com/cli/) - Command line interface for AWS
- [Terraform](https://www.terraform.io/) - Infrastructure as code
- [Prometheus](https://prometheus.io/) - Monitoring and alerting
- [Grafana](https://grafana.com/) - Visualization and dashboards

---

**Congratulations!** You've completed the comprehensive SaaS infrastructure learning path! 🎉