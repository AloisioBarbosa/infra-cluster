locals {
  karpenter_interruption_events = {
    health = {
      source      = ["aws.health"]
      detail-type = ["AWS Health Event"]
    }
    spot = {
      source      = ["aws.ec2"]
      detail-type = ["EC2 Spot Instance Interruption Warning"]
    }
    rebalance = {
      source      = ["aws.ec2"]
      detail-type = ["EC2 Instance Rebalance Recommendation"]
    }
    state_change = {
      source      = ["aws.ec2"]
      detail-type = ["EC2 Instance State-change Notification"]
    }
    capacity_reservation = {
      source      = ["aws.ec2"]
      detail-type = ["EC2 Capacity Reservation Instance Interruption Warning"]
    }
  }
}

resource "aws_sqs_queue" "karpenter_interruptions" {
  name                      = "${var.project_name}-karpenter-interruptions"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_cloudwatch_event_rule" "karpenter_interruptions" {
  for_each = local.karpenter_interruption_events

  name          = "${var.project_name}-karpenter-${replace(each.key, "_", "-")}"
  event_pattern = jsonencode(each.value)
}

data "aws_iam_policy_document" "karpenter_interruption_queue" {
  statement {
    sid     = "AllowEventBridge"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.karpenter_interruptions.arn,
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = values(aws_cloudwatch_event_rule.karpenter_interruptions)[*].arn
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.karpenter_interruptions.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruptions" {
  queue_url = aws_sqs_queue.karpenter_interruptions.id
  policy    = data.aws_iam_policy_document.karpenter_interruption_queue.json
}

resource "aws_cloudwatch_event_target" "karpenter_interruptions" {
  for_each = aws_cloudwatch_event_rule.karpenter_interruptions

  rule = each.value.name
  arn  = aws_sqs_queue.karpenter_interruptions.arn

  depends_on = [
    aws_sqs_queue_policy.karpenter_interruptions,
  ]
}
