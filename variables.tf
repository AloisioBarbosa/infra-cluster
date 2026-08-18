variable "project_name" {
  type        = string
  description = "Nome do projeto / cluster"
}

variable "region" {
  type        = string
  description = "Nome da região onde os recursos serão entregues"
}

variable "environment" {
  type        = string
  description = "Nome do ambiente (dev, staging, prod). Usado para tagging e organização dos recursos."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O valor de 'environment' deve ser um dos seguintes: dev, staging, prod."
  }
}

variable "k8s_version" {
  type        = string
  description = "Versão do kubernetes do projeto"
}

variable "ssm_private_subnets" {
  type        = list(string)
  description = "Lista dos ID's do SSM onde estão as subnets privadas do projeto"
}

variable "ssm_pod_subnets" {
  type        = list(string)
  description = "Lista dos ID's do SSM onde estão as subnets de pods do projeto"
}

variable "auto_scale_options" {
  type = object({
    min     = number
    max     = number
    desired = number
  })
  description = "Configurações de Autoscaling do Cluster"
}

variable "nodes_instance_sizes" {
  type        = list(string)
  description = "Lista de tamanhos das instâncias do projeto"
}

variable "github_actions_role_arn" {
  type        = string
  description = "ARN da role OIDC do GitHub Actions autorizada a administrar recursos Kubernetes durante o pipeline"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/GitHubActionsOIDCInfraClusterRole$", var.github_actions_role_arn))
    error_message = "github_actions_role_arn deve apontar para a role GitHubActionsOIDCInfraClusterRole."
  }
}

variable "infra_plataform_github_actions_role_arn" {
  type        = string
  description = "ARN da role OIDC do infra-plataform autorizada a administrar os serviços compartilhados no cluster"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/GitHubActionsOIDCInfraPlataformRole$", var.infra_plataform_github_actions_role_arn))
    error_message = "infra_plataform_github_actions_role_arn deve apontar para GitHubActionsOIDCInfraPlataformRole."
  }
}

variable "addon_cni_version" {
  type        = string
  default     = null
  description = "Versão do Addon da VPC CNI. Se não definida, usa a versão padrão recomendada pela AWS para a versão do cluster (var.k8s_version)."
}

variable "addon_coredns_version" {
  type        = string
  default     = null
  description = "Versão do Addon do CoreDNS. Se não definida, usa a versão padrão recomendada pela AWS para a versão do cluster (var.k8s_version)."
}

variable "addon_kubeproxy_version" {
  type        = string
  default     = null
  description = "Versão do Addon do Kube-Proxy. Se não definida, usa a versão padrão recomendada pela AWS para a versão do cluster (var.k8s_version)."
}

variable "addon_pod_identity_version" {
  type        = string
  default     = null
  description = "Versão do Addon do Pod Identity. Se não definida, usa a versão padrão recomendada pela AWS para a versão do cluster (var.k8s_version)."
}
