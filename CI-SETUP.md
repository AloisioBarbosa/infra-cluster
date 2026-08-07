# GitHub Actions: configuração do produto `infra-cluster`

O pipeline valida todo Pull Request, gera um `terraform plan` autenticado via
GitHub OIDC e aplica somente após merge em `main` ou acionamento manual. O job
`apply` usa o environment `production`, que deve exigir aprovação.

## Secret

Crie a IAM Role no produto `infra-bootstrap`, com trust no provider
`token.actions.githubusercontent.com`, restrita ao repositório
`AloisioBarbosa/infra-cluster`, e cadastre apenas:

- `AWS_ROLE_ARN`: ARN da role assumida pelo GitHub Actions.

Não use access keys permanentes. A role precisa acessar o backend S3 (incluindo
o lock file), ler os parâmetros SSM do `infra-network` e gerenciar EKS, EC2,
IAM, KMS e o provider OIDC deste produto. A role existente do `infra-network`
não deve ser reutilizada: seu trust está restrito àquele repositório.

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
| `TF_VAR_SSM_VPC` | `/infra-network/vpc/vpc_id` |
| `TF_VAR_SSM_PUBLIC_SUBNETS` | `["/infra-network/vpc/subnet_public_1a","/infra-network/vpc/subnet_public_1b","/infra-network/vpc/subnet_public_1c"]` |
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

1. Confirme que o `infra-network` foi aplicado e publicou os parâmetros SSM.
2. Crie a role OIDC e o secret `AWS_ROLE_ARN`.
3. Cadastre as repository variables.
4. Crie os environments e proteja `production`.
5. Abra a PR e revise o plan publicado como comentário.
6. Faça merge; o apply aguardará aprovação no environment `production`.

O pipeline não oferece `destroy`. Destruições devem usar um runbook separado,
com revisão do plano e autorização explícita.
