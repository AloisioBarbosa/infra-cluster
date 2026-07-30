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

variable "ssm_vpc" {
  type        = string
  description = "ID do SSM onde está o id da VPC onde o projeto será criado"
}

variable "ssm_public_subnets" {
  type        = list(string)
  description = "Lista dos ID's do SSM onde estão as subnets públicas do projeto"
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