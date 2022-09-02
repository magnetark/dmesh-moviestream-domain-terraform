
# --------------------------------
# DMS MIGRATION (See ./dms/dms.tf)
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

# -----------------------------
# KINESIS FIREHOSE
# -----------------------------

resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "terraform-kinesis-firehose-extended-s3-test-stream"
  destination = "extended_s3"

  kinesis_source_configuration{
    kinesis_stream_arn = aws_kinesis_stream.domain_stream_cdc1.arn
    role_arn = aws_iam_role.firehoserole.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehoserole.arn
    bucket_arn = aws_s3_bucket.raw.arn

    # Example prefix using partitionKeyFromQuery, applicable to JQ processor
    # prefix              = "data/customer_id=!{partitionKeyFromQuery:customer_id}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    # error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    # https://docs.aws.amazon.com/firehose/latest/dev/dynamic-partitioning.html
    # buffer_size = 64
    # processing_configuration {
    #   enabled = "true"

    #   # Multi-record deaggregation processor example
    #   processors {
    #     type = "RecordDeAggregation"
    #     parameters {
    #       parameter_name  = "SubRecordType"
    #       parameter_value = "JSON"
    #     }
    #   }

    #   # New line delimiter processor example
    #   processors {
    #     type = "AppendDelimiterToRecord"
    #   }

    #   # JQ processor example
    #   processors {
    #     type = "MetadataExtraction"
    #     parameters {
    #       parameter_name  = "JsonParsingEngine"
    #       parameter_value = "JQ-1.6"
    #     }
    #     parameters {
    #       parameter_name  = "MetadataExtractionQuery"
    #       parameter_value = "{customer_id:.customer_id}"
    #     }
    #   }
    # }
  }
}

# -----------------------------
# STORAGE LAYER - S3
# -----------------------------

resource "aws_s3_bucket" "raw" {
  bucket = "${var.dominio}-dmesh-raw-bucket"
  force_destroy = true #@WARNING
  tags = {
    Name = "${var.dominio}-dmesh-raw-bucket"
  }
}

resource "aws_s3_bucket" "stage" {
  bucket = "${var.dominio}-dmesh-stage-bucket"
  force_destroy = true #@WARNING
  tags = {
    Name = "${var.dominio}-dmesh-raw-bucket"
  }
}

resource "aws_s3_bucket" "products" {
  bucket = "${var.dominio}-dmesh-products-bucket"
  force_destroy = true #@WARNING
  tags = {
    Name = "${var.dominio}-dmesh-raw-bucket"
  }
}

# -----------------------------
# GLUE RT
# -----------------------------

