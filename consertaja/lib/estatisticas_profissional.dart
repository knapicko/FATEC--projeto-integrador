import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/estatisticas_profissional_service.dart';
import 'tutorial/botao_ajuda.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_da_tela.dart';
import 'widgets/imagem_app.dart';
import 'widgets/skeleton_loading.dart';
import 'utils/movimento.dart';

/// Estatísticas e Gráficos do profissional.
///
/// Mostra os dados das DUAS contas (independente e loja) quando o perfil é
/// de Loja, com o filtro Todos / Independente / Empresa. Sem loja, mostra só
/// a conta independente e não há filtro. Os dados se atualizam sozinhos
/// (Realtime + recarga periódica) e dá para arrastar para recarregar.
class EstatisticasProfissionalPage extends StatefulWidget {
  const EstatisticasProfissionalPage({super.key});

  @override
  State<EstatisticasProfissionalPage> createState() =>
      _EstatisticasProfissionalPageState();
}

// Paleta: só os azuis do app e variações.
const _azul = Color(0xFF0FB3FF);
const _azulEscuro = Color(0xFF004A7C);
const _azulNoite = Color(0xFF0B2545);
const _azulMedio = Color(0xFF3D7EAA);
const _azulClaro = Color(0xFFDAF3FF);
const _azulGelo = Color(0xFFEFF8FF);
const _fundo = Color(0xFFF4F7FA);
const _texto = Color(0xFF0F172A);
const _textoSuave = Color(0xFF64748B);
const _linha = Color(0xFFE2E8F0);

Color _corConta(ContaEst c) => c == ContaEst.empresa ? _azulEscuro : _azul;

