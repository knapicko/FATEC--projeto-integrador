import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/fluxo_solicitacao.dart';

/// Conta do profissional nas estatísticas.
enum ContaEst { independente, empresa }

extension ContaEstX on ContaEst {
  String get chave => this == ContaEst.empresa ? 'empresa' : 'independente';
  String get rotulo => this == ContaEst.empresa ? 'Loja' : 'Independente';
}

/// Período escolhido no topo da tela.
enum PeriodoEst { semana, mes, ano }

/// Situação do pedido (agrupando os vários status do fluxo).
enum SituacaoPedido {
  aguardandoResposta,
  aguardandoPagamento,
  emAndamento,
  concluido,
  cancelado,
  recusado,
}

class PerfilConta {
  const PerfilConta({required this.conta, required this.nome, this.foto});
  final ContaEst conta;
  final String nome;
  final String? foto;
}

class PedidoEst {
  PedidoEst({
    required this.id,
    required this.conta,
    required this.situacao,
    required this.dataSolicitacao,
    this.dataFinalizacao,
    this.dataAgendada,
    required this.valor,
    this.idCliente,
    required this.clienteCnpj,
    this.servico,
    this.tipoExecucao,
    this.idGeo,
    this.destLat,
    this.destLng,
    this.motivoCancelamento,
    this.metodoPagamento,
    this.dataPagamento,
    required this.pago,
  });

  final int id;
  final ContaEst conta;
  final SituacaoPedido situacao;
  final DateTime dataSolicitacao;
  final DateTime? dataFinalizacao;
  final DateTime? dataAgendada;
  final double valor;
  final int? idCliente;
  final bool clienteCnpj;
  final String? servico;
  final String? tipoExecucao;
  final int? idGeo;
  final double? destLat;
  final double? destLng;
  final String? motivoCancelamento;
  final String? metodoPagamento;
  final DateTime? dataPagamento;

  /// Pagamento confirmado (entra no faturamento).
  final bool pago;

  bool get cancelouOuRecusou =>
      situacao == SituacaoPedido.cancelado ||
      situacao == SituacaoPedido.recusado;

  /// Data em que o dinheiro conta no gráfico financeiro.
  DateTime get dataReceita =>
      dataPagamento ?? dataFinalizacao ?? dataSolicitacao;
}

/// Dados brutos vindos de `estatisticas_profissional()`.
class DadosEstatisticas {
  DadosEstatisticas({
    required this.temLoja,
    required this.perfis,
    required this.pedidos,
    required this.notas,
    required this.seguidores,
    required this.visualizacoes,
    required this.distanciaRadar,
    required this.origens,
    required this.atividade,
    this.idProfissional,
    this.idGrupoEmpresa,
  });

  final int? idProfissional;
  final int? idGrupoEmpresa;
  final bool temLoja;
  final Map<ContaEst, PerfilConta> perfis;
  final List<PedidoEst> pedidos;

  /// (conta, nota, data) das avaliações recebidas.
  final List<({ContaEst conta, double nota, DateTime? data})> notas;
  final Map<ContaEst, int> seguidores;

  /// (conta, tipo 'perfil'|'servico', dia, quantidade).
  final List<({ContaEst conta, String tipo, DateTime dia, int qtd})>
  visualizacoes;

  /// id da solicitação geográfica → distância (km) informada pelo Radar.
  final Map<int, double> distanciaRadar;
  final Map<ContaEst, ({double lat, double lng})> origens;

  /// Segundos com o app aberto por dia (é da pessoa, vale para as 2 contas).
  final Map<DateTime, int> atividade;

  List<ContaEst> get contas =>
      temLoja ? const [ContaEst.independente, ContaEst.empresa] : const [ContaEst.independente];
}

/// Uma série de barras: rótulos do eixo X e valores por conta.
class SerieBarras {
  const SerieBarras(this.rotulos, this.valores);
  final List<String> rotulos;
  final Map<ContaEst, List<double>> valores;

  double get maximo {
    var m = 0.0;
    for (final l in valores.values) {
      for (final v in l) {
        if (v > m) m = v;
      }
    }
    return m;
  }
}

/// Todas as métricas de UMA conta num período.
class MetricasConta {
  MetricasConta({required this.conta});
  final ContaEst conta;

