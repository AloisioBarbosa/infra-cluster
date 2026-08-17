output "cluster_name" {
  description = "Nome do cluster EKS publicado para os produtos downstream."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA codificada em base64 para clientes Kubernetes."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "Issuer OIDC usado por integracoes de identidade de workloads."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "Security group principal criado pelo EKS."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "ARN da IAM role usada pelo managed node group."
  value       = aws_iam_role.eks_nodes_role.arn
}

output "fargate_pod_execution_role_arn" {
  description = "ARN da role de execução dos pods críticos em EKS Fargate."
  value       = aws_iam_role.fargate_pod_execution.arn
}

output "karpenter_controller_role_arn" {
  description = "ARN da role IRSA usada pelo controller do Karpenter."
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_interruption_queue_name" {
  description = "Nome da fila SQS usada pelo tratamento de interrupções do Karpenter."
  value       = aws_sqs_queue.karpenter_interruptions.name
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile reutilizado pelos nodes provisionados pelo Karpenter."
  value       = aws_iam_instance_profile.nodes.name
}
