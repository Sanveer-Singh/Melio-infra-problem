# Architecture

## Overview

<!-- Brief description of the 3-service Clojure MVP deployed to AWS af-south-1 -->

## Architecture Diagram

<!-- Embed or reference the mermaid diagram from the assessment plan -->

```mermaid
graph TB
    Internet["Internet"]
    subgraph aws ["AWS af-south-1 Cape Town"]
        subgraph vpc ["VPC 10.0.0.0/16"]
            subgraph pubSubnetA ["Public Subnet AZ-a 10.0.1.0/24"]
                FE["Frontend EC2 t3.small"]
                QT["Quotes EC2 t3.small"]
                NF["Newsfeed EC2 t3.small"]
            end
            subgraph pubSubnetB ["Public Subnet AZ-b 10.0.2.0/24"]
                ALBSpan["ALB AZ-b presence"]
            end
        end
        ALB["ALB :80"]
        S3["S3 Artifact Bucket"]
        SSM["SSM Parameter Store"]
    end
    Internet -->|"HTTP :80"| ALB
    ALB -->|"Target Group :80"| FE
    FE -->|":8082"| QT
    FE -->|":8083"| NF
```

## Services

### Frontend
<!-- nginx reverse proxy on port 80, proxies to frontend.jar:8080, serves static CSS -->

### Quotes
<!-- Serves random quotes from quotes.json on port 8082 -->

### Newsfeed
<!-- Aggregates RSS feeds, serves on port 8083, requires auth token -->

## Networking

<!-- VPC, subnets, IGW, route tables, security groups -->

## Security Model

<!-- Security groups, IAM roles, SSM for secrets, no SSH by default -->

## Data Flow

<!-- Internet -> ALB -> nginx -> frontend.jar -> quotes/newsfeed backends -->
<!-- EC2 user data pulls JARs from S3 at boot -->
<!-- Frontend reads NEWSFEED_SERVICE_TOKEN from SSM at boot -->
