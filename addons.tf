resource "aws_eks_addon" "cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  addon_version               = coalesce(var.addon_cni_version, data.aws_eks_addon_version.cni.version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_access_entry.nodes
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  addon_version               = coalesce(var.addon_coredns_version, data.aws_eks_addon_version.coredns.version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_access_entry.nodes
  ]
}

resource "aws_eks_addon" "kubeproxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  addon_version               = coalesce(var.addon_kubeproxy_version, data.aws_eks_addon_version.kubeproxy.version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_access_entry.nodes
  ]
}


resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"

  addon_version               = coalesce(var.addon_pod_identity_version, data.aws_eks_addon_version.pod_identity.version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_access_entry.nodes
  ]
}
