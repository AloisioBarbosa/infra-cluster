# Plano de retomada do `infra-cluster`

Atualizado em 7 de agosto de 2026.

## Estado atual

- Pull Request em preparação: [#15](https://github.com/AloisioBarbosa/infra-cluster/pull/15).
- Branch: `codex/enable-cluster-deploy`.
- Conta AWS confirmada: `920278691034`.
- Região confirmada: `us-east-1`.
- `terraform fmt`, `terraform validate`, TFLint e Trivy estão passando.
- A autenticação do GitHub Actions com `AWS_ACCESS_KEY_ID` e
  `AWS_SECRET_ACCESS_KEY` funciona.
- O Terraform chega ao `plan`, mas falha porque os parâmetros SSM das sub-redes
  privadas não existem.

## Causa do bloqueio

A execução manual `31144053653` do `infra-network`, em 7 de agosto de 2026,
executou com sucesso o job `Destroy Infrastructure`. Os jobs `Plan` e `Apply`
foram ignorados nessa run. Como consequência, a VPC, as sub-redes e os
parâmetros SSM publicados pela rede foram removidos.

Parâmetros exigidos pelo cluster:

- `/infra-network/vpc/subnet_private_1a`;
- `/infra-network/vpc/subnet_private_1b`;
- `/infra-network/vpc/subnet_private_1c`.

O `infra-cluster` não deve ser aplicado enquanto esses parâmetros não existirem.

## Sequência segura para continuar

1. Revisar o `terraform plan` do `infra-network` e confirmar que ele recria a
   VPC, três sub-redes privadas e os três parâmetros SSM acima.
2. Executar `infra-network` com `workflow_dispatch` e `action=apply`.
3. Confirmar o apply verde e validar apenas os nomes dos parâmetros:

   ```bash
   aws ssm get-parameter --region us-east-1 \
     --name /infra-network/vpc/subnet_private_1a \
     --query Parameter.Name --output text
   ```

   Repetir para `1b` e `1c`.
4. Reexecutar os jobs com falha da PR #15 do `infra-cluster`.
5. Revisar o comentário automático do Terraform Plan. O plano esperado não
   pode conter deleções ou substituições inesperadas.
6. Somente depois de um plan aprovado, fazer merge e autorizar o environment
   `production` para o apply do cluster.

## Trade-offs e pendências

- Credenciais estáticas estão sendo usadas temporariamente para desbloquear a
  pipeline. Rotacioná-las após o uso e migrar para uma role OIDC exclusiva do
  `infra-cluster`, gerenciada pelo `infra-bootstrap`.
- Não reutilizar a role `GitHubActionsOIDCInfraNetworkRole` como desenho final.
- Proteger o environment `production` com aprovação obrigatória.
- Restringir as regras amplas de security group antes de classificar o produto
  como production-ready.
- Migrar `metrics-server` e `kube-state-metrics` para `infra-platform` em uma
  mudança futura com preservação explícita do state.

## Ações proibidas na retomada

- Não acionar `destroy` no `infra-network` ou `infra-cluster`.
- Não executar apply do cluster antes de restaurar e validar a rede.
- Não editar o state Terraform manualmente.
- Não publicar access keys, tokens, arquivos `.tfstate` ou planos sensíveis.
