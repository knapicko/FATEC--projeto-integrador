import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'meus_pedidos.dart';
import 'services/home_cliente_service.dart';
import 'services/solicitacao_geografica_service.dart';
import 'solicitacao_geografica_cliente.dart';
import 'tela_busca.dart';
import 'tela_mensagens.dart';
import 'tela_meu_perfil_cliente.dart';
import 'tela_servico.dart';
import 'todos_profissionais.dart';
import 'todos_servicos.dart';
import 'utils/abrir_solicitacao.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/avisos_bottom_sheet.dart';
import 'widgets/card_profissional_vitrine.dart';
import 'widgets/card_servico_popular.dart';
import 'widgets/contador_notificacoes.dart';
import 'widgets/filtros_busca.dart';
import 'widgets/seletor_endereco_cliente.dart';
import 'widgets/skeleton_loading.dart';
import 'widgets/permissoes_iniciais.dart';
import 'main.dart' show navigatorKey;
import 'services/avaliacoes_pendentes.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_visto.dart';
import 'tutorial/ilustracoes.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';

/// Home do cliente (e do visitante).
class TelaHome extends StatefulWidget {
  final bool isVisitante;

  const TelaHome({super.key, required this.isVisitante});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  static const _azul = Color(0xFF0FB3FF);
  static const _fundo = Color(0xFFF3F6FA);
  static const _texto = Color(0xFF0F172A);
  static const _sec = Color(0xFF64748B);

  ({String nome, String? foto})? _eu;
  List<PedidoAndamento>? _pedidos;
  List<OficioInfo>? _categorias;
  bool _todasCategorias = false;
  List<ProfissionalVitrine>? _regiao;
  List<ServicoAvaliado>? _servicos;
  EnderecoCliente? _endereco;

