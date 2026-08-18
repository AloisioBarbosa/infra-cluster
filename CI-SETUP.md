# GitHub Actions: configuração do produto `infra-cluster`

O pipeline valida todo Pull Request, gera um `terraform plan` autenticado via
GitHub Actions OIDC e aplica somente após merge em `main` ou acionamento
manual. O job `apply` usa o environment `production`, que deve exigir
aprovação. Nenhuma chave AWS de longa duração é necessária no repositório.

## Secrets

- `AWS_ROLE_ARN`: ARN da role
  `GitHubActionsOIDCInfraClusterRole`, provisionada pelo `infra-bootstrap`.

Valor esperado para a conta atual:

```text
arn:aws:iam::920278691034:role/GitHubActionsOIDCInfraClusterRole
```

A trust policy é restrita ao repositório e aos environments `plan` e
`production`. A policy de permissões cobre o backend S3, os parâmetros SSM e os
recursos AWS gerenciados por este produto. Ambos são mantidos pelo
`infra-bootstrap`.

## Repository variables

| Nome | Valor inicial |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `orange-ks8-logs` |
| `TF_STATE_KEY` | `cluster/dev/terraform.tfstate` |
| `TF_VAR_PROJECT_NAME` | `infra-cluster` |
| `TF_VAR_REGION` | `us-east-1` |
| `TF_VAR_ENVIRONMENT` | `dev` |
| `TF_VAR_K8S_VERSION` | `1.33` |
| `TF_VAR_SSM_PRIVATE_SUBNETS` | `["/infra-network/vpc/subnet_private_1a","/infra-network/vpc/subnet_private_1b","/infra-network/vpc/subnet_private_1c"]` |
| `TF_VAR_SSM_POD_SUBNETS` | `["/infra-network/vpc/subnet_private_1a","/infra-network/vpc/subnet_private_1b","/infra-network/vpc/subnet_private_1c"]` |
| `TF_VAR_NODES_INSTANCE_SIZES` | `["t3.medium"]` |
| `TF_VAR_AUTO_SCALE_OPTIONS` | `{"min":1,"max":3,"desired":2}` |

Os valores complexos são JSON válido porque o Terraform interpreta variáveis de
ambiente de tipos `list` e `object` como HCL/JSON.

## Environments

- `plan`: sem aprovação, usado em PRs e em execuções manuais de plan.
- `production`: com required reviewer e prevenção de self-review.

## Ordem de ativação

O primeiro deploy foi concluído com sucesso em 7 de agosto de 2026. Para novas
contas, ambientes ou reconstruções:

1. Confirme que o `infra-network` está aplicado e publicou os três parâmetros
   SSM de sub-redes privadas.
2. Confirme o secret `AWS_ROLE_ARN` e a trust OIDC para os environments `plan`
   e `production`.
3. Confirme as repository variables.
4. Proteja o environment `production`.
5. Abra uma PR e revise o plan publicado como comentário.
6. Faça merge; o apply aguardará aprovação no environment `production`.

O histórico da primeira recuperação está em
[`docs/CONTINUATION.md`](docs/CONTINUATION.md).

## Destroy controlado

O `workflow_dispatch` oferece `action = destroy`, mas exige a confirmação
`destroy-infra-cluster`. O job **Destroy Plan** produz um artifact válido por um
dia; o job **Destroy Apply** usa exatamente esse plano e aguarda aprovação no
environment `production`.

Antes de executar, siga [`docs/DESTROY-RUNBOOK.md`](docs/DESTROY-RUNBOOK.md) e
destrua o `infra-plataform`. Nunca destrua a rede antes do cluster.
