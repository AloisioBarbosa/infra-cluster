# GitHub Actions: configuração do produto `infra-cluster`

O pipeline valida todo Pull Request, gera um `terraform plan` autenticado com
credenciais AWS armazenadas como secrets e aplica somente após merge em `main`
ou acionamento manual. O job
`apply` usa o environment `production`, que deve exigir aprovação. Nesta fase,
o acesso AWS usa chaves estáticas como trade-off temporário para desbloquear o
deploy; a migração para OIDC permanece como melhoria prioritária.

## Secrets

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`.

Use um usuário técnico dedicado, rotacione as chaves e restrinja sua policy ao
backend S3, leitura dos parâmetros SSM e recursos EKS/EC2/IAM/KMS/OIDC deste
produto. Nunca use credenciais de usuário pessoal ou root.

Melhoria futura: criar no `infra-bootstrap` uma IAM Role exclusiva para
`infra-cluster`, com trust em `repo:AloisioBarbosa/infra-cluster:*`, substituir
os secrets acima por `AWS_ROLE_ARN` e restaurar `id-token: write` no workflow.

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
2. Confirme as credenciais do usuário técnico nos dois secrets.
3. Confirme as repository variables.
4. Proteja o environment `production`.
5. Abra uma PR e revise o plan publicado como comentário.
6. Faça merge; o apply aguardará aprovação no environment `production`.

O histórico da primeira recuperação está em
[`docs/CONTINUATION.md`](docs/CONTINUATION.md).

O pipeline não oferece `destroy`. Destruições devem usar um runbook separado,
com revisão do plano e autorização explícita.