class _EstatisticasProfissionalPageState
    extends State<EstatisticasProfissionalPage>
    with TutorialDaTela<EstatisticasProfissionalPage> {
  final _rolagem = ScrollController();

  DadosEstatisticas? _dados;
  bool _carregando = true;
  String? _erro;

  PeriodoEst _periodo = PeriodoEst.semana;

  /// null = Todos.
  ContaEst? _filtro;
  bool _liquido = false;

  /// Muda a cada recarga "de verdade" (abrir, puxar, trocar período/filtro):
  /// os gráficos redesenham do zero. Recargas automáticas só animam a
  /// diferença.
  int _versao = 0;

  final List<RealtimeChannel> _canais = [];
  Timer? _timer;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _carregar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    for (final c in _canais) {
      Supabase.instance.client.removeChannel(c);
    }
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        if (_dados == null) _carregando = true;
        _erro = null;
      });
    }
    try {
      final d = await EstatisticasProfissionalService.carregar();
      if (!mounted) return;
      setState(() {
        _dados = d;
        _carregando = false;
        _erro = null;
        if (!silencioso) _versao++;
        if (!d.temLoja) _filtro = null;
      });
      _assinarRealtime(d);
    } catch (e) {
      if (!mounted) return;
      if (silencioso && _dados != null) return;
      setState(() {
        _carregando = false;
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _assinarRealtime(DadosEstatisticas d) {
    if (_canais.isNotEmpty) return;
    final db = Supabase.instance.client;
    void mudou(PostgresChangePayload _) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 1200),
        () => _carregar(silencioso: true),
      );
    }

    final filtros = <(String, int)>[
      if (d.idProfissional != null) ('fk_profissional', d.idProfissional!),
      if (d.idGrupoEmpresa != null) ('fk_grupo_empresa', d.idGrupoEmpresa!),
    ];
    for (final (coluna, valor) in filtros) {
      final canal = db
          .channel('estatisticas_${coluna}_$valor')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'solicitacoes',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: coluna,
              value: valor,
            ),
            callback: mudou,
          )
          .subscribe();
      _canais.add(canal);
    }
  }

  void _trocarPeriodo(PeriodoEst p) {
    if (p == _periodo) return;
    setState(() {
      _periodo = p;
      _versao++;
    });
  }

  void _trocarFiltro(ContaEst? f) {
    if (f == _filtro) return;
    setState(() {
      _filtro = f;
      _versao++;
    });
  }

  List<ContaEst> get _contas {
    final d = _dados;
    if (d == null) return const [ContaEst.independente];
    if (!d.temLoja) return const [ContaEst.independente];
    return _filtro == null ? d.contas : [_filtro!];
  }

  bool get _comparando => _contas.length > 1;

  // ───────────────────────────────────────────────────────── tutorial

  List<PassoTutorial> _passos() => [
    PassoTutorial(
      'Aqui ficam as estatísticas do seu trabalho no ConsertaJá, com dados '
      'reais dos seus pedidos.',
      alvo: chaveTut('cabecalho'),
    ),
    PassoTutorial(
      'Escolha o período: esta semana, este mês ou este ano.',
      alvo: chaveTut('periodo'),
    ),
    if (_dados?.temLoja == true)
      PassoTutorial(
        'Como você tem uma Loja, dá para ver as duas contas juntas (Todos) '
        'ou só a Independente ou só a Empresa.',
        alvo: chaveTut('filtro'),
      ),
    PassoTutorial(
      'Visão financeira: quanto você faturou (bruto e líquido), a média por '
      'dia, de onde vem o dinheiro e as formas de pagamento. Toque numa '
      'barra para ver o valor.',
      alvo: chaveTut('financeiro'),
      rolagem: _rolagem,
      alinhamentoRolagem: 0.15,
    ),
    PassoTutorial(
      'Desempenho: sua nota, quantos clientes voltaram, quem viu seu perfil '
      'e os dias seguidos em que você abriu o app.',
      alvo: chaveTut('desempenho'),
      rolagem: _rolagem,
      alinhamentoRolagem: 0.15,
    ),
    PassoTutorial(
      'Raio-X das vendas: os dias com mais pedidos, seus serviços '
      '"carro-chefe" e os índices de cancelamento e retrabalho.',
      alvo: chaveTut('vendas'),
      rolagem: _rolagem,
      alinhamentoRolagem: 0.15,
    ),
    PassoTutorial(
      'Operação: em que etapa estão seus pedidos agora, a distância até os '
      'clientes e se você entrega no prazo. Arraste para baixo para '
      'recarregar; os números também se atualizam sozinhos.',
      alvo: chaveTut('operacao'),
      rolagem: _rolagem,
      alinhamentoRolagem: 0.15,
    ),
  ];

  // ───────────────────────────────────────────────────────── build

  @override
  Widget build(BuildContext context) {
    if (_dados != null) {
      tutorialDaTela(chave: 'estatisticas_profissional', passos: _passos);
    }
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: Column(
          children: [
            alvoTut('cabecalho', _cabecalho()),
            Expanded(child: _corpo()),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _azul, size: 26),
          ),
          const Expanded(
            child: Text(
              'Estatísticas e Gráficos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azul,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          BotaoAjuda(
            passos: () => passosAjuda(reserva: _passos),
            cor: _azul,
            diametro: 44,
          ),
        ],
      ),
    );
  }

  Widget _corpo() {
    if (_carregando && _dados == null) return _esqueleto();
    if (_erro != null && _dados == null) {
      return RefreshIndicator(
        color: _azul,
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.query_stats_rounded, color: _azul, size: 56),
            const SizedBox(height: 16),
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textoSuave, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Center(
              child: CorOriginal(
                interface: true,
                child: FilledButton(
                  onPressed: _carregar,
                  style: FilledButton.styleFrom(backgroundColor: _azul),
                  child: const Text('Tentar de novo'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final d = _dados!;
    final metricas = {
      for (final c in _contas)
        c: EstatisticasProfissionalService.calcular(d, c, _periodo),
    };
    return RefreshIndicator(
      color: _azul,
      onRefresh: _carregar,
      child: ListView(
        controller: _rolagem,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          alvoTut('periodo', _seletorPeriodo()),
          if (d.temLoja) ...[
            const SizedBox(height: 10),
            alvoTut('filtro', _seletorConta(d)),
          ],
          if (_comparando) ...[
            const SizedBox(height: 12),
            _Legenda(perfis: [for (final c in _contas) d.perfis[c]!]),
          ],
          const SizedBox(height: 18),
          alvoTut('financeiro', _secaoFinanceira(d, metricas)),
          const SizedBox(height: 22),
          alvoTut('desempenho', _secaoDesempenho(d, metricas)),
          const SizedBox(height: 22),
          alvoTut('vendas', _secaoVendas(d, metricas)),
          const SizedBox(height: 22),
          alvoTut('operacao', _secaoOperacao(d, metricas)),
          const SizedBox(height: 12),
          const Text(
            'Arraste para baixo para recarregar. Os dados também se '
            'atualizam sozinhos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textoSuave, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _esqueleto() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 48, borderRadius: 24),
        SizedBox(height: 20),
        SkeletonBox(height: 20, width: 160),
        SizedBox(height: 12),
        SkeletonBox(height: 240, borderRadius: 20),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 120, borderRadius: 20)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 120, borderRadius: 20)),
          ],
        ),
        SizedBox(height: 14),
        SkeletonBox(height: 170, borderRadius: 20),
        SizedBox(height: 14),
        SkeletonBox(height: 140, borderRadius: 20),
      ],
    );
  }

  // ───────────────────────────────────────────────────────── seletores

  Widget _seletorPeriodo() {
    const rotulos = {
      PeriodoEst.semana: 'Semana',
      PeriodoEst.mes: 'Mês',
      PeriodoEst.ano: 'Ano',
    };
    return _Segmentado<PeriodoEst>(
      valores: PeriodoEst.values,
      selecionado: _periodo,
      rotulo: (p) => rotulos[p]!,
      aoTrocar: _trocarPeriodo,
    );
  }

  Widget _seletorConta(DadosEstatisticas d) {
    final opcoes = <ContaEst?>[null, ContaEst.independente, ContaEst.empresa];
    return _Segmentado<ContaEst?>(
      valores: opcoes,
      selecionado: _filtro,
      altura: 40,
      rotulo: (c) => switch (c) {
        null => 'Todos',
        ContaEst.independente => 'Independente',
        ContaEst.empresa => 'Empresa',
      },
      aoTrocar: _trocarFiltro,
    );
  }

  // ───────────────────────────────────────────────────────── 1. financeiro

  Widget _secaoFinanceira(
    DadosEstatisticas d,
    Map<ContaEst, MetricasConta> m,
  ) {
    final serie = SerieBarras(
      EstatisticasProfissionalService.rotulosEixo(_periodo),
      {
        for (final e in m.entries)
          e.key: _liquido ? e.value.liquidoSerie : e.value.brutoSerie,
      },
    );
    final total = m.values.fold<double>(
      0,
      (s, x) => s + (_liquido ? x.liquido : x.bruto),
    );
    final mediaDia = m.values.fold<double>(
      0,
      (s, x) =>
          s + (_liquido ? x.mediaDiaria * (x.bruto == 0 ? 0 : x.liquido / x.bruto) : x.mediaDiaria),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao('Visão Financeira'),
        _Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Segmentado<bool>(
                    valores: const [false, true],
                    selecionado: _liquido,
                    altura: 32,
                    largura: 170,
                    rotulo: (v) => v ? 'Líquido' : 'Bruto',
                    aoTrocar: (v) => setState(() => _liquido = v),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 15,
                    color: _textoSuave,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Toque nas barras',
                    style: TextStyle(fontSize: 11, color: _textoSuave),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _liquido ? 'Lucro líquido' : 'Faturamento total',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textoSuave,
                          ),
                        ),
                        _NumeroAnimado(
                          valor: total,
                          formatar: _moeda,
                          estilo: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Média diária',
                        style: TextStyle(fontSize: 14, color: _textoSuave),
                      ),
                      _NumeroAnimado(
                        valor: mediaDia,
                        formatar: _moeda,
                        estilo: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _azulEscuro,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_comparando) ...[
                const SizedBox(height: 8),
                _ValoresPorConta(
                  perfis: d.perfis,
                  valores: {
                    for (final e in m.entries)
                      e.key: _moeda(_liquido ? e.value.liquido : e.value.bruto),
                  },
                ),
              ],
              const SizedBox(height: 16),
              _GraficoBarras(
                key: ValueKey('fin-$_versao-$_liquido'),
                serie: serie,
                altura: 170,
                formatar: (v) => _moedaCurta(v),
                vazio: 'Nenhum pagamento neste período',
              ),
              const SizedBox(height: 14),
              const Divider(color: _linha, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniKpi(
                    rotulo: 'Bruto',
                    valor: _moeda(m.values.fold(0.0, (s, x) => s + x.bruto)),
                  ),
                  _MiniKpi(
                    rotulo: 'Líquido',
                    valor: _moeda(m.values.fold(0.0, (s, x) => s + x.liquido)),
                  ),
                  _MiniKpi(
                    rotulo: 'Vendas pagas',
                    valor:
                        '${m.values.fold<int>(0, (s, x) => s + x.vendasPagas)}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Líquido = bruto menos a taxa estimada da forma de pagamento '
                '(Pix 1,19%; cartão 3,99% + R\$ 0,39; boleto R\$ 3,45).',
                style: TextStyle(fontSize: 10.5, color: _textoSuave),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cartaoSegmento(d, m)),
              const SizedBox(width: 12),
              Expanded(child: _cartaoTicket(d, m)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _cartaoMetodos(d, m),
      ],
    );
  }

  Widget _cartaoSegmento(DadosEstatisticas d, Map<ContaEst, MetricasConta> m) {
    return _Cartao(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RotuloCartao(
            icone: Icons.pie_chart_outline_rounded,
            texto: 'RECEITA POR SEGMENTO',
          ),
          const SizedBox(height: 10),
          for (final e in m.entries) ...[
            if (_comparando) _MiniPerfil(perfil: d.perfis[e.key]!),
            _LinhaRosca(
              key: ValueKey('seg-$_versao-${e.key}'),
              fatias: [
                ('Residencial (CPF)', e.value.receitaCpf, _corConta(e.key)),
                ('Comercial (CNPJ)', e.value.receitaCnpj, _azulClaro),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _cartaoTicket(DadosEstatisticas d, Map<ContaEst, MetricasConta> m) {
    return _Cartao(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RotuloCartao(
            icone: Icons.local_atm_rounded,
            texto: 'MÉDIA POR SERVIÇO',
          ),
          const SizedBox(height: 10),
          for (final e in m.entries) ...[
            if (_comparando) _MiniPerfil(perfil: d.perfis[e.key]!),
            _NumeroAnimado(
              valor: e.value.ticketMedio,
              formatar: _moeda,
              estilo: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _texto,
              ),
            ),
            Text(
              _variacao(e.value.ticketMedio, e.value.ticketPeriodoAnterior),
              style: const TextStyle(fontSize: 11.5, color: _textoSuave),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _variacao(double atual, double antes) {
    final quando = switch (_periodo) {
      PeriodoEst.semana => 'à semana passada',
      PeriodoEst.mes => 'ao mês passado',
      PeriodoEst.ano => 'ao ano passado',
    };
    if (antes == 0 && atual == 0) return 'Sem vendas para comparar';
    if (antes == 0) return 'Sem vendas em relação $quando';
    final p = (atual - antes) / antes * 100;
    final sinal = p >= 0 ? '+' : '';
    return '$sinal${p.toStringAsFixed(0)}% em relação $quando';
  }

  Widget _cartaoMetodos(DadosEstatisticas d, Map<ContaEst, MetricasConta> m) {
    final nomes = <String>{};
    for (final x in m.values) {
      nomes.addAll(x.metodos.keys);
    }
    final ordem = ['Pix', 'Crédito', 'Débito', 'Boleto', 'Dinheiro'];
    final lista = [
      ...ordem.where(nomes.contains),
      ...nomes.where((n) => !ordem.contains(n)),
    ];
    if (lista.isEmpty) lista.addAll(const ['Pix', 'Crédito', 'Débito', 'Boleto']);
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RotuloCartao(
            icone: Icons.account_balance_wallet_outlined,
            texto: 'MÉTODOS DE PAGAMENTO',
          ),
          const SizedBox(height: 14),
          for (final nome in lista) ...[
            for (final e in m.entries)
              Builder(
                builder: (_) {
                  final total = e.value.metodos.values.fold<int>(
                    0,
                    (s, v) => s + v,
                  );
                  final qtd = e.value.metodos[nome] ?? 0;
                  final frac = total == 0 ? 0.0 : qtd / total;
                  return _BarraRotulada(
                    key: ValueKey('met-$_versao-$nome-${e.key}'),
                    rotulo: e.key == m.keys.first ? nome : null,
                    valor: frac,
                    direita: '${(frac * 100).round()}%',
                    cor: _comparando
                        ? _corConta(e.key)
                        : Color.lerp(_azulClaro, _azulNoite, 0.35 + frac * 0.65)!,
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────── 2. desempenho

  Widget _secaoDesempenho(
    DadosEstatisticas d,
    Map<ContaEst, MetricasConta> m,
  ) {
    final online = EstatisticasProfissionalService.tempoOnline(d, _periodo);
    final dias = EstatisticasProfissionalService.constancia(d);
    final semana = EstatisticasProfissionalService.ultimos7Dias(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao('Desempenho & Engajamento'),
        for (final e in m.entries) ...[
          if (_comparando)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MiniPerfil(perfil: d.perfis[e.key]!, grande: true),
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cartaoNota(e.value)),
                const SizedBox(width: 12),
                Expanded(child: _cartaoFunil(e.value)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _cartaoConstancia(dias, online, semana),
      ],
    );
  }

  Widget _cartaoNota(MetricasConta m) {
    return CorOriginal(
      interface: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_azulNoite, _azulEscuro],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Icon(
                Icons.star_rounded,
                size: 90,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Estrelas(nota: m.nota),
                const SizedBox(height: 6),
                _NumeroAnimado(
                  valor: m.nota,
                  formatar: (v) => m.totalAvaliacoes == 0
                      ? '–'
                      : v.toStringAsFixed(1).replaceAll('.', ','),
                  estilo: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  m.totalAvaliacoes == 0
                      ? 'Sem avaliações ainda'
                      : 'Média de ${m.totalAvaliacoes} '
                            '${m.totalAvaliacoes == 1 ? 'avaliação' : 'avaliações'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TAXA DE RECORRÊNCIA',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      _NumeroAnimado(
                        valor: m.recorrencia * 100,
                        formatar: (v) => '${v.round()}%',
                        estilo: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${m.clientesRecorrentes} de ${m.clientesUnicos} '
                        'clientes voltaram',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoFunil(MetricasConta m) {
    final etapas = [
      ('Visitas ao perfil', m.visualizacoesPerfil),
      ('Cliques em serviços', m.visualizacoesServico),
      ('Pedidos recebidos', m.pedidosRecebidos),
      ('Vendas concluídas', m.vendasConcluidas),
    ];
    final maior = etapas.fold<int>(1, (s, e) => math.max(s, e.$2));
    return _Cartao(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RotuloCartao(
            icone: Icons.filter_alt_outlined,
            texto: 'VISIBILIDADE',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < etapas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _BarraFunil(
                key: ValueKey('funil-$_versao-$i-${m.conta}'),
                rotulo: etapas[i].$1,
                valor: etapas[i].$2,
                fracao: etapas[i].$2 / maior,
                cor: Color.lerp(_azulClaro, _azulNoite, i / 3)!,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Conversão: ${(m.conversao * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _azulEscuro,
            ),
          ),
          Text(
            '${m.seguidores} ${m.seguidores == 1 ? 'seguidor' : 'seguidores'}',
            style: const TextStyle(fontSize: 11.5, color: _textoSuave),
          ),
        ],
      ),
    );
  }

  Widget _cartaoConstancia(
    int dias,
    ({Duration total, Duration mediaDia, int diasAtivos}) online,
    List<bool> semana,
  ) {
    const iniciais = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final hoje = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _sombra,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CorOriginal(
              interface: true,
              child: Container(width: 5, color: _azul),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CorOriginal(
                          interface: true,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: _azulGelo,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color: dias > 0 ? _azul : _textoSuave,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Constância',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _texto,
                                ),
                              ),
                              Text(
                                dias == 0
                                    ? 'Abra o app hoje para começar uma sequência!'
                                    : '$dias ${dias == 1 ? 'dia seguido ativo' : 'dias seguidos ativos'}!',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textoSuave,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Tempo online',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textoSuave,
                              ),
                            ),
                            Text(
                              _duracaoCurta(online.total),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _texto,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Column(
                            children: [
                              AnimatedContainer(
                                duration: duracao(
                                  Duration(milliseconds: 300 + i * 70),
                                ),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: semana[i] ? _azul : _azulGelo,
                                  shape: BoxShape.circle,
                                ),
                                child: semana[i]
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                iniciais[hoje
                                        .subtract(Duration(days: 6 - i))
                                        .weekday %
                                    7],
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: _textoSuave,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Média de ${_duracaoCurta(online.mediaDia)} por dia ativo '
                      '(${online.diasAtivos} ${online.diasAtivos == 1 ? 'dia' : 'dias'} no período).',
                      style: const TextStyle(fontSize: 11.5, color: _textoSuave),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────── 3. vendas

  Widget _secaoVendas(DadosEstatisticas d, Map<ContaEst, MetricasConta> m) {
    final picos = SerieBarras(
      const ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'],
      {for (final e in m.entries) e.key: e.value.pedidosPorDiaSemana},
    );
    final ranking = <String, Map<ContaEst, int>>{};
    for (final e in m.entries) {
      for (final r in e.value.ranking) {
        ranking.putIfAbsent(r.key, () => {})[e.key] = r.value;
      }
    }
    final top = ranking.entries.toList()
      ..sort(
        (a, b) => b.value.values
            .fold<int>(0, (s, v) => s + v)
            .compareTo(a.value.values.fold<int>(0, (s, v) => s + v)),
      );
    final maiorRank = top.isEmpty
        ? 1
        : top
              .expand((e) => e.value.values)
              .fold<int>(1, (s, v) => math.max(s, v));
    final modalidades = <String, Map<ContaEst, int>>{};
    for (final e in m.entries) {
      e.value.modalidades.forEach((k, v) {
        modalidades.putIfAbsent(k, () => {})[e.key] = v;
      });
    }
    final totalVendas = m.values.fold<int>(0, (s, x) => s + x.vendasConcluidas);
    final recebidos = m.values.fold<int>(0, (s, x) => s + x.pedidosRecebidos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao('Raio-X das Vendas'),
        _Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: _azulEscuro,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Total de Vendas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                  ),
                  _NumeroAnimado(
                    valor: totalVendas.toDouble(),
                    formatar: (v) => '${v.round()}',
                    estilo: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _texto,
                    ),
                  ),
                ],
              ),
              Text(
                '$recebidos ${recebidos == 1 ? 'pedido recebido' : 'pedidos recebidos'} no período'
                '${_comparando ? ' · ${m.entries.map((e) => '${e.key.rotulo}: ${e.value.vendasConcluidas}').join(' · ')}' : ''}',
                style: const TextStyle(fontSize: 12, color: _textoSuave),
              ),
              const SizedBox(height: 14),
              const Divider(color: _linha, height: 1),
              const SizedBox(height: 14),
              const Text(
                'Picos de demanda (pedidos por dia da semana)',
                style: TextStyle(fontSize: 13.5, color: _textoSuave),
              ),
              const SizedBox(height: 12),
              _GraficoBarras(
                key: ValueKey('picos-$_versao'),
                serie: picos,
                altura: 120,
                formatar: (v) => '${v.round()}',
                vazio: 'Nenhum pedido neste período',
              ),
              const SizedBox(height: 16),
              const Text(
                'Serviços mais solicitados',
                style: TextStyle(fontSize: 13.5, color: _textoSuave),
              ),
              const SizedBox(height: 10),
              if (top.isEmpty)
                const _Vazio('Nenhum serviço solicitado neste período')
              else
                for (final r in top.take(5)) ...[
                  for (final c in m.keys)
                    _BarraRotulada(
                      key: ValueKey('rank-$_versao-${r.key}-$c'),
                      rotulo: c == m.keys.first ? r.key : null,
                      valor: (r.value[c] ?? 0) / maiorRank,
                      direita: '${r.value[c] ?? 0}',
                      cor: _comparando ? _corConta(c) : _azulEscuro,
                      grosso: true,
                    ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 6),
              for (final e in m.entries) ...[
                if (_comparando) _MiniPerfil(perfil: d.perfis[e.key]!),
                Row(
                  children: [
                    Expanded(
                      child: _CaixaIndice(
                        titulo: 'Cancelamentos',
                        valor: e.value.taxaCancelamento,
                        detalhe:
                            '${e.value.cancelados + e.value.recusados} de ${e.value.pedidosRecebidos}',
                        claro: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CaixaIndice(
                        titulo: 'Retrabalho / garantia',
                        valor: e.value.taxaRetrabalho,
                        detalhe:
                            '${e.value.retrabalhos} de ${e.value.vendasConcluidas}',
                        claro: true,
                      ),
                    ),
                  ],
                ),
                if (e.value.motivos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final mo
                      in (e.value.motivos.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value)))
                          .take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 15,
                            color: _textoSuave,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              mo.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textoSuave,
                              ),
                            ),
                          ),
                          Text(
                            '${mo.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _texto,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 10),
              ],
              const Text(
                'Retrabalho: o mesmo cliente pediu o mesmo serviço de novo até '
                '30 dias depois de um atendimento concluído.',
                style: TextStyle(fontSize: 10.5, color: _textoSuave),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RotuloCartao(
                icone: Icons.alt_route_rounded,
                texto: 'MODALIDADE DE ATENDIMENTO',
              ),
              const SizedBox(height: 12),
              if (modalidades.isEmpty)
                const _Vazio('Nenhum pedido neste período')
              else
                for (final mo in modalidades.entries) ...[
                  for (final c in m.keys)
                    Builder(
                      builder: (_) {
                        final total = m[c]!.modalidades.values.fold<int>(
                          0,
                          (s, v) => s + v,
                        );
                        final q = mo.value[c] ?? 0;
                        return _BarraRotulada(
                          key: ValueKey('mod-$_versao-${mo.key}-$c'),
                          rotulo: c == m.keys.first ? mo.key : null,
                          valor: total == 0 ? 0 : q / total,
                          direita: '$q',
                          cor: _comparando ? _corConta(c) : _azulMedio,
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────── 4. operação

  Widget _secaoOperacao(DadosEstatisticas d, Map<ContaEst, MetricasConta> m) {
    const blocos = [
      (SituacaoPedido.aguardandoResposta, Icons.mark_email_unread_outlined, 'AG. RESPOSTA'),
      (SituacaoPedido.aguardandoPagamento, Icons.payments_outlined, 'AG. PAGAMENTO'),
      (SituacaoPedido.emAndamento, Icons.build_outlined, 'EM ANDAMENTO'),
      (SituacaoPedido.concluido, Icons.check_circle_outline_rounded, 'REALIZADOS'),
      (SituacaoPedido.cancelado, Icons.cancel_outlined, 'CANCELADOS'),
      (SituacaoPedido.recusado, Icons.block_rounded, 'RECUSADOS'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao('Operação & Logística'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.98,
          children: [
            for (final (sit, icone, rotulo) in blocos)
              _BlocoStatus(
                icone: icone,
                rotulo: rotulo,
                destaque: sit == SituacaoPedido.emAndamento,
                total: m.values.fold<int>(0, (s, x) => s + (x.fluxo[sit] ?? 0)),
                detalhe: _comparando
                    ? m.entries
                          .map(
                            (e) =>
                                '${e.key == ContaEst.empresa ? 'L' : 'I'} ${e.value.fluxo[sit] ?? 0}',
                          )
                          .join(' · ')
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Situação atual de todos os seus pedidos (não depende do período).',
          style: TextStyle(fontSize: 10.5, color: _textoSuave),
        ),
        const SizedBox(height: 12),
        for (final e in m.entries) ...[
          _Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_comparando) _MiniPerfil(perfil: d.perfis[e.key]!),
                Row(
                  children: [
                    CorOriginal(
                      interface: true,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: _azulGelo,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.route_rounded, color: _azulEscuro),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ParValor(
                        rotulo: 'Média de distância',
                        valor: e.value.distanciaMediaKm == null
                            ? 'Sem dados'
                            : '${e.value.distanciaMediaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                      ),
                    ),
                    _ParValor(
                      rotulo: 'Tempo médio',
                      valor: e.value.tempoMedio == null
                          ? 'Sem dados'
                          : _duracaoLonga(e.value.tempoMedio!),
                      fim: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BarraRotulada(
                  key: ValueKey('prox-$_versao-${e.key}'),
                  rotulo: 'Pedidos aceitos vindos do Radar (proximidade)',
                  valor: e.value.proximidade,
                  direita: '${(e.value.proximidade * 100).round()}%',
                  cor: _azul,
                ),
                const SizedBox(height: 10),
                _BarraRotulada(
                  key: ValueKey('prazo-$_versao-${e.key}'),
                  rotulo: e.value.cumprimentoPrazo == null
                      ? 'Cumprimento de prazo (sem pedidos agendados concluídos)'
                      : 'Cumprimento de prazo (${e.value.pedidosComPrazo} agendados)',
                  valor: e.value.cumprimentoPrazo ?? 0,
                  direita: e.value.cumprimentoPrazo == null
                      ? '–'
                      : '${(e.value.cumprimentoPrazo! * 100).round()}%',
                  cor: _azulEscuro,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Distância: do seu endereço até o do cliente (ou a medida '
                  'pelo Radar). Tempo médio: do pedido até a conclusão.',
                  style: TextStyle(fontSize: 10.5, color: _textoSuave),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════ formatação

String _moeda(double v) {
  final neg = v < 0;
  final centavos = (v.abs() * 100).round();
  final inteiro = (centavos ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
  final dec = (centavos % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}R\$ $buf,$dec';
}

String _moedaCurta(double v) {
  if (v >= 1000000) {
    return 'R\$${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
  }
  if (v >= 10000) return 'R\$${(v / 1000).toStringAsFixed(0)}k';
  if (v >= 1000) {
    return 'R\$${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
  }
  return 'R\$${v.round()}';
}

String _duracaoCurta(Duration d) {
  if (d.inMinutes < 1) return '0min';
  if (d.inHours < 1) return '${d.inMinutes}min';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours}h' : '${d.inHours}h${m.toString().padLeft(2, '0')}';
}

String _duracaoLonga(Duration d) {
  if (d.inHours < 1) return '${math.max(1, d.inMinutes)} min';
  if (d.inHours < 24) return '${d.inHours} h';
  final dias = d.inMinutes / (60 * 24);
  return '${dias.toStringAsFixed(1).replaceAll('.', ',')} dias';
}

final _sombra = [
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

// ═════════════════════════════════════════════════════════ componentes

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _azulNoite,
      ),
    ),
  );
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: _sombra,
    ),
    child: child,
  );
}

class _RotuloCartao extends StatelessWidget {
  const _RotuloCartao({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icone, size: 16, color: _azulNoite),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _azulNoite,
          ),
        ),
      ),
    ],
  );
}

class _Vazio extends StatelessWidget {
  const _Vazio(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 12.5, color: _textoSuave),
    ),
  );
}

/// Controle segmentado com o fundo branco deslizando até a opção escolhida.
class _Segmentado<T> extends StatelessWidget {
  const _Segmentado({
    required this.valores,
    required this.selecionado,
    required this.rotulo,
    required this.aoTrocar,
    this.altura = 48,
    this.largura,
  });

  final List<T> valores;
  final T selecionado;
  final String Function(T) rotulo;
  final ValueChanged<T> aoTrocar;
  final double altura;
  final double? largura;

  @override
  Widget build(BuildContext context) {
    final i = math.max(0, valores.indexOf(selecionado));
    final n = valores.length;
    return SizedBox(
      height: altura,
      width: largura,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE6ECF2),
          borderRadius: BorderRadius.circular(altura / 2),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / n;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: duracao(const Duration(milliseconds: 260)),
                  curve: Curves.easeOutCubic,
                  left: w * i,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(altura / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var k = 0; k < n; k++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => aoTrocar(valores[k]),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: duracao(
                                const Duration(milliseconds: 200),
                              ),
                              style: TextStyle(
                                fontSize: altura >= 44 ? 16 : 13,
                                fontWeight: k == i
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: k == i ? _azulNoite : _textoSuave,
                              ),
                              child: Text(
                                rotulo(valores[k]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bolinha com a foto da conta.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.perfil, this.tamanho = 22});
  final PerfilConta perfil;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cor = _corConta(perfil.conta);
    final inicial = perfil.nome.isEmpty ? '?' : perfil.nome[0].toUpperCase();
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cor, width: 2),
      ),
      child: ClipOval(
        child: perfil.foto == null
            ? CorOriginal(
                interface: true,
                child: Container(
                  color: cor,
                  alignment: Alignment.center,
                  child: Text(
                    inicial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tamanho * 0.42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : ImagemApp(
                child: Image.network(
                  perfil.foto!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: cor),
                ),
              ),
      ),
    );
  }
}

/// Avatar + nome + tipo da conta (cabeçalho de um bloco no modo Todos).
class _MiniPerfil extends StatelessWidget {
  const _MiniPerfil({required this.perfil, this.grande = false});
  final PerfilConta perfil;
  final bool grande;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        _Avatar(perfil: perfil, tamanho: grande ? 26 : 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            perfil.nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: grande ? 13.5 : 11.5,
              fontWeight: FontWeight.w800,
              color: _texto,
            ),
          ),
        ),
        const SizedBox(width: 6),
        CorOriginal(
          interface: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _corConta(perfil.conta),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              perfil.conta.rotulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.perfis});
  final List<PerfilConta> perfis;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: [
      for (final p in perfis)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _corConta(p.conta),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            _Avatar(perfil: p, tamanho: 22),
            const SizedBox(width: 6),
            Text(
              p.conta.rotulo,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _texto,
              ),
            ),
          ],
        ),
    ],
  );
}

class _ValoresPorConta extends StatelessWidget {
  const _ValoresPorConta({required this.perfis, required this.valores});
  final Map<ContaEst, PerfilConta> perfis;
  final Map<ContaEst, String> valores;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final e in valores.entries)
        Expanded(
          child: Row(
            children: [
              _Avatar(perfil: perfis[e.key]!, tamanho: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${e.key.rotulo}: ${e.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _corConta(e.key),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.rotulo, required this.valor});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          rotulo,
          style: const TextStyle(fontSize: 11, color: _textoSuave),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _texto,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ParValor extends StatelessWidget {
  const _ParValor({required this.rotulo, required this.valor, this.fim = false});
  final String rotulo;
  final String valor;
  final bool fim;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: fim ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(rotulo, style: const TextStyle(fontSize: 13, color: _textoSuave)),
      Text(
        valor,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: _texto,
        ),
      ),
    ],
  );
}

/// Número que conta até o valor (e anima a diferença nas atualizações).
class _NumeroAnimado extends StatelessWidget {
  const _NumeroAnimado({
    required this.valor,
    required this.formatar,
    required this.estilo,
  });
  final double valor;
  final String Function(double) formatar;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: valor),
    duration: duracao(const Duration(milliseconds: 900)),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(formatar(v), style: estilo),
  );
}

class _Estrelas extends StatelessWidget {
  const _Estrelas({required this.nota});
  final double nota;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: nota),
    duration: duracao(const Duration(milliseconds: 1000)),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            v >= i
                ? Icons.star_rounded
                : v >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            color: const Color(0xFF7FD4FF),
            size: 19,
          ),
      ],
    ),
  );
}

/// Barra horizontal com rótulo em cima e valor à direita (cresce animada).
class _BarraRotulada extends StatelessWidget {
  const _BarraRotulada({
    super.key,
    this.rotulo,
    required this.valor,
    required this.direita,
    required this.cor,
    this.grosso = false,
  });

  final String? rotulo;
  final double valor;
  final String direita;
  final Color cor;
  final bool grosso;

  @override
  Widget build(BuildContext context) {
    final alto = grosso ? 8.0 : 7.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rotulo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                rotulo!,
                style: TextStyle(
                  fontSize: grosso ? 14 : 12.5,
                  fontWeight: grosso ? FontWeight.w600 : FontWeight.w500,
                  color: _texto,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(alto),
                  child: Container(
                    height: alto,
                    color: const Color(0xFFE9EEF3),
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: valor.clamp(0.0, 1.0)),
                      duration: duracao(const Duration(milliseconds: 900)),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cor,
                            borderRadius: BorderRadius.circular(alto),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text(
                  direita,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _texto,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarraFunil extends StatelessWidget {
  const _BarraFunil({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.fracao,
    required this.cor,
  });
  final String rotulo;
  final int valor;
  final double fracao;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final escuro = cor.computeLuminance() < 0.4;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.25, end: 0.25 + 0.75 * fracao.clamp(0, 1)),
              duration: duracao(const Duration(milliseconds: 900)),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) =>
                  FractionallySizedBox(widthFactor: v, child: child),
              child: CorOriginal(
                interface: escuro,
                ativo: escuro,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _compacto(valor),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: escuro ? Colors.white : _azulNoite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: Text(
            rotulo,
            style: const TextStyle(fontSize: 10.5, color: _textoSuave),
          ),
        ),
      ],
    );
  }

  static String _compacto(int v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    }
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    return '$v';
  }
}

class _CaixaIndice extends StatelessWidget {
  const _CaixaIndice({
    required this.titulo,
    required this.valor,
    required this.detalhe,
    required this.claro,
  });
  final String titulo;
  final double valor;
  final String detalhe;
  final bool claro;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: claro ? const Color(0xFFEEF2F6) : _azulGelo,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: _textoSuave),
        ),
        const SizedBox(height: 4),
        _NumeroAnimado(
          valor: valor * 100,
          formatar: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}%',
          estilo: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: claro ? _texto : _azulEscuro,
          ),
        ),
        Text(
          detalhe,
          style: const TextStyle(fontSize: 10.5, color: _textoSuave),
        ),
      ],
    ),
  );
}