  // Financeiro
  double bruto = 0;
  double liquido = 0;
  int vendasPagas = 0;
  double get ticketMedio => vendasPagas == 0 ? 0 : bruto / vendasPagas;
  double mediaDiaria = 0;
  double ticketPeriodoAnterior = 0;
  List<double> brutoSerie = const [];
  List<double> liquidoSerie = const [];
  double receitaCpf = 0;
  double receitaCnpj = 0;
  Map<String, int> metodos = {};

  // Desempenho
  double nota = 0;
  int totalAvaliacoes = 0;
  double recorrencia = 0;
  int clientesUnicos = 0;
  int clientesRecorrentes = 0;
  int visualizacoesPerfil = 0;
  int visualizacoesServico = 0;
  int pedidosRecebidos = 0;
  int seguidores = 0;
  double get conversao =>
      visualizacoesPerfil + visualizacoesServico == 0
          ? 0
          : vendasConcluidas / (visualizacoesPerfil + visualizacoesServico);

  // Vendas
  int vendasConcluidas = 0;
  List<double> pedidosPorDiaSemana = List.filled(7, 0);
  List<MapEntry<String, int>> ranking = const [];
  int cancelados = 0;
  int recusados = 0;
  double get taxaCancelamento =>
      pedidosRecebidos == 0 ? 0 : (cancelados + recusados) / pedidosRecebidos;
  Map<String, int> motivos = {};
  int retrabalhos = 0;
  double get taxaRetrabalho =>
      vendasConcluidas == 0 ? 0 : retrabalhos / vendasConcluidas;
  Map<String, int> modalidades = {};

  // Operação (situação atual, sem período)
  Map<SituacaoPedido, int> fluxo = {
    for (final s in SituacaoPedido.values) s: 0,
  };
  double? distanciaMediaKm;
  int pedidosComDistancia = 0;
  double proximidade = 0;
  Duration? tempoMedio;
  double? cumprimentoPrazo;
  int pedidosComPrazo = 0;
}

