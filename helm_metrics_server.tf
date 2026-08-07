resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  wait = true

  set {
    name  = "apiService.create"
    value = "true"
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}