class _BlocoStatus extends StatelessWidget {
  const _BlocoStatus({
    required this.icone,
    required this.rotulo,
    required this.total,
    this.detalhe,
    this.destaque = false,
  });
  final IconData icone;
  final String rotulo;
  final int total;
  final String? detalhe;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _sombra,
      border: destaque
          ? const Border(bottom: BorderSide(color: _azulEscuro, width: 3))
          : null,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icone, color: destaque ? _azulEscuro : _azulNoite, size: 22),
        const SizedBox(height: 6),
        _NumeroAnimado(
          valor: total.toDouble(),
          formatar: (v) => '${v.round()}',
          estilo: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: _texto,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: destaque ? _azulEscuro : _textoSuave,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (detalhe != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              detalhe!,
              style: const TextStyle(fontSize: 9.5, color: _textoSuave),
            ),
          ),
      ],
    ),
  );
}

/// Rosca (pizza) com legenda ao lado; as fatias abrem girando.
class _LinhaRosca extends StatelessWidget {
  const _LinhaRosca({super.key, required this.fatias});
  final List<(String, double, Color)> fatias;

  @override
  Widget build(BuildContext context) {
    final total = fatias.fold<double>(0, (s, f) => s + f.$2);
    return Row(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: duracao(const Duration(milliseconds: 1000)),
            curve: Curves.easeOutCubic,
            builder: (_, p, _) => CustomPaint(
              painter: _PintorRosca(
                valores: [for (final f in fatias) f.$2],
                cores: [for (final f in fatias) f.$3],
                progresso: p,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in fatias)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: f.$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${f.$1}\n${total == 0 ? 0 : (f.$2 / total * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _texto,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PintorRosca extends CustomPainter {
  _PintorRosca({
    required this.valores,
    required this.cores,
    required this.progresso,
  });
  final List<double> valores;
  final List<Color> cores;
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 9.0;
    final rect = Offset.zero & size;
    final arco = rect.deflate(espessura / 2);
    final fundo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..color = const Color(0xFFE9EEF3);
    canvas.drawArc(arco, 0, math.pi * 2, false, fundo);
    final total = valores.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return;
    var inicio = -math.pi / 2;
    final volta = math.pi * 2 * progresso;
    for (var i = 0; i < valores.length; i++) {
      final ang = valores[i] / total * volta;
      if (ang <= 0) continue;
      canvas.drawArc(
        arco,
        inicio,
        ang,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = espessura
          ..strokeCap = StrokeCap.butt
          ..color = cores[i],
      );
      inicio += ang;
    }
  }

  @override
  bool shouldRepaint(_PintorRosca old) =>
      old.progresso != progresso || old.valores != valores;
}

/// Gráfico de barras animado. Com 2 contas, as barras ficam lado a lado
/// (cores de cada conta). Com 1 conta, o tom acompanha o valor (como no
/// design). Toque numa barra para ver o valor; a maior já vem marcada.
class _GraficoBarras extends StatefulWidget {
  const _GraficoBarras({
    super.key,
    required this.serie,
    required this.formatar,
    this.altura = 160,
    this.vazio = 'Sem dados',
  });

  final SerieBarras serie;
  final String Function(double) formatar;
  final double altura;
  final String vazio;

  @override
  State<_GraficoBarras> createState() => _GraficoBarrasState();
}

class _GraficoBarrasState extends State<_GraficoBarras> {
  int? _selecionado;

  int _indiceMaior() {
    var idx = 0;
    var maior = -1.0;
    final n = widget.serie.rotulos.length;
    for (var i = 0; i < n; i++) {
      var soma = 0.0;
      for (final l in widget.serie.valores.values) {
        if (i < l.length) soma += l[i];
      }
      if (soma > maior) {
        maior = soma;
        idx = i;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final serie = widget.serie;
    final maximo = serie.maximo;
    final contas = serie.valores.keys.toList();
    final varias = contas.length > 1;
    final n = serie.rotulos.length;
    final sel = maximo == 0 ? null : (_selecionado ?? _indiceMaior());
    const topo = 22.0;
    final util = widget.altura - topo;

    return Column(
      children: [
        SizedBox(
          height: widget.altura,
          child: Stack(
            children: [
              Positioned.fill(
                top: topo,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(height: 1, color: const Color(0xFFF1F4F8)),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selecionado = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: topo,
                              child: sel == i
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        varias
                                            ? contas
                                                  .map(
                                                    (c) => widget.formatar(
                                                      serie.valores[c]![i],
                                                    ),
                                                  )
                                                  .join(' | ')
                                            : widget.formatar(
                                                serie.valores[contas.first]![i],
                                              ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _azulNoite,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(
                              height: util,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final c in contas)
                                    Flexible(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: varias ? 1.5 : (n > 8 ? 3 : 5),
                                        ),
                                        child: _Barra(
                                          fracao: maximo == 0
                                              ? 0
                                              : serie.valores[c]![i] / maximo,
                                          alturaMax: util,
                                          cor: varias
                                              ? _corConta(c).withValues(
                                                  alpha: sel == i ? 1 : 0.75,
                                                )
                                              : _tom(
                                                  maximo == 0
                                                      ? 0
                                                      : serie.valores[c]![i] / maximo,
                                                  sel == i,
                                                ),
                                          atraso: i,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (maximo == 0)
                Positioned.fill(
                  top: topo,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.vazio,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textoSuave,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: _linha),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Text(
                  serie.rotulos[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: n > 8 ? 9 : 11,
                    fontWeight: sel == i ? FontWeight.w800 : FontWeight.w500,
                    color: sel == i ? _azulNoite : _textoSuave,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _tom(double f, bool selecionado) {
    if (selecionado) return _azulNoite;
    return Color.lerp(const Color(0xFFD3DCE6), _azulMedio, f.clamp(0, 1))!;
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.fracao,
    required this.alturaMax,
    required this.cor,
    required this.atraso,
  });
  final double fracao;
  final double alturaMax;
  final Color cor;
  final int atraso;

  @override
  Widget build(BuildContext context) {
    final alvo = math.max(fracao.clamp(0.0, 1.0) * alturaMax, 3.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: alvo),
      duration: duracao(Duration(milliseconds: 650 + atraso * 60)),
      curve: Curves.easeOutCubic,
      builder: (_, h, _) => AnimatedContainer(
        duration: duracao(const Duration(milliseconds: 200)),
        height: h,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ),
    );
  }
}
