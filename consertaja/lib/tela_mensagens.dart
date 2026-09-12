import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'seguindo_cliente.dart';
import 'services/formatacao_data.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';

/// Tela "Mensagens": lista de conversas do usuário logado (cliente ou
/// profissional), acessada pelo botão "Mensagens" da barra de navegação
/// inferior do home.
///
/// Cada card de contato exibe:
///  - foto à esquerda (ou iniciais como fallback);
///  - nome;
///  - serviço associado, apenas quando existe uma solicitação aceita
///    (data_aceite não nula) que referencia esse serviço;
///  - última vez ativo ("Online", "há X min", "há X h", "há X dias"...);
///  - última mensagem da conversa.
///
/// Por enquanto é uma visualização essencialmente visual: se ainda não há
/// dados reais (ou as tabelas ainda não foram criadas no Supabase) são
/// exibidas conversas de exemplo para que seja possível ver o layout. Para
/// carregar seus dados reais, execute o script `docs/sql/mensagens.sql`.
class TelaMensagensPage extends StatefulWidget {
  final bool isVisitante;
  final bool isProfissional;

  const TelaMensagensPage({
    super.key,
    this.isVisitante = false,
    this.isProfissional = false,
  });

  @override
  State<TelaMensagensPage> createState() => _TelaMensagensPageState();
}

