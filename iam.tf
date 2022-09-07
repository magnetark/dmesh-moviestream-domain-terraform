# -------------------------------------
# IAM ROLE FOR FIREHOSE TO READ KINESIS
# -------------------------------------

resource "aws_iam_role" "firehoserole" {
  name = "moviestrea-app-firehoserole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [aws_iam_policy.policy_read_kinesis.arn]

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_policy" "policy_read_kinesis" {
  name = "moviestream-kinesis-firehose-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["kinesis:*"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["lambda:*"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["s3:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# ------------------------------------
# IAM ROLE FOR DMS TO WRITE IN KINESIS
# ------------------------------------

resource "aws_iam_role" "dmsrole" {
  name = "moviestrea-app-dmsrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "dms.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [aws_iam_policy.policy_write_kinesis.arn]

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_policy" "policy_write_kinesis" {
  name = "moviestream-dms-kinesis-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["kinesis:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# -------------------------------------------------------
# IAM ROLE FOR FIREHOSE-LAMBDA TO READ & WRITE ON KINESIS
# -------------------------------------------------------

resource "aws_iam_role" "lambda_firehose_kinesis" {
  name = "moviestrea-app-lambdafirehose"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [aws_iam_policy.policy_read_write_kinesis.arn]

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_policy" "policy_read_write_kinesis" {
  name = "moviestream-lambda-kinesis-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["kinesis:*"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "autoscaling:Describe*",
          "cloudwatch:*",
          "logs:*",
          "sns:*",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# -------------------------------------------------------
# IAM ROLE FOR GLUE TO READ S3
# -------------------------------------------------------

resource "aws_iam_role" "glue_crawler" {
  name = "${var.dominio}-gluecrawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [aws_iam_policy.policy_gluecrawler.arn]

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_policy" "policy_gluecrawler" {
  name = "${var.dominio}-gluecrawler-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["glue:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}