  // Tutorial (primeiro acesso): partes destacadas da tela.
  final _rolagem = ScrollController();
  final _kCabecalho = GlobalKey();
  final _kEndereco = GlobalKey();
  final _kBusca = GlobalKey();
  final _kCategorias = GlobalKey();
  final _kVerTodasCategorias = GlobalKey();
  final _kRegiao = GlobalKey();
  final _kVerTodosRegiao = GlobalKey();
  final _kPrimeiroProfissional = GlobalKey();
  final _kServicos = GlobalKey();
  final _kVerCatalogo = GlobalKey();
  final _kBarra = GlobalKey();
  final _kAjuda = GlobalKey();

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SessaoVisitante.ativo = widget.isVisitante;
    _carregarTudo();
    if (!widget.isVisitante) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await PermissoesIniciais.pedirSePrimeiraVez(context);
        // Primeiro acesso: tutorial da home.
        await _tutorial();
        // Pedidos concluídos sem avaliação: pede agora e sempre que um
        // pedido for concluído (em qualquer tela).
        AvaliacoesPendentes.iniciar(navigatorKey);
      });
    }
  }

  /// Apresentação da home (uma vez por conta).
  Future<void> _tutorial() async {
    if (widget.isVisitante) return;
    if (!await TutorialVisto.esperarSessao(() => mounted)) return;
    if (await TutorialVisto.jaViu('home_cliente')) return;
    // Espera as seções carregarem um pouco (para medir os destaques).
    for (var i = 0; i < 20 && (_regiao == null || _servicos == null); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    await Tutorial.mostrar(
      context,
      pularParaFinal: true,
      chave: 'home_cliente',
      passos: _passosHome(),
    );
  }

  /// Balões da home: a apresentação do primeiro acesso ou (sem
  /// [apresentacao]) a explicação do botão "?".
  List<PassoTutorial> _passosHome({bool apresentacao = true}) {
    Rect? Function() aba(int i) =>
        Tutorial.itemBarra(_kBarra, indice: i, total: 5);
    final temProfissional = _regiao?.isNotEmpty == true;
    return [
      if (apresentacao) ...[
        const PassoTutorial('Que bom te ver de novo por aqui!'),
        const PassoTutorial(
          'Vou te mostrar a tela principal e as partes mais importantes do '
          'app.',
        ),
        const PassoTutorial(
          'Se quiser, toque em "Pular", no canto de baixo, a qualquer '
          'momento.',
        ),
      ],
      PassoTutorial(
        'Este é o seu cabeçalho: sua foto, o endereço, a busca e as '
        'notificações.',
        alvo: _kCabecalho,
        rolagem: _rolagem,
        alinhamentoRolagem: 0,
      ),
      PassoTutorial(
        'Aqui fica o seu endereço. Ele é necessário para pedir serviços, e '
        'você pode trocar quando quiser.',
        alvo: _kEndereco,
        raio: 12,
      ),
      PassoTutorial(
        'Na busca você encontra profissionais e serviços, não só os da sua '
        'região.',
        alvo: _kBusca,
      ),
      PassoTutorial(
        'Estas são as categorias populares: um atalho para buscar já '
        'filtrando pela categoria.',
        alvo: _kCategorias,
        rolagem: _rolagem,
        alinhamentoRolagem: 0.15,
      ),
      PassoTutorial(
        'Se você quiser ver todas as categorias, é só tocar em "Ver '
        'todas".',
        alvo: _kVerTodasCategorias,
        raio: 10,
      ),
      PassoTutorial(
        'Aqui aparecem os profissionais que estão a até 5 km de você.',
        alvo: _kRegiao,
        rolagem: _rolagem,
        alinhamentoRolagem: 0.12,
      ),
      PassoTutorial(
        'Se quiser ver todos os profissionais cadastrados, toque em "Ver '
        'todos".',
        alvo: _kVerTodosRegiao,
        raio: 10,
      ),
      if (temProfissional)
        PassoTutorial(
          'E tocando em um profissional, você abre o perfil dele.',
          alvo: _kPrimeiroProfissional,
          raio: 24,
        ),
      PassoTutorial(
        'Estes são os serviços populares: os mais bem avaliados pelos '
        'clientes.',
        alvo: _kServicos,
        rolagem: _rolagem,
        alinhamentoRolagem: 0.1,
      ),
      PassoTutorial(
        'Se você quiser ver o catálogo completo de serviços, toque em "Ver '
        'catálogo".',
        alvo: _kVerCatalogo,
        raio: 10,
      ),
      PassoTutorial(
        'Este é o Radar! Você descreve o que precisa e o seu pedido vai '
        'para o mapa.',
        alvoRect: aba(1),
        folga: 2,
        raio: 14,
        ilustracao: const IlustracaoRadar(),
      ),
      PassoTutorial(
        'Os profissionais perto de você veem o pedido e mandam propostas. '
        'Aí é só escolher a melhor!',
        alvoRect: aba(1),
        folga: 2,
        raio: 14,
        ilustracao: const IlustracaoRadar(),
      ),
      PassoTutorial(
        'Em Mensagens ficam as suas conversas com os profissionais.',
        alvoRect: aba(2),
        folga: 2,
        raio: 14,
      ),
      PassoTutorial(
        'Em Pedidos você acompanha tudo o que pediu, do começo ao fim.',
        alvoRect: aba(3),
        folga: 2,
        raio: 14,
      ),
      PassoTutorial(
        'No Perfil ficam os seus dados, endereços e configurações.',
        alvoRect: aba(4),
        folga: 2,
        raio: 14,
      ),
      PassoTutorial(
        'Quando aparecer um ! amarelo, é algo que ainda falta preencher.',
        alvoRect: aba(4),
        folga: 2,
        raio: 14,
      ),
      PassoTutorial(
        'Esses dados são necessários para você fazer o seu primeiro '
        'pedido. Depois é só aproveitar!',
        alvoRect: aba(4),
        folga: 2,
        raio: 14,
      ),
      if (apresentacao)
        PassoTutorial(
          kFalaFinalTutorial,
          ehFinal: true,
          alvo: _kAjuda,
          raio: 23,
          folga: 2,
          apontar: true,
          antes: () async {
            if (_rolagem.hasClients) {
              await _rolagem.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              );
            }
          },
        ),
    ];
  }

  Future<void> _carregarTudo() async {
    if (!widget.isVisitante) {
      HomeClienteService.meusDados().then((d) {
        if (mounted) setState(() => _eu = d);
      });
      HomeClienteService.pedidosEmAndamento().then((p) {
        if (mounted) setState(() => _pedidos = p);
      });
    } else {
      _pedidos = const [];
    }
    // Todas as funções (tabela funcoes) com a cor do ofício.
    carregarFuncoesFiltro().then((c) {
      if (mounted) setState(() => _categorias = c);
    });
    HomeClienteService.servicosPorAvaliacao().then((s) {
      if (mounted) setState(() => _servicos = s);
    });
    await _carregarRegiao();
  }

  Future<void> _carregarRegiao() async {
    LatLng? centro;
    if (!widget.isVisitante) {
      var lista = await EnderecosCliente.carregar();
      var escolhido = await EnderecosCliente.escolhido(lista);
      // Endereço salvo sem latitude/longitude: geocodifica e grava antes de
      // buscar (senão a busca usava o GPS, que pode estar longe dali).
      if (escolhido != null &&
          (escolhido.latitude == null || escolhido.longitude == null)) {
        await SolicitacaoGeograficaService.garantirCoordenadas([escolhido.id]);
        lista = await EnderecosCliente.carregar();
        escolhido = await EnderecosCliente.escolhido(lista);
      }
      if (mounted) setState(() => _endereco = escolhido);
      if (escolhido?.latitude != null && escolhido?.longitude != null) {
        centro = LatLng(escolhido!.latitude!, escolhido.longitude!);
      }
    }
    centro ??= await SolicitacaoGeograficaService.localizacaoAtual();
    final regiao = await HomeClienteService.profissionaisNaRegiao(centro);
    if (mounted) setState(() => _regiao = regiao);
  }

  Future<void> _recarregar() async {
    setState(() {
      _pedidos = widget.isVisitante ? const [] : null;
      _regiao = null;
    });
    await _carregarTudo();
  }

  /// Ação que exige conta: visitante vê o convite para entrar.
  bool _permitido() {
    if (!widget.isVisitante) return true;
    mostrarAvisoVisitante(context);
    return false;
  }

  void _abrir(Widget pagina) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));

  void _abrirBusca({FiltrosBusca? filtros}) {
    _abrir(
      TelaBusca(isVisitante: widget.isVisitante, filtrosIniciais: filtros),
    );
  }

  Future<void> _abrirFiltros() async {
    final filtros = await mostrarFiltrosBusca(
      context,
      atuais: const FiltrosBusca(),
    );
    if (filtros != null && mounted) _abrirBusca(filtros: filtros);
  }

  String get _primeiroNome {
    final nome = _eu?.nome.trim() ?? '';
    return nome.isEmpty ? 'Visitante' : nome.split(' ').first;
  }

  String get _bairro {
    final b = _endereco?.bairroCidade.split(',').first.trim() ?? '';
    return b.isEmpty ? 'sua região' : b;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pedidos = _pedidos;
    return AppBackHandler(
      isHome: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _fundo,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _azul,
              onRefresh: _recarregar,
              child: ListView(
                controller: _rolagem,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _cabecalho(),
                  if (widget.isVisitante) _cardVisitante(),
                  if (pedidos == null)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: SkeletonBox(height: 170, borderRadius: 22),
                    )
                  else if (pedidos.isNotEmpty)
                    _pedidosEmAndamento(pedidos),
                  _secaoCategorias(),
                  _secaoRegiao(),
                  _secaoServicos(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: BottomNavigationBarCliente(
            key: _kBarra,
            currentIndex: 0,
            onReselecionarAbaAtual: (_) => _recarregar(),
            onTap: (index) {
              if (index == 0) return;
              if (!_permitido()) return;
              final destino = switch (index) {
                1 => const SolicitacaoGeograficaClientePage(),
                2 => const TelaMensagensPage(isVisitante: false),
                3 => const MeusPedidosPage(),
                _ => const TelaMeuPerfilClientePage(),
              };
              AppNavigationUtil.navegarAba(context, destino, isHome: false);
            },
          ),
        ),
      ),
    );
  }

  // ── Cabeçalho ────────────────────────────────────────────────────────────

  Widget _cabecalho() {
    final foto = _eu?.foto;
    return Padding(
      key: _kCabecalho,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_permitido()) _abrir(const TelaMeuPerfilClientePage());
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CorOriginal(child: CircleAvatar(
                        radius: 26,
                        backgroundColor: _azul,
                        backgroundImage: foto != null
                            ? NetworkImage(foto)
                            : null,
                        child: foto == null
                            ? widget.isVisitante
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      obterIniciais(_eu?.nome ?? ''),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                            : null,
                      )),
                    ),
                    if (!widget.isVisitante)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, $_primeiroNome',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SeletorEnderecoCliente(
                      key: _kEndereco,
                      cor: _texto,
                      corIcone: const Color(0xFF0EA5E9),
                      corTrocar: _azul,
                      aoMudar: (e) {
                        setState(() {
                          _endereco = e;
                          _regiao = null;
                        });
                        _carregarRegiao();
                      },
                      aoTocarSemPermissao: widget.isVisitante
                          ? () => mostrarAvisoVisitante(context)
                          : null,
                    ),
                  ],
                ),
              ),
              BotaoAjuda(
                key: _kAjuda,
                fundo: const Color(0xFFE8EDF3),
                cor: _texto,
                passos: () => _passosHome(apresentacao: false),
              ),
              const SizedBox(width: 8),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SinoNotificacoes(
                    cor: _texto,
                    tamanho: 24,
                    aoTocar: widget.isVisitante
                        ? () => mostrarAvisoVisitante(context)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            key: _kBusca,
            children: [
              Expanded(
                child: Material(
                  color: const Color(0xFFE8EDF3),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _abrirBusca(),
                    child: const SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          SizedBox(width: 14),
                          Icon(Icons.search_rounded, color: _sec),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pesquisar...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _sec, fontSize: 14.5),
                            ),
                          ),
                          Icon(Icons.mic_none_rounded, color: _sec),
                          SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CorOriginal(interface: true, child: Material(
                color: _azul,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _abrirFiltros,
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardVisitante() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: CorOriginal(interface: true, child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _azul,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você está como visitante',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Entre para pedir serviços, conversar e acompanhar seus '
                    'pedidos.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => mostrarAvisoVisitante(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _azul,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Acessar agora',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      )),
    );
  }

  // ── Pedido em andamento ──────────────────────────────────────────────────

  Widget _pedidosEmAndamento(List<PedidoAndamento> pedidos) {
    if (pedidos.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: _cardPedido(pedidos.first),
      );
    }
    final largura = MediaQuery.sizeOf(context).width - 56;
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        itemCount: pedidos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) =>
            SizedBox(width: largura, child: _cardPedido(pedidos[i])),
      ),
    );
  }

  Widget _cardPedido(PedidoAndamento p) {
    void abrir() => abrirSolicitacaoPorStatus(
      context,
      p.id,
      comoProfissional: false,
    ).then((_) => _recarregar());
    final local = [p.status, if ((p.rua ?? '').isNotEmpty) p.rua!].join(' • ');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: abrir,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BordaGradienteAnimada(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CorOriginal(interface: true, child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: _azul,
                            shape: BoxShape.circle,
                          ),
                        )),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'PEDIDO EM ANDAMENTO',
                            style: TextStyle(
                              color: Color(0xFF0369A1),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Text(
                              p.status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: p.foto != null
                                ? ImagemApp(child: Image.network(
                                    p.foto!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _iniciais(p.nomePrestador),
                                  ))
                                : _iniciais(p.nomePrestador),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _texto,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: p.nomePrestador,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if ((p.funcao ?? '').isNotEmpty)
                                      TextSpan(text: ' • ${p.funcao}'),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _sec,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEDEFF2)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.navigation_outlined,
                          color: Color(0xFF1E6FB8),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            local,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _sec, fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CorOriginal(interface: true, child: FilledButton(
                          onPressed: abrir,
                          style: FilledButton.styleFrom(
                            backgroundColor: _azul,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text(
                            'Acompanhar →',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iniciais(String nome) => CorOriginal(interface: true, child: Container(
    color: _azul,
    alignment: Alignment.center,
    child: Text(
      obterIniciais(nome),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),
  ));

  // ── Seções ───────────────────────────────────────────────────────────────

  Widget _tituloSecao(
    String titulo,
    String subtitulo, {
    String? acao,
    VoidCallback? aoTocar,
    Key? chaveAcao,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(color: _sec, fontSize: 13.5),
                ),
              ],
            ),
          ),
          if (acao != null)
            InkWell(
              key: chaveAcao,
              onTap: aoTocar,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Text(
                  acao,
                  style: const TextStyle(
                    color: _azul,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _secaoCategorias() {
    final cats = _categorias;
    // 7 funções + "Mais" (mostra todas); com todas abertas, "Menos".
    final visiveis = cats == null
        ? const <OficioInfo>[]
        : (_todasCategorias ? cats : cats.take(7).toList());
    return Column(
      key: _kCategorias,
      children: [
        _tituloSecao(
          'Categorias Populares',
          'Técnicos e serviços por especialidade',
          chaveAcao: _kVerTodasCategorias,
          // Abertas: "Ver menos" recolhe de volta.
          acao: _todasCategorias ? 'Ver menos ‹' : 'Ver todas ›',
          aoTocar: () => setState(() => _todasCategorias = !_todasCategorias),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedSize(
            duration: duracao(const Duration(milliseconds: 280)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.86,
              children: cats == null
                  ? List.generate(
                      8,
                      (_) => const SkeletonBox(
                        height: double.infinity,
                        borderRadius: 18,
                      ),
                    )
                  : [
                      for (final f in visiveis) _tileFuncao(f),
                      if (cats.length > 7)
                        _tileCategoria(
                          _todasCategorias ? 'Menos' : 'Mais',
                          Icon(
                            _todasCategorias
                                ? Icons.expand_less_rounded
                                : Icons.grid_view_rounded,
                            color: const Color(0xFF64748B),
                            size: 24,
                          ),
                          const Color(0xFF64748B),
                          () => setState(
                            () => _todasCategorias = !_todasCategorias,
                          ),
                          tracejado: true,
                        ),
                    ],
            ),
          ),
        ),
      ],
    );
  }

  /// Função com o ícone (icone_oficio.dart) pintado na cor do ofício
  /// (cor_oficio.dart). Toque: busca já filtrada por essa função.
  Widget _tileFuncao(OficioInfo f) {
    final cor = CorOficio.parse(f.cor);
    return _tileCategoria(
      f.funcao,
      ColorFiltered(
        colorFilter: ColorFilter.mode(CorOficio.corTexto(cor), BlendMode.srcIn),
        child: IconeOficio.imagemPorFuncao(f.funcao, tamanho: 26),
      ),
      cor,
      () => _abrirBusca(filtros: FiltrosBusca(funcoes: {f.funcao})),
    );
  }

  Widget _tileCategoria(
    String nome,
    Widget icone,
    Color cor,
    VoidCallback aoTocar, {
    bool tracejado = false,
  }) {
    final conteudo = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: icone,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    return Material(
      color: tracejado ? Colors.transparent : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: aoTocar,
        child: tracejado
            ? CustomPaint(
                painter: const _BordaTracejada(),
                child: SizedBox.expand(child: conteudo),
              )
            : conteudo,
      ),
    );
  }

  Widget _secaoRegiao() {
    final lista = _regiao;
    return Column(
      key: _kRegiao,
      children: [
        _tituloSecao(
          'Profissionais na sua Região',
          'Prontos para atender ${_bairro == 'sua região' ? 'na sua região' : 'na $_bairro'} e arredores',
          acao: 'Ver todos',
          chaveAcao: _kVerTodosRegiao,
          aoTocar: () => _abrir(const TodosProfissionaisPage()),
        ),
        if (lista != null && lista.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_searching_rounded,
                      color: _azul,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum profissional a até 5 km',
                    style: TextStyle(
                      color: _texto,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ainda não há profissionais num raio de 5 km de '
                    '${_bairro == 'sua região' ? 'onde você está' : _bairro}. '
                    'Veja todos os profissionais cadastrados.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _sec, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _abrir(const TodosProfissionaisPage()),
                    child: const Text('Ver todos os profissionais'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 236,
            child: lista == null
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 2,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, _) => const SkeletonBox(
                      width: 300,
                      height: 236,
                      borderRadius: 22,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => KeyedSubtree(
                      key: i == 0 ? _kPrimeiroProfissional : null,
                      child: CardProfissionalVitrine(p: lista[i]),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _secaoServicos() {
    final lista = _servicos;
    return Column(
      key: _kServicos,
      children: [
        _tituloSecao(
          'Serviços Populares',
          'Preços transparentes com garantia de 90 dias',
          chaveAcao: _kVerCatalogo,
          acao: 'Ver catálogo',
          aoTocar: () => _abrir(const TodosServicosPage()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: lista == null
              ? const Column(
                  children: [
                    SkeletonBox(height: 280, borderRadius: 22),
                    SizedBox(height: 18),
                    SkeletonBox(height: 280, borderRadius: 22),
                  ],
                )
              : lista.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhum serviço disponível ainda.',
                    style: TextStyle(color: _sec),
                  ),
                )
              : Column(
                  children: [
                    for (final item in lista.take(3))
                      CardServicoPopular(
                        item: item,
                        aoTocar: () =>
                            _abrir(TelaServico(idServico: item.servico.id)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => _abrir(const TodosServicosPage()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _azul,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: _azul, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Ver todos os serviços (${lista.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Faixa colorida no topo do card de pedido, com o degradê andando
/// (efeito "animated gradient border").
class _BordaGradienteAnimada extends StatefulWidget {
  const _BordaGradienteAnimada();

  @override
  State<_BordaGradienteAnimada> createState() => _BordaGradienteAnimadaState();
}

class _BordaGradienteAnimadaState extends State<_BordaGradienteAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 2600)),
  )..repetir();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: 5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // Azul principal, branco e cinza claro.
            colors: const [
              Color(0xFF0FB3FF),
              Color(0xFFFFFFFF),
              Color(0xFFE2E8F0),
              Color(0xFF0FB3FF),
            ],
            tileMode: TileMode.repeated,
            transform: _Deslizar(_c.value),
          ),
        ),
      ),
    );
  }
}

class _Deslizar extends GradientTransform {
  const _Deslizar(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * t, 0, 0);
}

/// Borda tracejada do tile "Mais".
class _BordaTracejada extends CustomPainter {
  const _BordaTracejada();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final caminho = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      );
    for (final m in caminho.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
