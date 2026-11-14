// =============================================================================
// ConsertaJá — Regras centrais do fluxo de solicitações
// =============================================================================
//
// Este arquivo concentra as regras de status (`fk_status`) e etapa
// (`etapa_solicitacao`) de cada modalidade (`tipo_execucao`). Todas as telas do
// cliente e do profissional devem consultar estas funções para decidir qual
// tela abrir e qual texto exibir, evitando que uma modalidade interfira na
// outra quando o mesmo status é reutilizado em modalidades diferentes.
//
// Tabela de transições (status / etapa):
//
// Comum a todas:
//   1 / 0  Aberto ─► (aceite) 2 / 1 Aguardando Pagamento ─► 3 / 1 Pago
//
// Leva e Traz (5 etapas: Aceito, Busca, Processo, Entrega, Concluído)
//   33 / 2 Profissional Deslocando ─► 34 / 2 Profissional Chegou
//   ─► 4 / 3 Em Andamento ─► 35 / 4 Aguardando Devolução
//   ─► 36 / 4 Devolução Deslocando ─► 37 / 4 Devolução Chegou ─► 6 / 5
//
// Atendimento em Domicílio (4 etapas: Aceito, A caminho, No Local, Concluído)
//   33 / 2 Profissional Deslocando ─► 34 / 3 Profissional Chegou
//   (o status 34 permanece durante todo o atendimento) ─► 6 / 4
//
// Retirado no Local (5 etapas: Aceito, Cliente, Processo, Retirada, Concluído)
//   38 / 2 Cliente Deslocando ─► 4 / 3 Em Andamento
//   ─► 35 / 4 (exibido como "Aguardando retirada pelo cliente") ─► 6 / 5
//
// Receba em Casa (5 etapas: Aceito, Cliente, Processo, Entrega, Concluído)
//   38 / 2 Cliente Deslocando ─► 4 / 3 Em Andamento ─► 35 / 4
//   ─► 36 / 4 Devolução Deslocando ─► 37 / 4 Devolução Chegou ─► 6 / 5
// =============================================================================

/// Modalidades de execução gravadas em `solicitacoes.tipo_execucao` e em
/// `dados_profissionais.metodo_entrega`.
enum ModalidadeExecucao {
  levaETraz,
  atendimentoDomicilio,
  retiradaNoLocal,
  recebaEmCasa;

  /// Converte o texto salvo no banco ("Leva e Traz", "Retirado no Local",
  /// "Receba em Casa", "Atendimento em Domicílio") na modalidade.
  ///
  /// Valores desconhecidos (por exemplo, o nome de uma categoria passado por
  /// engano) caem em [levaETraz], que é o padrão de `tipo_execucao`.
  static ModalidadeExecucao fromString(String? raw) {
    final s = normalizarTexto(raw);
    if (s.contains('leva') && s.contains('traz')) {
      return ModalidadeExecucao.levaETraz;
    }
    if (s.contains('retirad')) return ModalidadeExecucao.retiradaNoLocal;
    if (s.contains('receba')) return ModalidadeExecucao.recebaEmCasa;
    if (s.contains('domic') || s.contains('presencial')) {
      return ModalidadeExecucao.atendimentoDomicilio;
    }
    return ModalidadeExecucao.levaETraz;
  }

  /// Texto canônico gravado no banco.
  String get valorBanco {
    switch (this) {
      case ModalidadeExecucao.levaETraz:
        return 'Leva e Traz';
      case ModalidadeExecucao.atendimentoDomicilio:
        return 'Atendimento em Domicílio';
      case ModalidadeExecucao.retiradaNoLocal:
        return 'Retirado no Local';
      case ModalidadeExecucao.recebaEmCasa:
        return 'Receba em Casa';
    }
  }

  /// O profissional vai até o endereço do cliente no início do fluxo.
  bool get profissionalBuscaNoCliente =>
      this == ModalidadeExecucao.levaETraz ||
      this == ModalidadeExecucao.atendimentoDomicilio;

  /// O cliente leva o produto até o estabelecimento do profissional.
  bool get clienteLevaProduto =>
      this == ModalidadeExecucao.retiradaNoLocal ||
      this == ModalidadeExecucao.recebaEmCasa;

  /// O profissional devolve o produto no endereço do cliente ao final.
  bool get profissionalDevolveNoCliente =>
      this == ModalidadeExecucao.levaETraz ||
      this == ModalidadeExecucao.recebaEmCasa;

  /// O cliente busca o produto no estabelecimento ao final.
  bool get clienteRetiraNoLocal => this == ModalidadeExecucao.retiradaNoLocal;

  /// O serviço acontece no endereço do cliente.
  bool get ehDomicilio => this == ModalidadeExecucao.atendimentoDomicilio;

  /// Número da etapa final (Concluído).
  int get etapaFinal => ehDomicilio ? 4 : 5;

