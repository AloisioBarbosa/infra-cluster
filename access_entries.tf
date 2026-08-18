resource "aws_eks_access_entry" "nodes" {
  cluster_name  = aws_eks_cluster.main.id
  principal_arn = aws_iam_role.eks_nodes_role.arn
  type          = "EC2_LINUX"
}

resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = aws_eks_cluster.main.id
  principal_arn = var.github_actions_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_cluster_admin" {
  cluster_name  = aws_eks_cluster.main.id
  principal_arn = aws_eks_access_entry.github_actions.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "infra_plataform" {
  cluster_name  = aws_eks_cluster.main.id
  principal_arn = var.infra_plataform_github_actions_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "infra_plataform_cluster_admin" {
  cluster_name  = aws_eks_cluster.main.id
  principal_arn = aws_eks_access_entry.infra_plataform.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

import {
  to = aws_eks_access_entry.github_actions
  id = "${var.project_name}:${var.github_actions_role_arn}"
}

import {
  to = aws_eks_access_policy_association.github_actions_cluster_admin
  id = "${var.project_name}#${var.github_actions_role_arn}#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}