class _TelaMensagensPageState extends State<TelaMensagensPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFFAFAFA);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _greenOnline = Color(0xFF1F9D55);

  /// Quando ativo, se não há conversas reais (ou as tabelas ainda não
  /// existem) é exibida uma lista de exemplo com um banner de aviso.
  static const bool _mostrarExemplosQuandoNaoHa = true;

  final _supabase = Supabase.instance.client;
  final _buscaController = TextEditingController();

  late Future<List<_ConversaResumo>> _conversasFuture;
  bool _buscaAtiva = false;
  String _termoBusca = '';
  bool _visualizacaoPrevia = false;

  @override
  void initState() {
    super.initState();
    _conversasFuture = _carregarConversas();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // ======================================================================
  //  Carregamento de dados (Supabase)
  // ======================================================================

  Future<List<_ConversaResumo>> _carregarConversas() async {
    _visualizacaoPrevia = false;

    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return _conversasDeExemplo();

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario, tipo_conta')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return _conversasDeExemplo();

      final isProfissional =
          (usuario?['tipo_conta'] ?? '').toString() == 'Profissional';

      // Conversas do usuário logado.
      final List<Map<String, dynamic>> conversas;
      if (isProfissional) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('id_profissional')
            .eq('fk_usuario', idUsuario)
            .maybeSingle();
        final idProf = (dadosProf?['id_profissional'] as num?)?.toInt();
        if (idProf == null) return _conversasDeExemplo();
        conversas = await _supabase
            .from('conversas')
            .select()
            .eq('fk_profissional', idProf);
      } else {
        conversas = await _supabase
            .from('conversas')
            .select()
            .eq('fk_usuario', idUsuario);
      }

      if (conversas.isEmpty) return _conversasDeExemplo();

      // Resolver o outro lado da conversa (o contato que é exibido).
      // Para o cliente o contato é o profissional; para o profissional o
      // contato é o cliente.
      final Map<int, Map<String, dynamic>> contatoPorChave;
      if (isProfissional) {
        final idsClientes = {
          ...conversas
              .map((row) => (row['fk_usuario'] as num?)?.toInt())
              .whereType<int>()
              .toList(),
        }.toList();
        if (idsClientes.isEmpty) return _conversasDeExemplo();
        final usuarios = await _buscarUsuarios(idsClientes);
        contatoPorChave = {
          for (final row in usuarios)
            if ((row['id_usuario'] as num?) != null)
              (row['id_usuario'] as num).toInt():
                  Map<String, dynamic>.from(row),
        };
      } else {
        final idsProfissional = {
          ...conversas
              .map((row) => (row['fk_profissional'] as num?)?.toInt())
              .whereType<int>()
              .toList(),
        }.toList();
        if (idsProfissional.isEmpty) return _conversasDeExemplo();
        final dados = await _supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_usuario')
            .inFilter('id_profissional', idsProfissional);
        final dadosPorId = <int, Map<String, dynamic>>{
          for (final row in dados)
            if ((row['id_profissional'] as num?) != null)
              (row['id_profissional'] as num).toInt():
                  Map<String, dynamic>.from(row),
        };
        final idsUsuariosProf = {
          ...dados
              .map((row) => (row['fk_usuario'] as num?)?.toInt())
              .whereType<int>()
              .toList(),
        }.toList();
        if (idsUsuariosProf.isEmpty) return _conversasDeExemplo();
        final usuarios = await _buscarUsuarios(idsUsuariosProf);
        final usuarioPorId = <int, Map<String, dynamic>>{
          for (final row in usuarios)
            if ((row['id_usuario'] as num?) != null)
              (row['id_usuario'] as num).toInt():
                  Map<String, dynamic>.from(row),
        };
        contatoPorChave = <int, Map<String, dynamic>>{
          for (final entrada in dadosPorId.entries)
            if (usuarioPorId[(entrada.value['fk_usuario'] as num?)?.toInt()] !=
                null)
              entrada.key: usuarioPorId[
                  (entrada.value['fk_usuario'] as num).toInt()]!,
        };
      }
// Última mensagem de cada conversa (a mais recente primeiro).
      final idsConversas = {
        ...conversas
            .map((row) => (row['id_conversa'] as num?)?.toInt())
            .whereType<int>()
            .toList(),
      }.toList();
      final ultimaPorConversa = <int, Map<String, dynamic>>{};
      try {
        final mensagens = await _supabase
            .from('mensagens')
            .select('fk_conversa, conteudo, data_envio')
            .inFilter('fk_conversa', idsConversas)
            .order('data_envio'); // descendente por padrão
        for (final mensagem in mensagens) {
          final id = (mensagem['fk_conversa'] as num?)?.toInt();
          if (id != null && !ultimaPorConversa.containsKey(id)) {
            ultimaPorConversa[id] = Map<String, dynamic>.from(mensagem);
          }
        }
      } catch (_) {
        // Opcional: se falhar, o card fica sem visualização.
      }

      // Serviço associado (apenas solicitações aceitas → data_aceite não nula).
      final servicoPorConversa = <int, String>{};
      try {
        final idsSolicitacao = {
          ...conversas
              .map((row) => (row['fk_solicitacao'] as num?)?.toInt())
              .whereType<int>()
              .toList(),
        }.toList();
        if (idsSolicitacao.isNotEmpty) {
          final solicitacoes = await _supabase
              .from('solicitacoes')
              .select('id_solicitacao, data_aceite, fk_servico_prof')
              .inFilter('id_solicitacao', idsSolicitacao);
          final idsServico = {
            ...solicitacoes
                .where(
                  (row) =>
                      row['data_aceite'] != null &&
                      row['fk_servico_prof'] != null,
                )
                .map((row) => (row['fk_servico_prof'] as num?)?.toInt())
                .whereType<int>()
                .toList(),
          }.toList();
          if (idsServico.isNotEmpty) {
            final servicos = await _supabase
                .from('servicos_profissional')
                .select('id_servico_prof, titulo')
                .inFilter('id_servico_prof', idsServico);
            final tituloPorServico = <int, String>{
              for (final row in servicos)
                if ((row['id_servico_prof'] as num?) != null &&
                    row['titulo'] != null)
                  (row['id_servico_prof'] as num).toInt():
                      row['titulo'].toString(),
            };
            final solicitacaoPorId = <int, Map<String, dynamic>>{
              for (final row in solicitacoes)
                if ((row['id_solicitacao'] as num?) != null)
                  (row['id_solicitacao'] as num).toInt():
                      Map<String, dynamic>.from(row),
            };
            for (final conv in conversas) {
              final idSol = (conv['fk_solicitacao'] as num?)?.toInt();
              if (idSol == null) continue;
              final solicitacao = solicitacaoPorId[idSol];
              if (solicitacao == null || solicitacao['data_aceite'] == null) {
                continue;
              }
              final idServ =
                  (solicitacao['fk_servico_prof'] as num?)?.toInt();
              final titulo = idServ == null ? null : tituloPorServico[idServ];
              final idConv = (conv['id_conversa'] as num?)?.toInt();
              if (idConv != null && titulo != null && titulo.isNotEmpty) {
                servicoPorConversa[idConv] = titulo;
              }
            }
          }
        }
      } catch (_) {
        // O serviço associado é opcional; ignora se a coluna ainda não
        // existir em `solicitacoes`.
      }
// Construir os resumos de conversa.
      final resultado = <_ConversaResumo>[];
      for (final conv in conversas) {
        final idConv = (conv['id_conversa'] as num?)?.toInt();
        final chaveContato = isProfissional
            ? (conv['fk_usuario'] as num?)?.toInt()
            : (conv['fk_profissional'] as num?)?.toInt();
        if (idConv == null) continue;
        final contato =
            chaveContato == null ? null : contatoPorChave[chaveContato];
        if (contato == null) continue;

        final ultima = ultimaPorConversa[idConv];
        resultado.add(
          _ConversaResumo(
            idConversa: idConv,
            nomeContato:
                contato['nome']?.toString() ?? 'Nome não encontrado',
            fotoUrl: contato['foto_perfil_url']?.toString() ?? '',
            servicoAssociado: servicoPorConversa[idConv],
            ultimaConexaoContato: DateTime.tryParse(
              contato['ultima_conexao']?.toString() ?? '',
            ),
            ultimaMensagem: ultima?['conteudo']?.toString(),
            dataUltimaMensagem: DateTime.tryParse(
              ultima?['data_envio']?.toString() ?? '',
            ),
          ),
        );
      }

      if (resultado.isEmpty) return _conversasDeExemplo();

      // Ordenar por mensagem mais recente.
      resultado.sort((a, b) {
        final fa = a.dataUltimaMensagem;
        final fb = b.dataUltimaMensagem;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });

      return resultado;
    } catch (erro) {
      // Se as tabelas de mensageria ainda não existem (ou RLS as bloqueia) e
      // temos a visualização prévia ativada, mostramos os exemplos visuais.
      if (_mostrarExemplosQuandoNaoHa && _eTabelaIndisponivel(erro)) {
        return _conversasDeExemplo();
      }
      return [];
    }
  }

  static bool _eTabelaIndisponivel(Object erro) {
    if (erro is! PostgrestException) return false;
    final texto =
        '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'.toLowerCase();
    return erro.code == '42P01' ||
        (texto.contains('conversas') || texto.contains('mensagens')) &&
            (texto.contains('not found') ||
                texto.contains('does not exist') ||
                texto.contains('relation') ||
                texto.contains('schema cache'));
  }

  /// Consulta os usuários cuidando para que a coluna `ultima_conexao` pode não
  /// existir ainda se o script de mensageria não foi executado.
  Future<List<Map<String, dynamic>>> _buscarUsuarios(List<int> ids) async {
    try {
      return await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url, ultima_conexao')
          .inFilter('id_usuario', ids);
    } catch (_) {
      return await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .inFilter('id_usuario', ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
        ),
        title: const Text(
          'Mensagens',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildBarraPesquisa(),
          Expanded(
            child: FutureBuilder<List<_ConversaResumo>>(
              future: _conversasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryBlue),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Não foi possível carregar as conversas.'),
                  );
                }

                final termo = _termoBusca.trim().toLowerCase();
                final conversas = (snapshot.data ?? [])
                    .where(
                      (conversa) =>
                          termo.isEmpty ||
                          conversa.nomeContato.toLowerCase().contains(termo),
                    )
                    .toList();
                if (conversas.isEmpty) {
                  return _buildEstadoVazio(termo.isNotEmpty);
                }

                final children = <Widget>[];
                if (_visualizacaoPrevia) children.add(_buildBannerVisualizacaoPrevia());
                for (var index = 0; index < conversas.length; index++) {
                  if (index > 0) children.add(const SizedBox(height: 12));
                  children.add(_buildCard(conversas[index]));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  children: children,
                );
              },
              ),
            ),
          ],
        ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBarraPesquisa() {
    return Container(
      color: _background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _buscaController,
          onChanged: (value) => setState(() => _termoBusca = value),
          style: const TextStyle(fontSize: 15, color: _titleDark),
          decoration: InputDecoration(
            hintText: 'Pesquisar conversas',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (widget.isProfissional) {
      return BottomNavigationBarProfissional(currentIndex: 2, onTap: _navegar);
    }
    return BottomNavigationBarCliente(currentIndex: 2, onTap: _navegar);
  }

  PageRouteBuilder _rotaSemAnimacao(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _navegar(int index) {
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(
          widget.isProfissional
              ? TelaHomeProfissional(isVisitante: widget.isVisitante)
              : TelaHome(isVisitante: widget.isVisitante),
        ),
      );
    } else if (index == 1 && !widget.isProfissional) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(
          SeguindoClientePage(isVisitante: widget.isVisitante),
        ),
      );
    } else if (index == 4) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(
          widget.isProfissional
              ? TelaMeuPerfilProfissionalPage(isVisitante: widget.isVisitante)
              : TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
        ),
      );
    }
    // Os índices 3 (Pedidos) ainda não está linkado.
  }

  Widget _buildEstadoVazio(bool pesquisaAtiva) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.message_outlined,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            pesquisaAtiva
                ? 'A pesquisa não encontrou conversas.'
                : 'Você ainda não tem conversas.\nQuando iniciar um chat com um profissional, aparecerá aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerVisualizacaoPrevia() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Visualização prévia: conversas de exemplo. Crie as tabelas do SQL de '
        'mensageria para ver os seus dados reais.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Color(0xFF8A6D1D)),
      ),
    );
  }

  Widget _buildCard(_ConversaResumo conversa) {
    final textoEstado = formatarUltimaVezAtivo(conversa.ultimaConexaoContato);
    final corEstado = conversa.estaOnline ? _greenOnline : _textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A conversa completa estará disponível em breve.'),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(conversa),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          conversa.nomeContato,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _titleDark,
                          ),
                        ),
                      ),
                      if (textoEstado.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          textoEstado,
                          style: TextStyle(fontSize: 12, color: corEstado),
                        ),
                      ],
                    ],
                  ),
                  if (conversa.servicoAssociado != null) ...[
                    const SizedBox(height: 5),
                    _buildTagServico(conversa.servicoAssociado!),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    conversa.ultimaMensagem ?? 'A conversa está vazia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagServico(String titulo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Color(0xFF0A6E9D)),
      ),
    );
  }

  Widget _buildAvatar(_ConversaResumo conversa) {
    if (conversa.fotoUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 27,
        backgroundImage: NetworkImage(conversa.fotoUrl),
      );
    }
    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFFE6EFF2),
      child: Text(
        obterIniciais(conversa.nomeContato),
        style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
      ),
    );
  }
