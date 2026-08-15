# Handoff para o produto infra-plataform.
# Mantem o release instalado enquanto remove sua propriedade deste state.
removed {
  from = helm_release.metrics_server

  lifecycle {
    destroy = false
  }
}
