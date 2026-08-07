# Runbook de desligamento do `infra-cluster`

Este workflow existe para reduzir custos em uma conta pessoal. Ele é manual e
destrutivo; não deve ser usado como mecanismo de rollback.

## Ordem entre produtos

Desligue sempre na ordem inversa das dependências:

1. `infra-apps`;
2. `infra-observability`;
3. `infra-platform`;
4. `infra-cluster`;
5. `infra-network`.

No estado atual, confirme especialmente que o `infra-platform` já removeu seus
releases antes de destruir o EKS. Caso contrário, seu state continuará contendo
recursos Kubernetes inacessíveis depois que o cluster desaparecer.

## Pré-condições

- concluir o handoff do Metrics Server na PR #17;
- confirmar que não há workloads ou dados persistentes necessários;
- confirmar backups e snapshots de volumes, se existirem;
- verificar que nenhum apply de outro produto está em andamento;
- proteger o environment `production` com aprovação obrigatória.

## Execução

1. Abra **Actions → Terraform Pipeline → Run workflow**.
2. Selecione `action = destroy`.
3. Digite exatamente `destroy-infra-cluster` em `confirmation`.
4. Aguarde o job **Destroy Plan**.
5. Revise no log todas as deleções e baixe o artifact do plano, se necessário.
6. Aprove o job **Destroy Apply** no environment `production`.
7. Aguarde a conclusão e confirme que o EKS não existe mais.

O plano binário expira após um dia. O apply utiliza exatamente o artifact
produzido pelo job anterior.

## Verificação

```bash
aws eks describe-cluster --region us-east-1 --name infra-cluster
```

O resultado esperado após a destruição é `ResourceNotFoundException`.

O backend e o state S3 são mantidos pelo `infra-bootstrap`; não apague o state.

## Recriação

Recrie na ordem direta: `infra-network` → `infra-cluster` → `infra-platform` →
`infra-observability` → `infra-apps`. Revise cada plan antes do apply.
