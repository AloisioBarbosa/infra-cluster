locals {
  karpenter_oidc_issuer = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

data "aws_iam_policy_document" "karpenter_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.karpenter_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.karpenter_oidc_issuer}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "KarpenterControllerRole-${var.project_name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_trust.json
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "AllowScopedEC2InstanceAccessActions"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}::image/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}::snapshot/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:capacity-reservation/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:placement-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:security-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:subnet/*",
    ]
  }

  statement {
    sid    = "AllowScopedEC2LaunchTemplateAccessActions"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.project_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid    = "AllowScopedEC2InstanceActionsWithTags"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:RunInstances",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:fleet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:spot-instances-request/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:volume/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.project_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.project_name]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid     = "AllowScopedResourceCreationTagging"
    effect  = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:fleet/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:spot-instances-request/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:volume/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.project_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateFleet", "CreateLaunchTemplate", "RunInstances"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid     = "AllowScopedResourceTagging"
    effect  = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.project_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.project_name]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["Name", "eks:eks-cluster-name", "karpenter.sh/nodeclaim"]
    }
  }

  statement {
    sid    = "AllowScopedDeletion"
    effect = "Allow"
    actions = [
      "ec2:DeleteLaunchTemplate",
      "ec2:TerminateInstances",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:*:launch-template/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.project_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowPassingInstanceRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.eks_nodes_role.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowAPIServerEndpointDiscovery"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [aws_eks_cluster.main.arn]
  }

  statement {
    sid    = "AllowInterruptionQueueActions"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.karpenter_interruptions.arn]
  }

  statement {
    sid       = "AllowZonalShiftStatusReadOnly"
    effect    = "Allow"
    actions   = ["arc-zonal-shift:GetManagedResource"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "arc-zonal-shift:ResourceIdentifier"
      values   = [aws_eks_cluster.main.arn]
    }
  }

  statement {
    sid    = "AllowRegionalReadActions"
    effect = "Allow"
    actions = [
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid       = "AllowSSMReadActions"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.region}::parameter/aws/service/*"]
  }

  statement {
    sid       = "AllowPricingReadActions"
    effect    = "Allow"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowInstanceProfileDiscovery"
    effect    = "Allow"
    actions   = ["iam:ListInstanceProfiles"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowInstanceProfileReadActions"
    effect    = "Allow"
    actions   = ["iam:GetInstanceProfile"]
    resources = [aws_iam_instance_profile.nodes.arn]
  }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name   = "KarpenterControllerPolicy-${var.project_name}"
  role   = aws_iam_role.karpenter_controller.id
  policy = data.aws_iam_policy_document.karpenter_controller.json
}
