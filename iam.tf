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