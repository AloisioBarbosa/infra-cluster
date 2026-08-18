# AGENTS.md — infra-cluster

Fonte da verdade para IA (ou humano) trabalhando neste repositório. Só
contém fatos verificados no código atual. Confira aqui antes de assumir um
nome de variável, path de SSM, versão de provider ou add-on. Atualize este
arquivo no mesmo PR que mudar o código correspondente.

## O que este repositório faz

Provisiona o cluster EKS na AWS, consumindo os IDs de VPC/subnets publicados
pelo `infra-network` via SSM Parameter Store. Instala temporariamente
`kube-state-metrics`; o `metrics-server` está em handoff não destrutivo para o
`infra-plataform`.

**Não** faz bootstrap do ArgoCD ainda — ver seção "O que NÃO existe" abaixo.

## Inventário real de arquivos

| Arquivo | Conteúdo |
|---|---|
| `versions.tf` | `required_version` e `required_providers` (aws, kubernetes, helm, tls) |
| `providers.tf` | providers `aws` (com `default_tags`), `kubernetes`, `helm` |
| `backend.tf` | bloco `backend "s3" {}` **vazio** — precisa de `-backend-config` |
| `variables.tf` | ver lista completa abaixo |
| `data.tf` | data sources de SSM privado/pods, `aws_eks_cluster_auth` e `aws_eks_addon_version` (x4) |
| `eks.tf` | `aws_eks_cluster.main` — encryption via KMS, logging completo, `access_config` modo API |
| `nodes.tf` | `aws_eks_node_group.main` — autoscaling, `lifecycle.ignore_changes` no `desired_size` |
| `addons.tf` | 4 `aws_eks_addon` (vpc-cni, coredns, kube-proxy, eks-pod-identity-agent) |
| `access_entries.tf` | EKS access entries |
| `aws-auth.tf` | configuração de autenticação do cluster |
| `iam_cluster.tf` / `iam_nodes.tf` | IAM roles do cluster e dos nodes |
| `oidc.tf` | provedor OIDC do cluster (para IRSA) |
| `kms.tf` | chave KMS usada na criptografia de secrets do cluster |
| `sg.tf` | security groups |
| `removed_metrics_server.tf` | tombstone não destrutivo que remove `helm_release.metrics_server` deste state |
| `helm_kube_state_metrics.tf` | `helm_release` do kube-state-metrics |
| `outputs.tf` | outputs do cluster |
| `fargate.tf` | role e profile Fargate seletivo para add-ons críticos |
| `karpenter_iam.tf` | role IRSA e policy versionada do controller Karpenter |
| `karpenter_interruption.tf` | fila SQS e regras EventBridge de interrupção |
| `terraform.tfvars.example` | exemplo de valores para as variáveis obrigatórias |

**Não existe** separação de ambiente (dev/staging/prod) — único diretório
flat, único state.

## Variáveis (nomes e tipos exatos)

```hcl
variable "project_name"              { type = string }               # obrigatória
variable "region"                    { type = string }               # obrigatória
variable "environment"               { type = string }               # obrigatória: "dev" | "staging" | "prod"
variable "k8s_version"               { type = string }               # obrigatória, ex: "1.31"
variable "ssm_private_subnets"       { type = list(string) }         # nomes dos parametros SSM
variable "ssm_pod_subnets"           { type = list(string) }         # nomes dos parametros SSM (reaproveita subnets privadas)
variable "auto_scale_options"        { type = object({ min = number, max = number, desired = number }) }
variable "nodes_instance_sizes"      { type = list(string) }
variable "github_actions_role_arn"   { type = string }               # role OIDC exclusiva do pipeline
variable "addon_cni_version"         { type = string, default = null }  # override opcional
variable "addon_coredns_version"     { type = string, default = null }  # override opcional
variable "addon_kubeproxy_version"   { type = string, default = null }  # override opcional
variable "addon_pod_identity_version"{ type = string, default = null }  # override opcional
```