// ======================================================================
  //  Visualização prévia (dados de exemplo, enquanto não há mensageria real)
  // ======================================================================

  List<_ConversaResumo> _conversasDeExemplo() {
    _visualizacaoPrevia = true;
    final agora = DateTime.now();
    return [
      _ConversaResumo(
        idConversa: -1,
        nomeContato: 'Carlos Mendes',
        servicoAssociado: 'Conserto de cabo de panela',
        ultimaConexaoContato: agora,
        ultimaMensagem: 'Boa tarde! Recebi o seu pedido, posso passar amanhã de manhã.',
        dataUltimaMensagem: agora,
      ),
      _ConversaResumo(
        idConversa: -2,
        nomeContato: 'Lúcia Ferreira',
        ultimaConexaoContato: agora.subtract(const Duration(minutes: 5)),
        ultimaMensagem: 'Ficamos de que avisaria quando estivesse livre.',
        dataUltimaMensagem: agora.subtract(const Duration(minutes: 5)),
      ),
      _ConversaResumo(
        idConversa: -3,
        nomeContato: 'João Pereira',
        servicoAssociado: 'Reparo de máquina de lavar',
        ultimaConexaoContato: agora.subtract(const Duration(hours: 3)),
        ultimaMensagem: 'Vou levar a ferramenta no sábado de manhã.',
        dataUltimaMensagem: agora.subtract(const Duration(hours: 3)),
      ),
      _ConversaResumo(
        idConversa: -4,
        nomeContato: 'Ana Torres',
        ultimaConexaoContato: agora.subtract(const Duration(days: 2)),
        ultimaMensagem: 'Obrigada pelo atendimento, tudo ficou funcionando.',
        dataUltimaMensagem: agora.subtract(const Duration(days: 2)),
      ),
      _ConversaResumo(
        idConversa: -5,
        nomeContato: 'Diego Ramírez',
        servicoAssociado: 'Cabeamento elétrico',
        ultimaConexaoContato: agora.subtract(const Duration(days: 9)),
        ultimaMensagem: 'Aviso quando conseguir os materiais.',
        dataUltimaMensagem: agora.subtract(const Duration(days: 9)),
      ),
    ];
  }
}

/// Resumo de uma conversa para a lista da tela "Mensagens".
class _ConversaResumo {
  final int idConversa;
  final String nomeContato;
  final String fotoUrl;
  final String? servicoAssociado;
  final DateTime? ultimaConexaoContato;
  final String? ultimaMensagem;
  final DateTime? dataUltimaMensagem;

  const _ConversaResumo({
    required this.idConversa,
    required this.nomeContato,
    this.fotoUrl = '',
    this.servicoAssociado,
    this.ultimaConexaoContato,
    this.ultimaMensagem,
    this.dataUltimaMensagem,
  });

  /// Considera que o contato está online se se conectou há 2 minutos ou
  /// menos (mesma regra usada por [formatarUltimaVezAtivo]).
  bool get estaOnline {
    final conexao = ultimaConexaoContato;
    if (conexao == null) return false;
    return DateTime.now().difference(conexao).inMinutes <= 2;
  }
}