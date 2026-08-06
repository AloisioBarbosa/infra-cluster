# AGENTS.md — infra-cluster

Fonte da verdade para IA (ou humano) trabalhando neste repositório. Só
contém fatos verificados no código atual. Confira aqui antes de assumir um
nome de variável, path de SSM, versão de provider ou add-on. Atualize este
arquivo no mesmo PR que mudar o código correspondente.

## O que este repositório faz

Provisiona o cluster EKS na AWS, consumindo os IDs de VPC/subnets publicados
pelo `infra-network` via SSM Parameter Store. Também instala componentes de
observabilidade básicos via Helm (`metrics-server`, `kube-state-metrics`).

**Não** faz bootstrap do ArgoCD ainda — ver seção "O que NÃO existe" abaixo.

## Inventário real de arquivos

| Arquivo | Conteúdo |
|---|---|
| `versions.tf` | `required_version` e `required_providers` (aws, kubernetes, helm) |
| `providers.tf` | providers `aws` (com `default_tags`), `kubernetes`, `helm` |
| `backend.tf` | bloco `backend "s3" {}` **vazio** — precisa de `-backend-config` |
| `variables.tf` | ver lista completa abaixo |
| `data.tf` | data sources de SSM, `aws_eks_cluster_auth`, `aws_caller_identity`, `aws_eks_addon_version` (x4) |
| `eks.tf` | `aws_eks_cluster.main` — encryption via KMS, logging completo, `access_config` modo API |
| `nodes.tf` | `aws_eks_node_group.main` — autoscaling, `lifecycle.ignore_changes` no `desired_size` |
| `addons.tf` | 4 `aws_eks_addon` (vpc-cni, coredns, kube-proxy, eks-pod-identity-agent) |
| `access_entries.tf` | EKS access entries |
| `aws-auth.tf` | configuração de autenticação do cluster |
| `iam_cluster.tf` / `iam_nodes.tf` | IAM roles do cluster e dos nodes |
| `oidc.tf` | provedor OIDC do cluster (para IRSA) |
| `kms.tf` | chave KMS usada na criptografia de secrets do cluster |
| `sg.tf` | security groups |
| `helm_metrics_server.tf` | `helm_release` do metrics-server (Bitnami chart) |
| `helm_kube_state_metrics.tf` | `helm_release` do kube-state-metrics |
| `outputs.tf` | outputs do cluster |
| `terraform.tfvars.example` | exemplo de valores para as variáveis obrigatórias |

**Não existe** separação de ambiente (dev/staging/prod) — único diretório
flat, único state.

## Variáveis (nomes e tipos exatos)

```hcl
variable "project_name"              { type = string }               # obrigatória
variable "region"                    { type = string }               # obrigatória
variable "environment"               { type = string }               # obrigatória: "dev" | "staging" | "prod"
variable "k8s_version"               { type = string }               # obrigatória, ex: "1.31"
variable "ssm_vpc"                   { type = string }               # nome do parametro SSM da VPC
variable "ssm_public_subnets"        { type = list(string) }         # nomes dos parametros SSM
variable "ssm_private_subnets"       { type = list(string) }         # nomes dos parametros SSM
variable "ssm_pod_subnets"           { type = list(string) }         # nomes dos parametros SSM (reaproveita subnets privadas)
variable "auto_scale_options"        { type = object({ min = number, max = number, desired = number }) }
variable "nodes_instance_sizes"      { type = list(string) }
variable "addon_cni_version"         { type = string, default = null }  # override opcional
variable "addon_coredns_version"     { type = string, default = null }  # override opcional
variable "addon_kubeproxy_version"   { type = string, default = null }  # override opcional
variable "addon_pod_identity_version"{ type = string, default = null }  # override opcional
```

As variáveis `ssm_*` recebem os **nomes dos parâmetros** (não os valores) —
o valor real é lido via `data "aws_ssm_parameter"` dentro deste repo. Os
nomes devem bater exatamente com o que o `infra-network` publica (ver o
`AGENTS.md` daquele repo para a lista completa).

**Valor real decidido: `TF_VAR_project_name = infra-network` neste
repositório também** — mesmo valor usado no `infra-network`, não o nome
deste repositório (`infra-cluster`). O `project_name` vira o prefixo dos
paths do SSM (`/infra-network/vpc/...`); se este repo usar um
`project_name` diferente, os `data "aws_ssm_parameter"` abaixo vão tentar
ler parâmetros que não existem e o `plan`/`apply` falha. Confirme se essa
variable já foi criada como repository variable antes de assumir que o
lookup do SSM funciona.

## Resolução de versão dos add-ons EKS

As versões dos 4 add-ons **não são mais hardcoded**. São resolvidas via
`data "aws_eks_addon_version"`, compatível com `var.k8s_version`, e usadas
assim em `addons.tf`:

```hcl
addon_version = coalesce(var.addon_cni_version, data.aws_eks_addon_version.cni.version)
```

Ou seja: se a variável de override não for passada (`null`, o default), a
versão padrão recomendada pela AWS é usada automaticamente. Nunca hardcode
uma versão de add-on em texto — se precisar fixar uma, faça isso via a
variável de override.

## Provider e versões travadas

```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws        = { source = "hashicorp/aws",        version = "~> 5.42" }
    kubernetes = { source = "hashicorp/kubernetes",  version = "~> 2.0" }
    helm       = { source = "hashicorp/helm",        version = "~> 2.0" }
  }
}
```

**Importante**: `kubernetes` e `helm` estão presos na major `2.x` de
propósito. Os `helm_release` existentes usam a sintaxe de bloco
`set { name = ... value = ... }`, que muda para lista de objetos na v3
desses providers. Não faça upgrade para v3 sem migrar essa sintaxe em
`helm_metrics_server.tf` e `helm_kube_state_metrics.tf` primeiro.

## Tags aplicadas automaticamente

Mesmo padrão do `infra-network`, via `default_tags` no provider `aws`:
`Project`, `Environment`, `ManagedBy = "terraform"`, `Repository = "infra-cluster"`.

## CI/CD

Mesmo padrão do `infra-network`: `.github/workflows/terraform.yml` com jobs
`lint` → `trivy-scan` → `plan` → `apply`, mais `CI-SETUP.md` documentando
o que falta configurar manualmente.

**Ainda não verificamos via API o estado real das Variables/Secrets/
Environments deste repositório** (diferente do `infra-network`, onde já
confirmamos). Não assuma que algo aqui está configurado só porque está no
`infra-network` — confira antes.

Problemas já conhecidos no `infra-network` que provavelmente se repetem
aqui, até prova em contrário:
- A policy IAM provavelmente não cobre o backend do Terraform (bucket S3 +
  DynamoDB) — só os recursos gerenciados (EC2/EKS/IAM/SSM/KMS)
- A autenticação pode ter migrado de OIDC pra chaves estáticas
  (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) — confirme qual método
  está ativo no `terraform.yml` antes de debugar
- `TF_VAR_project_name` precisa ser **`infra-network`** (não
  `infra-cluster`) — ver seção de variáveis acima

## Licença

MIT. Mesmo racional do `infra-network`.

## O que NÃO existe neste repositório (não invente)

- Bootstrap do ArgoCD (nenhum `helm_release` para ArgoCD existe ainda —
  esse é o próximo passo planejado, que vai conectar este repo ao
  `app-gitops`)
- Separação por ambiente
- Migração dos providers kubernetes/helm para v3
- IAM role de OIDC configurada para o CI
