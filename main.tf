
# --------------------------------
# DMS MIGRATION (See ./dms.tf)
# --------------------------------

# -------------------------
# DOMAIN VPC
# -------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name            = "vpc_moviestream_domain"
  cidr            = "10.1.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true
  create_igw = true

  tags = merge(var.tags, { Name = "vpc_moviestream_domain" })
}

resource "aws_security_group" "dms_sg" {
  name        = "allow_migration"
  description = "allow_migration"
  vpc_id      = module.vpc.vpc_id

   # @WARINNG
  ingress {
    description      = "Allow all"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "allow_notebook" })
}

# -----------------------------
# KINESIS
# -----------------------------

resource "aws_kinesis_stream" "domain_stream_cdc1" {
  name             = "${var.dominio}-kinesis-stream-cdc1"
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Environment = "test"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.kinesis-streams"
  vpc_endpoint_type = "Interface"

  subnet_ids = module.vpc.public_subnets 

  security_group_ids = [
    aws_security_group.dms_sg.id,
  ]

  private_dns_enabled = true
}

# -----------------------------
# KINESIS FIREHOSE
# -----------------------------

resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "${var.dominio}-kinesis-firehose-extended-s3"
  destination = "extended_s3"

  kinesis_source_configuration{
    kinesis_stream_arn = aws_kinesis_stream.domain_stream_cdc1.arn
    role_arn = aws_iam_role.firehoserole.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehoserole.arn
    bucket_arn = aws_s3_bucket.raw.arn
    buffer_size = 64 # 5 64
    buffer_interval = 60

    dynamic_partitioning_configuration {
      enabled = true 
    }

    prefix              = "db/schema=!{partitionKeyFromLambda:schema}/table=!{partitionKeyFromLambda:table}/year=!{partitionKeyFromLambda:year}/month=!{partitionKeyFromLambda:month}/date=!{partitionKeyFromLambda:date}/hour=!{partitionKeyFromLambda:hour}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"
        
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.lambda_firehose_processor.arn}:$LATEST"
        }
      }
    }

    ## https://docs.aws.amazon.com/firehose/latest/dev/dynamic-partitioning.html
    ## Example prefix using partitionKeyFromQuery, applicable to JQ processor
    ## prefix              = "data/movieId=!{partitionKeyFromQuery:movieId}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    ## error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    ## processing_configuration {
    ##   enabled = "true"

    ##   # Multi-record deaggregation processor example
    ##   processors {
    ##     type = "RecordDeAggregation"
    ##     parameters {
    ##       parameter_name  = "SubRecordType"
    ##       parameter_value = "JSON"
    ##     }
    ##   }

    ##   New line delimiter processor example
    ##   processors {
    ##     type = "AppendDelimiterToRecord"
    ##   }

    ##   JQ processor example
    ##   processors {
    ##     type = "MetadataExtraction"
    ##     parameters {
    ##       parameter_name  = "JsonParsingEngine"
    ##       parameter_value = "JQ-1.6"
    ##     }
    ##     parameters {
    ##       parameter_name  = "MetadataExtractionQuery"
    ##       parameter_value = "{movieId:.movieId}"
    ##     }
    ##   }
    ## }
  }
}

resource "aws_lambda_function" "lambda_firehose_processor" {
  filename      = "lambda-firehose/code.zip" #
  function_name = "firehose_lambda_processor"
  role          = aws_iam_role.lambda_firehose_kinesis.arn
  handler       = "lambda_function.lambda_handler" # 
  runtime       = "python3.8"
  timeout       = 60
}

# -----------------------------
# STORAGE LAYER - S3
# -----------------------------

resource "aws_s3_bucket" "raw" {
  bucket = "${var.dominio}-dmesh-raw-bucket"
  force_destroy = true # @WARNING: This configuration could be hazardous to your deploymen in a production environment.
  tags = {
    Name = "${var.dominio}-dmesh-raw"
  }
}

resource "aws_s3_bucket" "stage" {
  bucket = "${var.dominio}-dmesh-stage-bucket"
  force_destroy = true # @WARNING: This configuration could be hazardous to your deploymen in a production environment.
  tags = {
    Name = "${var.dominio}-dmesh-stage"
  }
}

resource "aws_s3_bucket" "products" {
  bucket = "${var.dominio}-dmesh-products-bucket"
  force_destroy = true # @WARNING: This configuration could be hazardous to your deploymen in a production environment.
  tags = {
    Name = "${var.dominio}-dmesh-raw"
  }
}

resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.dominio}-athena-query-results"
  force_destroy = true # @WARNING: This configuration could be hazardous to your deploymen in a production environment.
  tags = {
    Name = "${var.dominio}-athena-query-results"
  }
}

# -----------------------------
# GLUE CRAWLER
# -----------------------------

# resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
#   name = "${var.dominio}-catalog-database"
# }

resource "aws_glue_crawler" "crawler_raw" {
  database_name = aws_athena_database.dmesh_athana_db.name
  name          = "${var.dominio}-raw-data"
  role          = aws_iam_role.glue_crawler.arn

  configuration = jsonencode(
    {
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas",
        TableLevelConfiguration = 4
      }
      CrawlerOutput = {
        Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      }
      Version = 1
    }
  )

  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}"
  }

  tags = var.tags
}

resource "aws_glue_crawler" "crawler_stage" {
  database_name = aws_athena_database.dmesh_athana_db.name
  name          = "${var.dominio}-stage-data"
  role          = aws_iam_role.glue_crawler.arn

  configuration = jsonencode(
    {
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas"
      }
      CrawlerOutput = {
        Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      }
      Version = 1
    }
  )

  s3_target {
    path = "s3://${aws_s3_bucket.stage.bucket}"
  }

  tags = var.tags
}

resource "aws_glue_crawler" "crawler_products" {
  database_name = aws_athena_database.dmesh_athana_db.name
  name          = "${var.dominio}-products-data"
  role          = aws_iam_role.glue_crawler.arn

  configuration = jsonencode(
    {
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas"
      }
      CrawlerOutput = {
        Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      }
      Version = 1
    }
  )

  s3_target {
    path = "s3://${aws_s3_bucket.products.bucket}"
  }

  tags = var.tags
}

# -----------------------------
# GLUE RT
# -----------------------------



# -----------------------------
# ATHENA
# -----------------------------

resource "aws_athena_database" "dmesh_athana_db" {
  name   = "${var.dominio}_database"
  bucket = aws_s3_bucket.athena_results.bucket
  force_destroy = true # @WARNING: This configuration could be hazardous to your deploymen in a production environment.
}