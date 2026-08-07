# Registro de retomada do `infra-cluster`

Atualizado em 7 de agosto de 2026.

## Resultado

- Pull Request [#15](https://github.com/AloisioBarbosa/infra-cluster/pull/15)
  mesclada em 7 de agosto de 2026.
- Conta AWS confirmada: `920278691034`.
- Região confirmada: `us-east-1`.
- `terraform fmt`, `terraform validate`, TFLint e Trivy estão passando.
- A autenticação do GitHub Actions com `AWS_ACCESS_KEY_ID` e
  `AWS_SECRET_ACCESS_KEY` funciona.
- `infra-network` restaurado com apply bem-sucedido na run `31185537460`.
- `infra-cluster` implantado com apply bem-sucedido na run `31186635717`.
- EKS `infra-cluster` confirmado como `ACTIVE`, Kubernetes `1.33`, com o managed
  node group `infra-cluster`.

## Causa do bloqueio

A execução manual `31144053653` do `infra-network`, em 7 de agosto de 2026,
executou com sucesso o job `Destroy Infrastructure`. Os jobs `Plan` e `Apply`
foram ignorados nessa run. Como consequência, a VPC, as sub-redes e os
parâmetros SSM publicados pela rede foram removidos.

Parâmetros exigidos pelo cluster:

- `/infra-network/vpc/subnet_private_1a`;
- `/infra-network/vpc/subnet_private_1b`;
- `/infra-network/vpc/subnet_private_1c`.

O bloqueio foi resolvido após a restauração do `infra-network` e a republicação
desses parâmetros.

## Recuperação executada

1. O `infra-network` foi executado com `workflow_dispatch` e `action=apply`.
2. O apply da rede concluiu com sucesso e republicou seu contrato SSM.
3. O plan da PR #15 foi reexecutado e aprovado.
4. A PR #15 foi mesclada em `main`.
5. O apply do `infra-cluster` concluiu com sucesso.
6. O status do EKS e a presença do node group foram confirmados via AWS API.

Para futuras verificações do contrato, valide somente os nomes dos parâmetros:

```bash
aws ssm get-parameter --region us-east-1 \
  --name /infra-network/vpc/subnet_private_1a \
  --query Parameter.Name --output text
```

Repita para `1b` e `1c`.

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

## Guardrails permanentes

- Não acionar `destroy` no `infra-network` ou `infra-cluster`.
- Não executar apply do cluster sem validar primeiro o contrato SSM da rede.
- Não editar o state Terraform manualmente.
- Não publicar access keys, tokens, arquivos `.tfstate` ou planos sensíveis.
