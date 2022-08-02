provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
variable "region" {
  default = "eu-central-1"
  type = string
}
variable "access_key" {
  description = "Access key for AWS"
  type = string
}
variable "secret_key" {
  description = "Secret key for AWS"
  type = string
}

resource "aws_lambda_function" "create-product" {
  filename      = "create-product.zip"
  function_name = "create-product"
  role          = aws_iam_role.create-product-iam.arn
  handler       = "index.handler"

  source_code_hash = filebase64sha256("create-product.zip")

  runtime = "nodejs16.x"

  depends_on = [
    aws_iam_role_policy_attachment.create-products-logs-policy-attachment,
  ]
}

resource "aws_iam_policy" "create-product-iam-policy" {
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          Resource = "arn:aws:logs:*:*:*",
          Effect   = "Allow"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "create-products-logs-policy-attachment" {
  role       = aws_iam_role.create-product-iam.name
  policy_arn = aws_iam_policy.create-product-iam-policy.arn
}




resource "aws_cloudwatch_event_rule" "always-warm-event-rule" {
  name        = "always-warm-event-rule"
  description = "Call a lambda every minute to keep warm"

  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "always-warm-event-target" {
  rule = aws_cloudwatch_event_rule.always-warm-event-rule.name
  arn  = aws_lambda_function.create-product.arn
}

resource "aws_lambda_permission" "create-product-permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create-product.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.always-warm-event-rule.arn
}


resource "aws_iam_role" "create-product-iam" {
  name = "create-product-iam"

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
      }
    ]
  })
}