As variáveis `ssm_*` recebem os **nomes dos parâmetros** (não os valores) —
o valor real é lido via `data "aws_ssm_parameter"` dentro deste repo. Os
nomes devem bater exatamente com o que o `infra-network` publica (ver o
`AGENTS.md` daquele repo para a lista completa).

**Contrato atual:** `TF_VAR_project_name = infra-cluster` identifica este
produto e nomeia o cluster. Os inputs `TF_VAR_ssm_*` recebem explicitamente os
paths publicados pelo `infra-network` sob `/infra-network/vpc/*`. O código não
deriva os paths SSM de `project_name`; não acople esses conceitos novamente.

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

`.github/workflows/terraform.yml` executa `validate` e `security`, seguido de
`plan` em PR ou dispatch e `apply` em push para `main` ou dispatch. Plan/apply
assumem via GitHub Actions OIDC a role `GitHubActionsOIDCInfraClusterRole`,
publicada pelo `infra-bootstrap`; o workflow requer `id-token: write` e o secret
`AWS_ROLE_ARN`. A trust cobre os environments `plan` e `production`. O pipeline
usa lock nativo do backend S3 e todas as variáveis obrigatórias via repository
variables. Não reintroduza chaves AWS de longa duração.

Antes do Terraform consultar o provider Helm, os jobs AWS garantem de forma
idempotente um EKS Access Entry para `AWS_ROLE_ARN` associado à policy
`AmazonEKSClusterAdminPolicy`. `access_entries.tf` contém os recursos e imports
declarativos que adotam esse bootstrap no state. Esse contrato resolve a
migração do cluster originalmente criado por `github-user`.

O destroy é somente manual: requer `action = destroy`, confirmação
`destroy-infra-cluster`, artifact de `terraform plan -destroy` e aprovação no
environment `production`. Leia `docs/DESTROY-RUNBOOK.md`. Ordem obrigatória:
`infra-plataform` → `infra-cluster` → `infra-network`.

O Managed Node Group permanece como fallback operacional. CoreDNS, Metrics
Server e o controller do Karpenter são selecionados para EKS Fargate. O
Karpenter usa IRSA, fila SQS de interrupções e o instance profile já usado
pelos managed nodes; não remova esses contratos antes do cutover validado.

O secret `AWS_ROLE_ARN` e a trust OIDC para `plan` e `production` foram
verificados via API em 17 de agosto de 2026.

**Estado verificado em 7 de agosto de 2026:** `infra-network` aplicado na run
`31185537460`; `infra-cluster` aplicado na run `31186635717`; EKS
`infra-cluster` `ACTIVE`, Kubernetes `1.33`, com node group `infra-cluster`.
`docs/CONTINUATION.md` preserva o histórico de recuperação.

Contratos operacionais importantes:
- a policy da role OIDC precisa cobrir o backend S3, os parâmetros SSM
  consumidos e os recursos gerenciados pelo cluster, incluindo SQS e
  EventBridge usados pelo Karpenter;
- `TF_VAR_PROJECT_NAME` deve ser `infra-cluster`; os paths SSM devem manter o
  prefixo `/infra-network/vpc/`.

## Licença

MIT. Mesmo racional do `infra-network`.

## O que NÃO existe neste repositório (não invente)

- Bootstrap do ArgoCD (nenhum `helm_release` para ArgoCD existe ainda —
  esse é o próximo passo planejado, que vai conectar este repo ao
  `app-gitops`)
- Separação por ambiente
- Migração dos providers kubernetes/helm para v3

## Handoff do Metrics Server

O bloco `removed` com `destroy = false` deve ser aplicado antes do import no
`infra-plataform`. Não remova esse tombstone nem recrie `helm_release.metrics_server`
neste repositório durante a migração. Ordem obrigatória:

1. apply do `infra-cluster`, removendo apenas o endereço do state;
2. import/apply do `infra-plataform`, assumindo o release existente;
3. validar `kubectl top nodes` e `kubectl top pods -A`.