  /// Títulos das etapas exibidas na linha do tempo (índice 0 = etapa 1).
  List<String> get titulosEtapas {
    switch (this) {
      case ModalidadeExecucao.levaETraz:
        return const ['Aceito', 'Busca', 'Processo', 'Entrega', 'Concluído'];
      case ModalidadeExecucao.atendimentoDomicilio:
        return const ['Aceito', 'A caminho', 'No Local', 'Concluído'];
      case ModalidadeExecucao.retiradaNoLocal:
        return const ['Aceito', 'Cliente', 'Processo', 'Retirada', 'Concluído'];
      case ModalidadeExecucao.recebaEmCasa:
        return const ['Aceito', 'Cliente', 'Processo', 'Entrega', 'Concluído'];
    }
  }
}

/// IDs da tabela `status` usados no fluxo de solicitações.
class StatusSolicitacao {
  StatusSolicitacao._();

  static const int aberto = 1;
  static const int aguardandoPagamento = 2;
  static const int pago = 3;
  static const int emAndamento = 4;
  static const int concluido = 6;
  static const int aguardandoDeslocamentoLegado = 32;
  static const int profissionalDeslocando = 33;
  static const int profissionalChegou = 34;
  static const int aguardandoDevolucao = 35;
  static const int devolucaoDeslocando = 36;
  static const int devolucaoChegou = 37;
  static const int clienteDeslocando = 38;
}

/// Telas possíveis do lado do cliente.
enum DestinoCliente {
  detalhes,
  acompanharDeslocamento,
  deslocamentoCliente,
  atendimentoNoLocal,
  confirmarRetirada,
}

/// Telas possíveis do lado do profissional.
enum DestinoProfissional {
  estado,
  deslocamento,
  recebimento,
  devolucaoNoLocal,
  emAndamento,
  atendimentoNoLocal,
}

