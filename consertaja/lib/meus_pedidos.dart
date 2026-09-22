import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seguindo_cliente.dart';
import 'tela_chat_profissional.dart';
import 'tela_home.dart';
import 'tela_mensagens.dart';
import 'tela_meu_perfil_cliente.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';

class PedidoCliente {
  final int id;
  final String status;
  final String titulo;
  final String prestador;
  final double valor;
  final String? dataAg;
  final String? horaAg;
  final String? img;
  final String? funcao;
  final String? corOficio;
  final String? fotoPrest;
  final String? tagEmp;
  final String? corTag;
  final int? idProf;
  final int? idGrupo;
  const PedidoCliente({
    required this.id,
    required this.status,
    required this.titulo,
    required this.prestador,
    required this.valor,
    this.dataAg,
    this.horaAg,
    this.img,
    this.funcao,
    this.corOficio,
    this.fotoPrest,
    this.tagEmp,
    this.corTag,
    this.idProf,
    this.idGrupo,
  });
}

enum FiltroPedido { todos, emAberto, emAndamento, concluidos }

class MeusPedidosPage extends StatefulWidget {
  final bool isVisitante;
  const MeusPedidosPage({super.key, this.isVisitante = false});
  @override
  State<MeusPedidosPage> createState() => MeusPedidosState();
}