class EstatisticasProfissionalService {
  EstatisticasProfissionalService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Taxa estimada do processador de pagamento por método (o líquido é o
  /// bruto menos essa taxa). A taxa de serviço do app é cobrada à parte do
  /// cliente, então não sai do valor do profissional.
  static double taxaPagamento(String? metodo, double valor) {
    final m = (metodo ?? '').toLowerCase();
    if (valor <= 0) return 0;
    if (m.contains('pix')) return valor * 0.0119;
    if (m.contains('boleto')) return 3.45;
    if (m.contains('card') ||
        m.contains('cart') ||
        m.contains('cred') ||
        m.contains('deb')) {
      return valor * 0.0399 + 0.39;
    }
    return 0;
  }

  static Future<DadosEstatisticas> carregar() async {
    final r = await _db.rpc('estatisticas_profissional');
    final j = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
    if (j['erro'] != null) {
      throw Exception(
        j['erro'] == 'sem_login'
            ? 'Faça login para ver suas estatísticas.'
            : 'Não encontramos os dados do seu perfil profissional.',
      );
    }
    final temLoja = j['tem_loja'] == true;

    PerfilConta perfil(ContaEst c, String padrao) {
      final m = j[c.chave];
      final nome = m is Map ? m['nome']?.toString().trim() : null;
      final foto = m is Map ? m['foto']?.toString().trim() : null;
      return PerfilConta(
        conta: c,
        nome: (nome == null || nome.isEmpty) ? padrao : nome,
        foto: (foto == null || foto.isEmpty || foto == 'null') ? null : foto,
      );
    }

    final perfis = {
      ContaEst.independente: perfil(ContaEst.independente, 'Independente'),
      if (temLoja) ContaEst.empresa: perfil(ContaEst.empresa, 'Loja'),
    };

    // Pagamentos por pedido
    final pag = <int, Map>{};
    for (final p in _lista(j['pagamentos'])) {
      final id = _int(p['id_solicitacao']);
      if (id != null) pag[id] = p;
    }

    final pedidos = <PedidoEst>[];
    for (final item in _lista(j['pedidos'])) {
      final s = item['s'] is Map ? item['s'] as Map : const {};
      final id = _int(s['id_solicitacao']);
      if (id == null) continue;
      final conta = item['conta'] == 'empresa'
          ? ContaEst.empresa
          : ContaEst.independente;
      if (conta == ContaEst.empresa && !temLoja) continue;
      final statusNome = item['status_nome']?.toString();
      final fk = _int(s['fk_status']);
      final p = pag[id];
      final statusPag = p?['status']?.toString().toLowerCase() ?? '';
      final situacao = _situacao(fk, statusNome, s['tipo_execucao'], s);
      final pagoStripe =
          statusPag == 'succeeded' ||
          statusPag == 'paid' ||
          statusPag.contains('pago') ||
          p?['data'] != null;
      final pago =
          pagoStripe ||
          situacao == SituacaoPedido.emAndamento ||
          situacao == SituacaoPedido.concluido;
      final destino = item['destino'];
      pedidos.add(
        PedidoEst(
          id: id,
          conta: conta,
          situacao: situacao,
          dataSolicitacao:
              _data(s['data_solicitacao']) ??
              _data(s['data_criacao']) ??
              DateTime.now(),
          dataFinalizacao: _data(s['data_finalizacao']),
          dataAgendada: _data(s['data_agendada']),
          valor: _double(s['valor_final']) ?? _double(s['valor_total']) ?? 0,
          idCliente: _int(s['fk_usuario']),
          clienteCnpj: item['cliente_cnpj'] == true,
          servico: item['servico']?.toString(),
          tipoExecucao: s['tipo_execucao']?.toString(),
          idGeo: _int(s['fk_solicitacao_geografica']),
          destLat: destino is Map ? _double(destino['lat']) : null,
          destLng: destino is Map ? _double(destino['lng']) : null,
          motivoCancelamento: s['motivo_cancelamento']?.toString(),
          metodoPagamento: p?['metodo']?.toString(),
          dataPagamento: _data(p?['data']),
          pago: pago,
        ),
      );
    }

    // Nota: avaliação do profissional; se não houver, a do serviço.
    final notasProf = <({ContaEst conta, double nota, DateTime? data})>[];
    final notasServ = <({ContaEst conta, double nota, DateTime? data})>[];
    for (final a in _lista(j['avaliacoes'])) {
      final tipo = a['tipo']?.toString().toLowerCase() ?? '';
      if (tipo == 'cliente') continue;
      final nota = _double(a['nota']);
      if (nota == null) continue;
      final conta = a['conta'] == 'empresa'
          ? ContaEst.empresa
          : ContaEst.independente;
      final reg = (conta: conta, nota: nota, data: _data(a['data']));
      (tipo == 'profissional' ? notasProf : notasServ).add(reg);
    }
    final notas = [
      ...notasProf,
      for (final n in notasServ)
        if (!notasProf.any((p) => p.conta == n.conta)) n,
    ];

    final seg = j['seguidores'] is Map ? j['seguidores'] as Map : const {};
    final vis = [
      for (final v in _lista(j['visualizacoes']))
        if (_data(v['dia']) != null)
          (
            conta: v['conta'] == 'empresa'
                ? ContaEst.empresa
                : ContaEst.independente,
            tipo: v['tipo']?.toString() ?? 'perfil',
            dia: _data(v['dia'])!,
            qtd: _int(v['qtd']) ?? 0,
          ),
    ];
    final radar = <int, double>{
      for (final r in _lista(j['radar']))
        if (_int(r['id_solicitacao_geografica']) != null &&
            _double(r['distancia_km']) != null)
          _int(r['id_solicitacao_geografica'])!: _double(r['distancia_km'])!,
    };
    ({double lat, double lng})? origem(Object? o) {
      if (o is! Map) return null;
      final lat = _double(o['lat']);
      final lng = _double(o['lng']);
      if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
      return (lat: lat, lng: lng);
    }

    final origens = <ContaEst, ({double lat, double lng})>{
      if (origem(j['origem_independente']) != null)
        ContaEst.independente: origem(j['origem_independente'])!,
      if (origem(j['origem_empresa']) != null)
        ContaEst.empresa: origem(j['origem_empresa'])!,
    };
    final atividade = <DateTime, int>{
      for (final a in _lista(j['atividade']))
        if (_data(a['dia']) != null)
          _dia(_data(a['dia'])!): _int(a['segundos']) ?? 0,
    };

    return DadosEstatisticas(
      temLoja: temLoja,
      perfis: perfis,
      pedidos: pedidos,
      notas: notas,
      seguidores: {
        ContaEst.independente: _int(seg['independente']) ?? 0,
        ContaEst.empresa: _int(seg['empresa']) ?? 0,
      },
      visualizacoes: vis,
      distanciaRadar: radar,
      origens: origens,
      atividade: atividade,
      idProfissional: _int(j['id_profissional']),
      idGrupoEmpresa: _int(j['id_grupo_empresa']),
    );
  }

  // ───────────────────────────────────────────────────────── períodos

  /// Início e fim (exclusivo) do período atual.
  static (DateTime, DateTime) intervalo(PeriodoEst p, [DateTime? agora]) {
    final h = _dia(agora ?? DateTime.now());
    switch (p) {
      case PeriodoEst.semana:
        final ini = h.subtract(Duration(days: h.weekday - 1));
        return (ini, ini.add(const Duration(days: 7)));
      case PeriodoEst.mes:
        return (DateTime(h.year, h.month), DateTime(h.year, h.month + 1));
      case PeriodoEst.ano:
        return (DateTime(h.year), DateTime(h.year + 1));
    }
  }

  static (DateTime, DateTime) intervaloAnterior(PeriodoEst p) {
    final (ini, _) = intervalo(p);
    return intervalo(p, ini.subtract(const Duration(days: 1)));
  }

  static List<String> rotulosEixo(PeriodoEst p) {
    switch (p) {
      case PeriodoEst.semana:
        return const ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
      case PeriodoEst.mes:
        final (ini, fim) = intervalo(p);
        final semanas = ((fim.difference(ini).inDays + ini.weekday - 1) / 7)
            .ceil();
        return [for (var i = 1; i <= semanas; i++) 'SEM $i'];
      case PeriodoEst.ano:
        return const [
          'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
          'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
        ];
    }
  }

  static int _indiceEixo(PeriodoEst p, DateTime d) {
    switch (p) {
      case PeriodoEst.semana:
        return d.weekday - 1;
      case PeriodoEst.mes:
        final ini = DateTime(d.year, d.month);
        return (d.day - 1 + ini.weekday - 1) ~/ 7;
      case PeriodoEst.ano:
        return d.month - 1;
    }
  }

  static bool _dentro(DateTime d, (DateTime, DateTime) i) =>
      !d.isBefore(i.$1) && d.isBefore(i.$2);

  // ───────────────────────────────────────────────────────── cálculo

  static MetricasConta calcular(
    DadosEstatisticas dados,
    ContaEst conta,
    PeriodoEst periodo,
  ) {
    final m = MetricasConta(conta: conta);
    final todos = [
      for (final p in dados.pedidos)
        if (p.conta == conta) p,
    ];
    final faixa = intervalo(periodo);
    final anterior = intervaloAnterior(periodo);
    final noPeriodo = [
      for (final p in todos)
        if (_dentro(p.dataSolicitacao.toLocal(), faixa)) p,
    ];
    final eixo = rotulosEixo(periodo).length;

    // Financeiro (pela data do pagamento)
    final bruto = List<double>.filled(eixo, 0);
    final liquido = List<double>.filled(eixo, 0);
    var brutoAnterior = 0.0;
    var vendasAnteriores = 0;
    for (final p in todos) {
      if (!p.pago || p.cancelouOuRecusou) continue;
      final d = p.dataReceita.toLocal();
      if (_dentro(d, anterior)) {
        brutoAnterior += p.valor;
        vendasAnteriores++;
      }
      if (!_dentro(d, faixa)) continue;
      final liq = p.valor - taxaPagamento(p.metodoPagamento, p.valor);
      final i = _indiceEixo(periodo, d).clamp(0, eixo - 1);
      bruto[i] += p.valor;
      liquido[i] += liq;
      m.bruto += p.valor;
      m.liquido += liq;
      m.vendasPagas++;
      if (p.clienteCnpj) {
        m.receitaCnpj += p.valor;
      } else {
        m.receitaCpf += p.valor;
      }
      final metodo = rotuloMetodo(p.metodoPagamento);
      m.metodos[metodo] = (m.metodos[metodo] ?? 0) + 1;
    }
    m.brutoSerie = bruto;
    m.liquidoSerie = liquido;
    m.ticketPeriodoAnterior = vendasAnteriores == 0
        ? 0
        : brutoAnterior / vendasAnteriores;
    final hoje = _dia(DateTime.now());
    final diasDecorridos = math.max(
      1,
      (hoje.isBefore(faixa.$2) ? hoje : faixa.$2.subtract(const Duration(days: 1)))
              .difference(faixa.$1)
              .inDays +
          1,
    );
    m.mediaDiaria = m.bruto / diasDecorridos;

    // Desempenho
    final notas = [
      for (final n in dados.notas)
        if (n.conta == conta) n.nota,
    ];
    m.totalAvaliacoes = notas.length;
    m.nota = notas.isEmpty ? 0 : notas.reduce((a, b) => a + b) / notas.length;
    final porCliente = <int, int>{};
    for (final p in todos) {
      if (p.idCliente == null || p.cancelouOuRecusou) continue;
      if (p.situacao == SituacaoPedido.aguardandoResposta) continue;
      porCliente[p.idCliente!] = (porCliente[p.idCliente!] ?? 0) + 1;
    }
    m.clientesUnicos = porCliente.length;
    m.clientesRecorrentes = porCliente.values.where((v) => v >= 2).length;
    m.recorrencia = m.clientesUnicos == 0
        ? 0
        : m.clientesRecorrentes / m.clientesUnicos;
    for (final v in dados.visualizacoes) {
      if (v.conta != conta || !_dentro(v.dia, faixa)) continue;
      if (v.tipo == 'servico') {
        m.visualizacoesServico += v.qtd;
      } else {
        m.visualizacoesPerfil += v.qtd;
      }
    }
    m.seguidores = dados.seguidores[conta] ?? 0;

    // Vendas e qualidade (pela data do pedido)
    m.pedidosRecebidos = noPeriodo.length;
    final rank = <String, int>{};
    for (final p in noPeriodo) {
      m.pedidosPorDiaSemana[p.dataSolicitacao.toLocal().weekday - 1]++;
      if (p.situacao == SituacaoPedido.concluido) m.vendasConcluidas++;
      if (p.situacao == SituacaoPedido.cancelado) {
        m.cancelados++;
        final motivo = (p.motivoCancelamento ?? '').trim();
        final chave = motivo.isEmpty ? 'Cancelado sem motivo informado' : motivo;
        m.motivos[chave] = (m.motivos[chave] ?? 0) + 1;
      }
      if (p.situacao == SituacaoPedido.recusado) {
        m.recusados++;
        m.motivos['Recusado pelo profissional'] =
            (m.motivos['Recusado pelo profissional'] ?? 0) + 1;
      }
      if (!p.cancelouOuRecusou) {
        final nome = (p.servico ?? '').trim().isEmpty
            ? 'Serviço sem título'
            : p.servico!.trim();
        rank[nome] = (rank[nome] ?? 0) + 1;
        final mod = ModalidadeExecucao.fromString(p.tipoExecucao).valorBanco;
        m.modalidades[mod] = (m.modalidades[mod] ?? 0) + 1;
      }
    }
    m.ranking = rank.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Retrabalho/garantia: o mesmo cliente volta a pedir o mesmo serviço
    // até 30 dias depois de um atendimento concluído.
    final concluidos = [
      for (final p in todos)
        if (p.situacao == SituacaoPedido.concluido) p,
    ]..sort((a, b) => a.dataSolicitacao.compareTo(b.dataSolicitacao));
    for (final p in concluidos) {
      if (!_dentro(p.dataSolicitacao.toLocal(), faixa)) continue;
      final repetiu = concluidos.any(
        (o) =>
            o.id != p.id &&
            o.idCliente != null &&
            o.idCliente == p.idCliente &&
            (o.servico ?? '') == (p.servico ?? '') &&
            o.dataSolicitacao.isBefore(p.dataSolicitacao) &&
            p.dataSolicitacao.difference(o.dataFinalizacao ?? o.dataSolicitacao).inDays <= 30,
      );
      if (repetiu) m.retrabalhos++;
    }

    // Operação: situação atual de todos os pedidos
    for (final p in todos) {
      m.fluxo[p.situacao] = (m.fluxo[p.situacao] ?? 0) + 1;
    }

    // Distância até o cliente e pedidos vindos do Radar (proximidade)
    final origem = dados.origens[conta];
    var somaKm = 0.0;
    var aceitos = 0;
    var doRadar = 0;
    for (final p in noPeriodo) {
      if (p.cancelouOuRecusou || p.situacao == SituacaoPedido.aguardandoResposta) {
        continue;
      }
      aceitos++;
      if (p.idGeo != null) doRadar++;
      double? km = p.idGeo == null ? null : dados.distanciaRadar[p.idGeo];
      if (km == null &&
          origem != null &&
          p.destLat != null &&
          p.destLng != null &&
          !(p.destLat == 0 && p.destLng == 0)) {
        km = distanciaKm(origem.lat, origem.lng, p.destLat!, p.destLng!);
      }
      if (km != null && km < 500) {
        somaKm += km;
        m.pedidosComDistancia++;
      }
    }
    m.distanciaMediaKm = m.pedidosComDistancia == 0
        ? null
        : somaKm / m.pedidosComDistancia;
    m.proximidade = aceitos == 0 ? 0 : doRadar / aceitos;

    // Eficiência de tempo
    var somaMin = 0;
    var comTempo = 0;
    var noPrazo = 0;
    for (final p in noPeriodo) {
      if (p.situacao != SituacaoPedido.concluido) continue;
      final fim = p.dataFinalizacao;
      if (fim != null && fim.isAfter(p.dataSolicitacao)) {
        somaMin += fim.difference(p.dataSolicitacao).inMinutes;
        comTempo++;
      }
      final prazo = p.dataAgendada;
      if (prazo != null && fim != null) {
        m.pedidosComPrazo++;
        if (!_dia(fim.toLocal()).isAfter(_dia(prazo))) noPrazo++;
      }
    }
    m.tempoMedio = comTempo == 0 ? null : Duration(minutes: somaMin ~/ comTempo);
    m.cumprimentoPrazo = m.pedidosComPrazo == 0
        ? null
        : noPrazo / m.pedidosComPrazo;
    return m;
  }

  /// Dias seguidos com o app aberto (até hoje ou ontem).
  static int constancia(DadosEstatisticas d) {
    bool ativo(DateTime dia) => (d.atividade[dia] ?? 0) >= 60;
    var dia = _dia(DateTime.now());
    if (!ativo(dia)) dia = dia.subtract(const Duration(days: 1));
    var n = 0;
    while (ativo(dia)) {
      n++;
      dia = dia.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Tempo online no período e média por dia ativo.
  static ({Duration total, Duration mediaDia, int diasAtivos}) tempoOnline(
    DadosEstatisticas d,
    PeriodoEst p,
  ) {
    final faixa = intervalo(p);
    var seg = 0;
    var dias = 0;
    d.atividade.forEach((dia, s) {
      if (_dentro(dia, faixa) && s > 0) {
        seg += s;
        dias++;
      }
    });
    return (
      total: Duration(seconds: seg),
      mediaDia: Duration(seconds: dias == 0 ? 0 : seg ~/ dias),
      diasAtivos: dias,
    );
  }

  /// Os últimos 7 dias (do mais antigo ao de hoje): ativo ou não.
  static List<bool> ultimos7Dias(DadosEstatisticas d) {
    final hoje = _dia(DateTime.now());
    return [
      for (var i = 6; i >= 0; i--)
        (d.atividade[hoje.subtract(Duration(days: i))] ?? 0) >= 60,
    ];
  }

  static String rotuloMetodo(String? m) {
    final t = (m ?? '').toLowerCase();
    if (t.contains('pix')) return 'Pix';
    if (t.contains('boleto')) return 'Boleto';
    if (t.contains('deb')) return 'Débito';
    if (t.contains('card') || t.contains('cred') || t.contains('cart')) {
      return 'Crédito';
    }
    if (t.contains('dinheiro') || t.contains('cash')) return 'Dinheiro';
    if (t.isEmpty) return 'Não informado';
    return m!.trim();
  }

  static double distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  // ───────────────────────────────────────────────────────── utilitários

  static SituacaoPedido _situacao(
    int? fk,
    String? nome,
    Object? tipoExecucao,
    Map s,
  ) {
    final t = normalizarTexto(nome);
    if (fk == 7 || t.contains('cancel')) return SituacaoPedido.cancelado;
    if (fk == 30 || t.contains('recus')) return SituacaoPedido.recusado;
    final f = FluxoSolicitacao(
      tipoExecucao: tipoExecucao?.toString(),
      fkStatus: fk,
      etapa: _int(s['etapa_solicitacao']) ?? 0,
      statusTexto: nome,
    );
    if (f.estaConcluido || fk == StatusSolicitacao.concluido) {
      return SituacaoPedido.concluido;
    }
    if (f.estaAberto) return SituacaoPedido.aguardandoResposta;
    if (f.aguardandoPagamento) return SituacaoPedido.aguardandoPagamento;
    return SituacaoPedido.emAndamento;
  }

  static List<Map> _lista(Object? o) =>
      o is List ? [for (final e in o) if (e is Map) e] : const [];

  static int? _int(Object? o) =>
      o is num ? o.toInt() : int.tryParse(o?.toString() ?? '');

  static double? _double(Object? o) =>
      o is num ? o.toDouble() : double.tryParse(o?.toString() ?? '');

  static DateTime? _data(Object? o) {
    if (o == null) return null;
    final d = DateTime.tryParse(o.toString());
    return d?.isUtc == true ? d!.toLocal() : d;
  }

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);
}
