data "aws_iam_policy_document" "fargate_pod_execution_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:fargateprofile/${aws_eks_cluster.main.name}/*",
      ]
    }
  }
}

resource "aws_iam_role" "fargate_pod_execution" {
  name               = "${var.project_name}-fargate-pod-execution"
  assume_role_policy = data.aws_iam_policy_document.fargate_pod_execution_trust.json
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution" {
  role       = aws_iam_role.fargate_pod_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_fargate_profile" "critical_addons" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "critical-addons"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = data.aws_ssm_parameter.private_subnets[*].value

  selector {
    namespace = "karpenter"
  }

  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
    }
  }

  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "metrics-server"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate_pod_execution,
  ]
}