class MeusPedidosState extends State<MeusPedidosPage> {
  static const Color azul = Color(0xFF0FB3FF);
  static const Color fundo = Color(0xFFF6F8FB);
  static const Color escuro = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color badgeRed = Color(0xFFBA1A1A);
  final SupabaseClient db = Supabase.instance.client;
  final TextEditingController buscaCtrl = TextEditingController();
  bool carregando = true;
  String? erro;
  String termo = '';
  bool buscaAtiva = false;
  String nomeCli = 'Nome não encontrado';
  String? fotoCli;
  List<PedidoCliente> todos = [];
  FiltroPedido filtro = FiltroPedido.todos;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  @override
  void dispose() {
    buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> carregar({bool loading = true}) async {
    if (loading && mounted)
      setState(() {
        carregando = true;
        erro = null;
      });
    try {
      if (widget.isVisitante) {
        if (mounted) setState(() => carregando = false);
        return;
      }
      final auth = db.auth.currentUser;
      if (auth == null) {
        if (mounted) setState(() => carregando = false);
        return;
      }
      final uRow = await db
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .eq('auth_id', auth.id)
          .maybeSingle();
      final idU = (uRow?['id_usuario'] as num?)?.toInt();
      if (idU == null) {
        if (mounted) setState(() => carregando = false);
        return;
      }
      final nm = uRow?['nome']?.toString().trim() ?? '';
      nomeCli = nm.isNotEmpty ? nm : 'Nome não encontrado';
      fotoCli = uRow?['foto_perfil_url']?.toString();
      final lista = await buscarPedidos(idU);
      if (!mounted) return;
      setState(() {
        todos = lista;
        carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        erro = 'Não foi possível carregar seus pedidos.';
        carregando = false;
      });
    }
  }

  Future<List<PedidoCliente>> buscarPedidos(int idUsuario) async {
    final linhas = await db
        .from('solicitacoes')
        .select(
          'id_solicitacao, data_agendada, hora_agendada, valor_final, fk_profissional, fk_grupo_empresa, fk_servico_prof, fk_status',
        )
        .eq('fk_usuario', idUsuario)
        .order('data_solicitacao', ascending: false);
    if (linhas.isEmpty) return [];
    final idsStatus = <int>{};
    final idsServ = <int>{};
    for (final r in linhas) {
      final a = (r['fk_status'] as num?)?.toInt();
      final b = (r['fk_servico_prof'] as num?)?.toInt();
      if (a != null) idsStatus.add(a);
      if (b != null) idsServ.add(b);
    }
    final Map<int, String> statusMap = {};
    if (idsStatus.isNotEmpty) {
      final sRows = await db
          .from('status')
          .select('id_status, status')
          .inFilter('id_status', idsStatus.toList());
      for (final s in sRows) {
        final id = (s['id_status'] as num?)?.toInt();
        if (id != null) statusMap[id] = (s['status'] ?? '').toString();
      }
    }
    final Map<int, Map<String, dynamic>> servMap = {};
    if (idsServ.isNotEmpty) {
      final vRows = await db
          .from('servicos_profissional')
          .select(
            'id_servico_prof, titulo, valor, imagem_url, fk_profissional, fk_grupo_empresa, fk_oficios',
          )
          .inFilter('id_servico_prof', idsServ.toList());
      for (final v in vRows) {
        final id = (v['id_servico_prof'] as num?)?.toInt();
        if (id != null) servMap[id] = Map<String, dynamic>.from(v);
      }
    }
    final aux = await carregarAuxiliar(servMap, linhas);
    return montarLista(linhas, statusMap, servMap, aux);
  }

  Future<Map<String, dynamic>> carregarAuxiliar(
    Map<int, Map<String, dynamic>> servMap,
    List<dynamic> linhas,
  ) async {
    final idsOf = <int>{};
    final idsGrupo = <int>{};
    final idsProf = <int>{};
    for (final r in linhas) {
      final idS = (r['fk_servico_prof'] as num?)?.toInt();
      final sv = idS == null ? null : servMap[idS];
      final idOf = (sv?['fk_oficios'] as num?)?.toInt();
      if (idOf != null) idsOf.add(idOf);
      final g = (r['fk_grupo_empresa'] as num?)?.toInt();
      final p = (r['fk_profissional'] as num?)?.toInt();
      if (g != null) idsGrupo.add(g);
      if (p != null) idsProf.add(p);
      final gs = (sv?['fk_grupo_empresa'] as num?)?.toInt();
      final ps = (sv?['fk_profissional'] as num?)?.toInt();
      if (gs != null) idsGrupo.add(gs);
      if (ps != null) idsProf.add(ps);
    }
    final Map<int, String> funcMap = {};
    final Map<int, String> corMap = {};
    if (idsOf.isNotEmpty) {
      final oRows = await db
          .from('oficios')
          .select('id_oficio, funcao, cod_cor')
          .inFilter('id_oficio', idsOf.toList());
      for (final o in oRows) {
        final id = (o['id_oficio'] as num?)?.toInt();
        if (id == null) continue;
        funcMap[id] = (o['funcao'] ?? '').toString();
        corMap[id] = (o['cod_cor'] ?? '').toString();
      }
    }
    final Map<int, Map<String, dynamic>> grupos = {};
    if (idsGrupo.isNotEmpty) {
      final gRows = await db
          .from('grupo_empresa')
          .select(
            'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa',
          )
          .inFilter('id_grupo_empresa', idsGrupo.toList());
      for (final g in gRows) {
        final id = (g['id_grupo_empresa'] as num?)?.toInt();
        if (id != null) grupos[id] = Map<String, dynamic>.from(g);
      }
    }
    final Map<int, int> userPorProf = {};
    final Map<int, int> grupoPorProf = {};
    if (idsProf.isNotEmpty) {
      final dRows = await db
          .from('dados_profissionais')
          .select('id_profissional, fk_usuario, fk_grupo_empresa')
          .inFilter('id_profissional', idsProf.toList());
      for (final d in dRows) {
        final id = (d['id_profissional'] as num?)?.toInt();
        if (id == null) continue;
        final iu = (d['fk_usuario'] as num?)?.toInt();
        if (iu != null) userPorProf[id] = iu;
        final gg = (d['fk_grupo_empresa'] as num?)?.toInt();
        if (gg != null) {
          grupoPorProf[id] = gg;
          idsGrupo.add(gg);
        }
      }
    }
    final extras = idsGrupo.where((e) => !grupos.containsKey(e)).toList();
    if (extras.isNotEmpty) {
      final g2 = await db
          .from('grupo_empresa')
          .select(
            'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa',
          )
          .inFilter('id_grupo_empresa', extras);
      for (final g in g2) {
        final id = (g['id_grupo_empresa'] as num?)?.toInt();
        if (id != null) grupos[id] = Map<String, dynamic>.from(g);
      }
    }
    final Map<int, Map<String, dynamic>> usersProf = {};
    if (userPorProf.values.isNotEmpty) {
      final uRows = await db
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .inFilter('id_usuario', userPorProf.values.toSet().toList());
      for (final u in uRows) {
        final id = (u['id_usuario'] as num?)?.toInt();
        if (id != null) usersProf[id] = Map<String, dynamic>.from(u);
      }
    }
    return {
      'func': funcMap,
      'cor': corMap,
      'grupos': grupos,
      'userPorProf': userPorProf,
      'grupoPorProf': grupoPorProf,
      'usersProf': usersProf,
    };
  }

  List<PedidoCliente> montarLista(
    List<dynamic> linhas,
    Map<int, String> statusMap,
    Map<int, Map<String, dynamic>> servMap,
    Map<String, dynamic> aux,
  ) {
    final funcMap = Map<int, String>.from(aux['func'] as Map);
    final corMap = Map<int, String>.from(aux['cor'] as Map);
    final grupos = Map<int, Map<String, dynamic>>.from(aux['grupos'] as Map);
    final userPorProf = Map<int, int>.from(aux['userPorProf'] as Map);
    final grupoPorProf = Map<int, int>.from(aux['grupoPorProf'] as Map);
    final usersProf = Map<int, Map<String, dynamic>>.from(
      aux['usersProf'] as Map,
    );
    final out = <PedidoCliente>[];
    for (final r in linhas) {
      final idSol = (r['id_solicitacao'] as num?)?.toInt();
      if (idSol == null) continue;
      final idSt = (r['fk_status'] as num?)?.toInt();
      final st = idSt == null ? '' : (statusMap[idSt] ?? '');
      final idS = (r['fk_servico_prof'] as num?)?.toInt();
      final sv = idS == null ? null : servMap[idS];
      var titulo = (sv?['titulo'] ?? '').toString().trim();
      if (titulo.isEmpty) titulo = 'Serviço';
      final imgRaw = (sv?['imagem_url'] ?? '').toString().trim();
      final vServ = (sv?['valor'] as num?)?.toDouble();
      var func = '';
      String? corOf;
      final idOf = (sv?['fk_oficios'] as num?)?.toInt();
      if (idOf != null) {
        func = funcMap[idOf] ?? '';
        corOf = corMap[idOf];
      }
      final idG =
          (r['fk_grupo_empresa'] as num?)?.toInt() ??
          (sv?['fk_grupo_empresa'] as num?)?.toInt();
      final idP =
          (r['fk_profissional'] as num?)?.toInt() ??
          (sv?['fk_profissional'] as num?)?.toInt();
      var nomeP = 'Profissional';
      String? fotoP;
      String? tagE;
      String? corTag;
      if (idG != null && grupos.containsKey(idG)) {
        final g = grupos[idG]!;
        final nm = (g['nome_empresa'] ?? '').toString().trim();
        nomeP = nm.isNotEmpty ? nm : 'Empresa';
        final f = (g['foto_url_empresa'] ?? '').toString().trim();
        fotoP = f.isNotEmpty ? f : null;
        final tg = (g['tag_empresa'] ?? '').toString().trim();
        tagE = tg.isNotEmpty ? tg : null;
        corTag = (g['cor_tag_empresa'] ?? '').toString().trim();
      } else if (idP != null) {
        final iu = userPorProf[idP];
        final u = iu == null ? null : usersProf[iu];
        final nm = (u?['nome'] ?? '').toString().trim();
        nomeP = nm.isNotEmpty ? nm : 'Profissional';
        final f = (u?['foto_perfil_url'] ?? '').toString().trim();
        fotoP = f.isNotEmpty ? f : null;
        final ga = grupoPorProf[idP];
        if (ga != null && grupos.containsKey(ga)) {
          final g = grupos[ga]!;
          final tg = (g['tag_empresa'] ?? '').toString().trim();
          tagE = tg.isNotEmpty ? tg : null;
          corTag = (g['cor_tag_empresa'] ?? '').toString().trim();
        }
      }
      final vFinal =
          double.tryParse((r['valor_final'] ?? '').toString()) ?? vServ ?? 0;
      out.add(
        PedidoCliente(
          id: idSol,
          status: st,
          titulo: titulo,
          prestador: nomeP,
          valor: vFinal,
          dataAg: r['data_agendada']?.toString(),
          horaAg: r['hora_agendada']?.toString(),
          img: imgRaw.isNotEmpty ? imgRaw : null,
          funcao: func.isNotEmpty ? func : null,
          corOficio: corOf,
          fotoPrest: fotoP,
          tagEmp: tagE,
          corTag: corTag,
          idProf: idP,
          idGrupo: idG,
        ),
      );
    }
    return out;
  }

  bool ehAberto(String s) {
    final v = s.trim().toLowerCase();
    if (v.isEmpty) return true;
    if (v.contains('cancel')) return false;
    if (v.contains('recus')) return false;
    if (v.contains('conclu')) return false;
    if (v.contains('finaliz')) return false;
    if (v.contains('andamento')) return false;
    if (v.contains('execu')) return false;
    return true;
  }

  bool ehAndamento(String s) {
    final v = s.trim().toLowerCase();
    if (v.contains('cancel')) return false;
    if (v.contains('conclu')) return false;
    if (v.contains('recus')) return false;
    if (v.contains('finaliz')) return false;
    return v.contains('andamento') ||
        v.contains('execu') ||
        v.contains('aceito') ||
        v.contains('aprovado');
  }

  bool ehConcluido(String s) {
    final v = s.trim().toLowerCase();
    return v.contains('conclu') ||
        v.contains('finaliz') ||
        v.contains('cancel') ||
        v.contains('recus');
  }

  List<PedidoCliente> get listaFiltrada {
    var lista = todos;
    if (filtro == FiltroPedido.emAberto) {
      lista = lista.where((p) => ehAberto(p.status)).toList();
    }
    if (filtro == FiltroPedido.emAndamento) {
      lista = lista.where((p) => ehAndamento(p.status)).toList();
    }
    if (filtro == FiltroPedido.concluidos) {
      lista = lista.where((p) => ehConcluido(p.status)).toList();
    }
    final t = termo.trim().toLowerCase();
    if (t.isNotEmpty) {
      lista = lista
          .where(
            (p) =>
                p.titulo.toLowerCase().contains(t) ||
                p.prestador.toLowerCase().contains(t) ||
                p.status.toLowerCase().contains(t),
          )
          .toList();
    }
    return lista;
  }

  int get qtdAberto => todos.where((p) => ehAberto(p.status)).length;
  int get qtdAndamento => todos.where((p) => ehAndamento(p.status)).length;
  int get qtdConcl => todos.where((p) => ehConcluido(p.status)).length;

  String textoAgendado(PedidoCliente p) {
    final d = (p.dataAg ?? '').trim();
    var h = (p.horaAg ?? '').trim();
    if (d.isEmpty && h.isEmpty) return '';
    var dFmt = d;
    try {
      final dt = DateTime.parse(d);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      dFmt = '$dd/$mm/${dt.year}';
    } catch (_) {}
    if (h.length >= 5) h = h.substring(0, 5);
    if (dFmt.isNotEmpty && h.isNotEmpty) return '$dFmt - $h';
    return dFmt.isNotEmpty ? dFmt : h;
  }

  String rotuloValor(PedidoCliente p) {
    final s = p.status.trim().toLowerCase();
    if (s.contains('conclu') || s.contains('finaliz') || s == 'pago') {
      return 'Total pago';
    }
    if (s.contains('andamento') || s.contains('execu')) return 'Valor fechado';
    return 'Valor Total';
  }

  void irPara(int index) {
    if (index == 0) {
      AppNavigationUtil.navegarAba(
        context,
        TelaHome(isVisitante: widget.isVisitante),
        isHome: true,
      );
    } else if (index == 1) {
      AppNavigationUtil.navegarAba(
        context,
        SeguindoClientePage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    } else if (index == 2) {
      AppNavigationUtil.navegarAba(
        context,
        TelaMensagensPage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    } else if (index == 4) {
      AppNavigationUtil.navegarAba(
        context,
        TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    }
  }

  void abrirConversa(PedidoCliente p) {
    final ehEmp = p.idGrupo != null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: p.prestador,
          fotoProfissional: p.fotoPrest ?? '',
          oficioPrincipal: (p.funcao ?? '').isNotEmpty
              ? p.funcao!
              : 'Atendimento',
          idProfissional: ehEmp ? null : p.idProf,
          idGrupoEmpresa: ehEmp ? p.idGrupo : null,
        ),
      ),
    );
  }

  String fmtValor(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final ip = parts[0];
    final b = StringBuffer();
    for (var i = 0; i < ip.length; i++) {
      final pos = ip.length - i;
      b.write(ip[i]);
      if (pos > 1 && pos % 3 == 1) b.write('.');
    }
    return 'R\$ ${b.toString()},${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackHandler(
      child: Scaffold(
        backgroundColor: fundo,
        body: SafeArea(
          child: Column(
            children: [
              cabecalho(),
              if (buscaAtiva) campoBusca(),
              pills(),
              Expanded(child: corpo()),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBarCliente(
          currentIndex: 3,
          onReselecionarAbaAtual: (_) => carregar(loading: false),
          onTap: irPara,
        ),
      ),
    );
  }

  Widget corpo() {
    if (carregando) {
      return const Center(child: CircularProgressIndicator(color: azul));
    }
    if (erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 12),
            const Text('Erro ao carregar pedidos.'),
            TextButton(
              onPressed: () => carregar(),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: azul,
      onRefresh: () => carregar(loading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          visaoGeral(),
          const SizedBox(height: 12),
          for (final p in listaFiltrada) card(p),
          if (listaFiltrada.isEmpty) vazio(),
        ],
      ),
    );
  }

  Widget cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                AppNavigationUtil.tratarBotaoVoltar(context, isHome: false),
            icon: const Icon(Icons.arrow_back, color: azul, size: 26),
          ),
          const Text(
            'Pedidos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: azul,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() {
              buscaAtiva = !buscaAtiva;
              if (!buscaAtiva) {
                buscaCtrl.clear();
                termo = '';
              }
            }),
            icon: const Icon(Icons.search, color: azul, size: 24),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: azul,
                  size: 24,
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: badgeRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          avatarCli(),
        ],
      ),
    );
  }

  Widget avatarCli() {
    final f = (fotoCli ?? '').trim();
    if (f.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          f,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => avatarIni(),
        ),
      );
    }
    return avatarIni();
  }

  Widget avatarIni() {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: azul, shape: BoxShape.circle),
      child: Text(
        obterIniciais(nomeCli),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget campoBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: buscaCtrl,
        autofocus: true,
        onChanged: (v) => setState(() => termo = v),
        decoration: InputDecoration(
          hintText: 'Buscar por serviço ou prestador...',
          prefixIcon: const Icon(Icons.search, color: azul),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget pills() {
    final items = [
      (FiltroPedido.todos, 'Todos', todos.length),
      (FiltroPedido.emAberto, 'Em Aberto', qtdAberto),
      (FiltroPedido.emAndamento, 'Em Andamento', qtdAndamento),
      (FiltroPedido.concluidos, 'Concluído', qtdConcl),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final fl = items[i].$1;
          final rot = items[i].$2;
          final qtd = items[i].$3;
          final ativo = filtro == fl;
          return GestureDetector(
            onTap: () => setState(() => filtro = fl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: ativo ? azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ativo ? azul : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rot,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ativo ? Colors.white : escuro,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ativo
                          ? Colors.white.withValues(alpha: 0.3)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$qtd',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: ativo ? Colors.white : muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget visaoGeral() {
    final qtd = qtdAndamento;
    final txt = qtd == 0
        ? 'Você não tem atendimentos em atividade hoje'
        : qtd == 1
        ? 'Você tem 1 atendimento em atividade hoje'
        : 'Você tem $qtd atendimentos em atividade hoje';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: azul,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visão Geral dos Pedidos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: escuro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(txt, style: const TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget vazio() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6FD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: azul,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum pedido por aqui',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: escuro,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            termo.trim().isNotEmpty
                ? 'Nenhum pedido corresponde à sua busca.'
                : 'Quando você solicitar um serviço, ele aparecerá aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget card(PedidoCliente p) {
    final e = estiloStatus(p.status);
    final ag = textoAgendado(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: tagStatus(e)),
              if (ag.isNotEmpty)
                Text(ag, style: const TextStyle(fontSize: 11, color: muted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              imgServ(p),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: escuro,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: azul,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.prestador,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if ((p.tagEmp ?? '').trim().isNotEmpty)
                          miniTag(
                            '#${p.tagEmp!.trim()}',
                            CorOficio.parse(p.corTag),
                          ),
                        if ((p.funcao ?? '').isNotEmpty)
                          miniTag(p.funcao!, CorOficio.parse(p.corOficio)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotuloValor(p),
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      fmtValor(p.valor),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4F91),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => abrirConversa(p),
                icon: const Icon(Icons.chat_outlined, size: 15),
                label: const Text('Conversar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: escuro,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: azul,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Ver Detalhes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget tagStatus(StatusEstilo e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: e.fundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: e.borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(e.icone, size: 12, color: e.texto),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              e.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: e.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget miniTag(String txt, Color base) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CorOficio.corFundo(base),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: CorOficio.corTexto(base),
        ),
      ),
    );
  }

  Widget imgServ(PedidoCliente p) {
    final u = (p.img ?? '').trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: u.isNotEmpty
            ? Image.network(
                u,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => phServ(p),
              )
            : phServ(p),
      ),
    );
  }

  Widget phServ(PedidoCliente p) {
    return Container(
      color: CorOficio.parse(p.corOficio),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(p.titulo),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  StatusEstilo estiloStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('cancel')) {
      return const StatusEstilo(
        rotulo: 'Cancelado',
        fundo: Color(0xFFFEE2E2),
        texto: Color(0xFFB91C1C),
        borda: Color(0xFFFECACA),
        icone: Icons.cancel_outlined,
      );
    }
    if (s.contains('conclu') || s.contains('finaliz')) {
      return const StatusEstilo(
        rotulo: 'Concluído com sucesso',
        fundo: Color(0xFFF1F5F9),
        texto: Color(0xFF334155),
        borda: Color(0xFFE2E8F0),
        icone: Icons.check_circle_outline,
      );
    }
    if (s.contains('andamento') || s.contains('execu')) {
      return const StatusEstilo(
        rotulo: 'Em andamento',
        fundo: Color(0xFF0B3B5B),
        texto: Colors.white,
        borda: Color(0xFF0B3B5B),
        icone: Icons.autorenew,
      );
    }
    if (s.contains('aceito') || s.contains('aprovado')) {
      return const StatusEstilo(
        rotulo: 'Aceito',
        fundo: Color(0xFFDCFCE7),
        texto: Color(0xFF15803D),
        borda: Color(0xFFBBF7D0),
        icone: Icons.check_circle_outline,
      );
    }
    if (s.contains('pagamento') || s == 'pago') {
      final pago = s.contains('pago') && !s.contains('aguard');
      return StatusEstilo(
        rotulo: pago ? 'Pago' : 'Aguardando Pagamento',
        fundo: const Color(0xFFFEF9C3),
        texto: const Color(0xFF854D0E),
        borda: const Color(0xFFFDE68A),
        icone: Icons.payments_outlined,
      );
    }
    return const StatusEstilo(
      rotulo: 'Aguardando profissional',
      fundo: Color(0xFFE0F2FE),
      texto: Color(0xFF0284C7),
      borda: Color(0xFFBAE6FD),
      icone: Icons.hourglass_top_outlined,
    );
  }
}

class StatusEstilo {
  final String rotulo;
  final Color fundo;
  final Color texto;
  final Color borda;
  final IconData icone;
  const StatusEstilo({
    required this.rotulo,
    required this.fundo,
    required this.texto,
    required this.borda,
    required this.icone,
  });
}