/// Remove acentos e normaliza para comparação.
String normalizarTexto(String? raw) => (raw ?? '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

/// Converte qualquer variação de método de atendimento (com espaços sobrando,
/// "Retirada no Local", "retirada", etc.) para o texto canônico aceito pela
/// constraint `solicitacoes_tipo_execucao_check`.
String normalizarTipoExecucao(String? raw) =>
    ModalidadeExecucao.fromString(raw).valorBanco;

/// Regras de fluxo aplicadas a uma solicitação específica.
class FluxoSolicitacao {
  FluxoSolicitacao({
    required String? tipoExecucao,
    required this.fkStatus,
    required this.etapa,
    String? statusTexto,
  }) : modalidade = ModalidadeExecucao.fromString(tipoExecucao),
       statusTexto = normalizarTexto(statusTexto);

  final ModalidadeExecucao modalidade;
  final int? fkStatus;
  final int etapa;

  /// Texto do status já normalizado (sem acento, minúsculo).
  final String statusTexto;

  int get _st => fkStatus ?? 0;

  bool get estaAberto =>
      _st == StatusSolicitacao.aberto ||
      statusTexto == 'aberto' ||
      statusTexto.contains('aguardando profissional') ||
      statusTexto == 'pendente' ||
      statusTexto == 'novo';

  /// Aceito, mas ainda sem pagamento confirmado.
  bool get aguardandoPagamento =>
      _st == StatusSolicitacao.aguardandoPagamento ||
      _st == 31 ||
      statusTexto.contains('aguardando pagamento') ||
      statusTexto == 'aceito';

  bool get estaPago => _st == StatusSolicitacao.pago || statusTexto == 'pago';

  bool get estaConcluido =>
      _st == StatusSolicitacao.concluido || statusTexto.contains('conclu');

  bool get emAndamento =>
      _st == StatusSolicitacao.emAndamento || statusTexto == 'em andamento';

  /// Profissional indo até o cliente (busca ou atendimento).
  bool get profissionalDeslocando =>
      _st == StatusSolicitacao.profissionalDeslocando ||
      _st == StatusSolicitacao.aguardandoDeslocamentoLegado;

  /// Profissional chegou no cliente na fase de busca/atendimento.
  /// Registros antigos de "Receba em Casa" gravavam 34 na devolução (etapa 4);
  /// esses casos são tratados como [devolucaoChegou].
  bool get profissionalChegou =>
      _st == StatusSolicitacao.profissionalChegou && !_chegadaDevolucaoLegado;

  bool get _chegadaDevolucaoLegado =>
      _st == StatusSolicitacao.profissionalChegou &&
      etapa >= 4 &&
      modalidade.profissionalDevolveNoCliente;

  bool get clienteDeslocando => _st == StatusSolicitacao.clienteDeslocando;

  /// Serviço pronto, aguardando o profissional iniciar a devolução.
  bool get aguardandoDevolucao =>
      _st == StatusSolicitacao.aguardandoDevolucao &&
      modalidade.profissionalDevolveNoCliente;

  /// Serviço pronto, aguardando o cliente retirar no estabelecimento.
  bool get aguardandoRetirada =>
      modalidade.clienteRetiraNoLocal &&
      (_st == StatusSolicitacao.aguardandoDevolucao ||
          _st == StatusSolicitacao.devolucaoDeslocando ||
          _st == StatusSolicitacao.devolucaoChegou);

  bool get devolucaoDeslocando =>
      _st == StatusSolicitacao.devolucaoDeslocando &&
      modalidade.profissionalDevolveNoCliente;

  bool get devolucaoChegou =>
      (_st == StatusSolicitacao.devolucaoChegou &&
          modalidade.profissionalDevolveNoCliente) ||
      _chegadaDevolucaoLegado;

  /// Etapa coerente com o status, mesmo que o banco esteja desatualizado.
  int get etapaEfetiva {
    if (estaConcluido) return modalidade.etapaFinal;
    if (estaAberto) return 0;
    if (aguardandoPagamento || estaPago) return etapa < 1 ? 1 : etapa;
    if (profissionalDeslocando || clienteDeslocando) return 2;
    if (profissionalChegou) return modalidade.ehDomicilio ? 3 : 2;
    if (emAndamento) return 3;
    if (aguardandoDevolucao ||
        aguardandoRetirada ||
        devolucaoDeslocando ||
        devolucaoChegou) {
      return 4;
    }
    return etapa;
  }

  // ---------------------------------------------------------------------------
  // Ações permitidas
  // ---------------------------------------------------------------------------

  /// Profissional pode iniciar o deslocamento até o cliente (fase de busca).
  bool get profissionalPodeIniciarBusca =>
      estaPago && modalidade.profissionalBuscaNoCliente;

  /// Cliente pode iniciar o deslocamento até o estabelecimento.
  bool get clientePodeIniciarDeslocamento =>
      estaPago && modalidade.clienteLevaProduto;

  /// Profissional está apenas aguardando o cliente levar o produto.
  bool get profissionalAguardaCliente =>
      modalidade.clienteLevaProduto && (estaPago || clienteDeslocando);

  // ---------------------------------------------------------------------------
  // Navegação
  // ---------------------------------------------------------------------------

  DestinoCliente get destinoCliente {
    if (estaConcluido) return DestinoCliente.detalhes;
    switch (modalidade) {
      case ModalidadeExecucao.atendimentoDomicilio:
        if (profissionalChegou) return DestinoCliente.atendimentoNoLocal;
        if (profissionalDeslocando) {
          return DestinoCliente.acompanharDeslocamento;
        }
        return DestinoCliente.detalhes;
      case ModalidadeExecucao.levaETraz:
        if (profissionalDeslocando ||
            profissionalChegou ||
            devolucaoDeslocando ||
            devolucaoChegou) {
          return DestinoCliente.acompanharDeslocamento;
        }
        return DestinoCliente.detalhes;
      case ModalidadeExecucao.recebaEmCasa:
        if (clienteDeslocando) return DestinoCliente.deslocamentoCliente;
        if (devolucaoDeslocando || devolucaoChegou) {
          return DestinoCliente.acompanharDeslocamento;
        }
        return DestinoCliente.detalhes;
      case ModalidadeExecucao.retiradaNoLocal:
        if (clienteDeslocando) return DestinoCliente.deslocamentoCliente;
        if (aguardandoRetirada) return DestinoCliente.confirmarRetirada;
        return DestinoCliente.detalhes;
    }
  }

  DestinoProfissional get destinoProfissional {
    if (estaConcluido || estaAberto) return DestinoProfissional.estado;
    if (emAndamento) return DestinoProfissional.emAndamento;
    switch (modalidade) {
      case ModalidadeExecucao.atendimentoDomicilio:
        if (profissionalChegou) return DestinoProfissional.atendimentoNoLocal;
        if (profissionalDeslocando) return DestinoProfissional.deslocamento;
        return DestinoProfissional.estado;
      case ModalidadeExecucao.levaETraz:
      case ModalidadeExecucao.recebaEmCasa:
        if (profissionalDeslocando &&
            modalidade == ModalidadeExecucao.levaETraz) {
          return DestinoProfissional.deslocamento;
        }
        if (profissionalChegou && modalidade == ModalidadeExecucao.levaETraz) {
          return DestinoProfissional.recebimento;
        }
        if (aguardandoDevolucao || devolucaoDeslocando) {
          return DestinoProfissional.deslocamento;
        }
        if (devolucaoChegou) return DestinoProfissional.devolucaoNoLocal;
        return DestinoProfissional.estado;
      case ModalidadeExecucao.retiradaNoLocal:
        return DestinoProfissional.estado;
    }
  }

  // ---------------------------------------------------------------------------
  // Textos
  // ---------------------------------------------------------------------------

  /// Rótulo do status considerando a modalidade (quando o mesmo `fk_status` é
  /// usado em modalidades diferentes). Retorna `null` quando o texto da
  /// tabela `status` pode ser usado sem alteração.
  String? get rotuloPorModalidade {
    if (estaAberto && _st == StatusSolicitacao.aberto) return 'Aberto';
    if (clienteDeslocando) {
      return modalidade == ModalidadeExecucao.retiradaNoLocal
          ? 'Cliente levando o produto'
          : 'Cliente Deslocando';
    }
    if (aguardandoRetirada) return 'Aguardando retirada pelo cliente';
    if (profissionalChegou && modalidade.ehDomicilio) {
      return 'Atendimento no local';
    }
    if (devolucaoChegou) return 'Devolução Chegou';
    return null;
  }
}
