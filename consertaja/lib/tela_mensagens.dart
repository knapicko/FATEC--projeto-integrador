import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'seguindo_cliente.dart';
import 'services/verificacao_online.dart';
import 'tela_chat_profissional.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';
import 'utils/app_navigation_util.dart';

/// Tela "Mensagens": lista de conversas do usuário logado (cliente ou profissional),
/// com visual moderno, atualização em tempo real, indicador de presença online,
/// badge com contador de não lidas e tipografia fiel ao design.
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
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _titleDark = Color(0xFF111827);
  static const Color _unreadAccent = Color(0xFF1D4F91);
  static const Color _textMuted = Color(0xFF6B7280);

  final _supabase = Supabase.instance.client;
  final _buscaController = TextEditingController();

  List<_ConversaResumo> _conversas = [];
  bool _carregando = true;
  String? _erro;
  String _termoBusca = '';
  int? _idUsuarioLogado;
  bool _isProfissional = false;

  RealtimeChannel? _canalLista;
  Timer? _pollingLista;
  Timer? _timerOnlineTicker;
  Timer? _debounceReload;

  @override
  void initState() {
    super.initState();
    _isProfissional = widget.isProfissional;
    _carregarConversas(mostrarLoading: true).then((_) {
      if (mounted) _assinarAtualizacoes();
    });

    // Reavalia a cada 15 segundos para atualizar a bolinha azul de online visualmente
    _timerOnlineTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounceReload?.cancel();
    _pollingLista?.cancel();
    _timerOnlineTicker?.cancel();
    if (_canalLista != null) {
      _supabase.removeChannel(_canalLista!);
    }
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarConversas({bool mostrarLoading = false}) async {
    if (mostrarLoading && mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _aplicarLista([]);
        return;
      }

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario, tipo_conta')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) {
        _aplicarLista([]);
        return;
      }
      _idUsuarioLogado = idUsuario;

      final isProfissional =
          (usuario?['tipo_conta'] ?? '').toString() == 'Profissional' ||
          widget.isProfissional;
      if (mounted) {
        setState(() => _isProfissional = isProfissional);
      } else {
        _isProfissional = isProfissional;
      }

      final List<Map<String, dynamic>> conversas;
      if (isProfissional) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('id_profissional')
            .eq('fk_usuario', idUsuario)
            .maybeSingle();
        final idProf = (dadosProf?['id_profissional'] as num?)?.toInt();
        if (idProf == null) {
          _aplicarLista([]);
          return;
        }
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

      if (conversas.isEmpty) {
        _aplicarLista([]);
        return;
      }

      final Map<int, Map<String, dynamic>> contatoPorChave;
      if (isProfissional) {
        final idsClientes = {
          ...conversas
              .map((row) => (row['fk_usuario'] as num?)?.toInt())
              .whereType<int>(),
        }.toList();
        if (idsClientes.isEmpty) {
          _aplicarLista([]);
          return;
        }
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
              .whereType<int>(),
        }.toList();
        if (idsProfissional.isEmpty) {
          _aplicarLista([]);
          return;
        }
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
              .whereType<int>(),
        }.toList();
        if (idsUsuariosProf.isEmpty) {
          _aplicarLista([]);
          return;
        }
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
              entrada.key:
                  usuarioPorId[(entrada.value['fk_usuario'] as num).toInt()]!,
        };
      }

      final idsConversas = {
        ...conversas
            .map((row) => (row['id_conversa'] as num?)?.toInt())
            .whereType<int>(),
      }.toList();
      final ultimaPorConversa = <int, Map<String, dynamic>>{};
      final naoLidasPorConversa = <int, int>{};
      try {
        final mensagens = await _buscarMensagens(idsConversas);
        for (final mensagem in mensagens) {
          final id = (mensagem['fk_conversa'] as num?)?.toInt();
          if (id == null) continue;
          if (!ultimaPorConversa.containsKey(id)) {
            ultimaPorConversa[id] = Map<String, dynamic>.from(mensagem);
          }
          if (!mensagem.containsKey('lida')) continue;
          final remetente =
              (mensagem['fk_remitente_usuario'] as num?)?.toInt();
          if (remetente != null &&
              remetente != idUsuario &&
              mensagem['lida'] != true) {
            naoLidasPorConversa[id] = (naoLidasPorConversa[id] ?? 0) + 1;
          }
        }
      } catch (_) {}

      final servicoPorConversa = <int, String>{};
      try {
        final idsSolicitacao = {
          ...conversas
              .map((row) => (row['fk_solicitacao'] as num?)?.toInt())
              .whereType<int>(),
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
                .whereType<int>(),
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
      } catch (_) {}

      final oficioPorProfissional = <int, String>{};
      if (!isProfissional) {
        try {
          final idsProf = contatoPorChave.keys.toList();
          if (idsProf.isNotEmpty) {
            final assocs = await _supabase
                .from('ass_oficio_profissional')
                .select('fk_profissional, fk_oficio')
                .inFilter('fk_profissional', idsProf);
            final idsOficio = assocs
                .map((r) => (r['fk_oficio'] as num?)?.toInt())
                .whereType<int>()
                .toSet()
                .toList();
            if (idsOficio.isNotEmpty) {
              final oficios = await _supabase
                  .from('oficios')
                  .select('id_oficio, funcao')
                  .inFilter('id_oficio', idsOficio);
              final funcaoPorId = <int, String>{
                for (final row in oficios)
                  if ((row['id_oficio'] as num?) != null)
                    (row['id_oficio'] as num).toInt():
                        row['funcao']?.toString() ?? '',
              };
              for (final row in assocs) {
                final idP = (row['fk_profissional'] as num?)?.toInt();
                final idO = (row['fk_oficio'] as num?)?.toInt();
                if (idP != null &&
                    idO != null &&
                    !oficioPorProfissional.containsKey(idP)) {
                  final funcao = funcaoPorId[idO] ?? '';
                  if (funcao.isNotEmpty) oficioPorProfissional[idP] = funcao;
                }
              }
            }
          }
        } catch (_) {}
      }

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
        final remetenteUltima =
            (ultima?['fk_remitente_usuario'] as num?)?.toInt();
        final ultimaLida = ultima?['lida'] == true;
        final ultimaEnviadaPorMim =
            remetenteUltima != null && remetenteUltima == idUsuario;
        final ultimaRecebida =
            remetenteUltima != null && remetenteUltima != idUsuario;

        resultado.add(
          _ConversaResumo(
            idConversa: idConv,
            nomeContato: contato['nome']?.toString() ?? 'Nome não encontrado',
            fotoUrl: contato['foto_perfil_url']?.toString() ?? '',
            oficioContato: isProfissional
                ? 'Cliente'
                : (oficioPorProfissional[chaveContato] ?? ''),
            idProfissional: isProfissional ? null : chaveContato,
            servicoAssociado: servicoPorConversa[idConv],
            ultimaConexaoContato: DateTime.tryParse(
              contato['ultima_conexao']?.toString() ?? '',
            ),
            ultimaMensagem: ultima?['conteudo']?.toString(),
            dataUltimaMensagem: DateTime.tryParse(
              ultima?['data_envio']?.toString() ?? '',
            ),
            mensagensNaoLidas: naoLidasPorConversa[idConv] ?? 0,
            ultimaMensagemRecebida: ultimaRecebida,
            ultimaMensagemLida: ultimaLida,
            ultimaMensagemEnviadaPorMim: ultimaEnviadaPorMim,
          ),
        );
      }

      if (resultado.isEmpty) {
        _aplicarLista([]);
        return;
      }

      resultado.sort((a, b) {
        final fa = a.dataUltimaMensagem;
        final fb = b.dataUltimaMensagem;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });

      _aplicarLista(resultado);
    } catch (erro) {
      if (_eTabelaIndisponivel(erro)) {
        _aplicarLista([]);
        return;
      }
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as conversas.';
      });
    }
  }

  void _aplicarLista(List<_ConversaResumo> lista) {
    if (!mounted) return;
    setState(() {
      _conversas = lista;
      _carregando = false;
      _erro = null;
    });
  }

  void _assinarAtualizacoes() {
    _pollingLista?.cancel();
    if (_canalLista != null) {
      _supabase.removeChannel(_canalLista!);
      _canalLista = null;
    }

    final canal = _supabase.channel(
      'lista_mensagens_realtime_${_idUsuarioLogado ?? 0}_${DateTime.now().millisecondsSinceEpoch}',
    );
    _canalLista = canal;

    // Escuta novas mensagens e alterações em conversas em tempo real
    canal.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'mensagens',
      callback: (_) => _agendarRecarregar(),
    );
    canal.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversas',
      callback: (_) => _agendarRecarregar(),
    );
    canal.subscribe();

    // Polling a cada 4 segundos como garantia para atualizações silenciosas em segundo plano
    _pollingLista = Timer.periodic(const Duration(seconds: 4), (_) {
      _carregarConversas();
    });
  }

  void _agendarRecarregar() {
    _debounceReload?.cancel();
    _debounceReload = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _carregarConversas();
    });
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

  Future<List<Map<String, dynamic>>> _buscarMensagens(List<int> ids) async {
    try {
      return await _supabase
          .from('mensagens')
          .select(
            'fk_conversa, conteudo, data_envio, fk_remitente_usuario, lida',
          )
          .inFilter('fk_conversa', ids)
          .order('data_envio', ascending: false)
          .limit(300);
    } catch (_) {
      return await _supabase
          .from('mensagens')
          .select('fk_conversa, conteudo, data_envio, fk_remitente_usuario')
          .inFilter('fk_conversa', ids)
          .order('data_envio', ascending: false)
          .limit(300);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackHandler(
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _primaryBlue,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: _voltarParaHome,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          title: const Text(
            'Mensagens',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildBarraPesquisa(),
            Expanded(child: _buildLista()),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildLista() {
    if (_carregando && _conversas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryBlue),
      );
    }
    if (_erro != null && _conversas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMuted),
          ),
        ),
      );
    }

    final termo = _termoBusca.trim().toLowerCase();
    final conversas = _conversas
        .where(
          (conversa) =>
              termo.isEmpty ||
              conversa.nomeContato.toLowerCase().contains(termo) ||
              conversa.subtituloServico.toLowerCase().contains(termo) ||
              (conversa.ultimaMensagem ?? '').toLowerCase().contains(termo),
        )
        .toList();

    if (conversas.isEmpty) {
      return _buildEstadoVazio(termo.isNotEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: conversas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCard(conversas[index]);
      },
    );
  }

  Widget _buildBarraPesquisa() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _buscaController,
          onChanged: (value) => setState(() => _termoBusca = value),
          style: const TextStyle(fontSize: 15, color: _titleDark),
          decoration: InputDecoration(
            hintText: 'Pesquisar...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
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

  void _navegar(int index) {
    if (index == 0) {
      AppNavigationUtil.navegarAba(
        context,
        widget.isProfissional
            ? TelaHomeProfissional(isVisitante: widget.isVisitante)
            : TelaHome(isVisitante: widget.isVisitante),
        isHome: true,
      );
    } else if (index == 1 && !widget.isProfissional) {
      AppNavigationUtil.navegarAba(
        context,
        SeguindoClientePage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    } else if (index == 4) {
      AppNavigationUtil.navegarAba(
        context,
        widget.isProfissional
            ? TelaMeuPerfilProfissionalPage(isVisitante: widget.isVisitante)
            : TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    }
  }

  void _voltarParaHome() {
    AppNavigationUtil.tratarBotaoVoltar(context, isHome: false);
  }

  Widget _buildEstadoVazio(bool pesquisaAtiva) {
    if (pesquisaAtiva) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma conversa encontrada',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tente buscar por outro termo ou nome.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final titulo = _isProfissional
        ? 'Você ainda não contatou nem foi contatado por nenhum cliente'
        : 'Você ainda não contatou nenhum profissional';

    final subtitulo = _isProfissional
        ? 'Quando um cliente iniciar um atendimento ou você enviar uma mensagem, as conversas aparecerão aqui.'
        : 'Quando você iniciar uma conversa com um profissional para solicitar um serviço, ela aparecerá aqui.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F6FD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _titleDark,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_ConversaResumo conversa) {
    final destaqueNaoLida = conversa.temNaoLidas;
    final textoDataHora = _formatarDataHoraUltimaMensagem(
      conversa.dataUltimaMensagem,
    );

    // Cores e estilos fiéis ao design
    final corHorario = destaqueNaoLida ? _unreadAccent : _textMuted;
    final corServico = destaqueNaoLida ? _unreadAccent : _textMuted;
    final corMensagem = destaqueNaoLida ? _titleDark : _textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TelaChatProfissional(
                nomeProfissional: conversa.nomeContato,
                fotoProfissional: conversa.fotoUrl,
                oficioPrincipal: conversa.subtituloServico,
                idProfissional: conversa.idProfissional,
                idConversa: conversa.idConversa > 0 ? conversa.idConversa : null,
              ),
            ),
          );
          if (!mounted) return;
          _carregarConversas();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(conversa),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Linha 1: Nome e Horário
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversa.nomeContato,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                color: _titleDark,
                              ),
                            ),
                          ),
                          if (textoDataHora.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              textoDataHora,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: destaqueNaoLida
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: corHorario,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Linha 2: Categoria / Serviço
                      const SizedBox(height: 3),
                      Text(
                        conversa.subtituloServico,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: destaqueNaoLida
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: corServico,
                        ),
                      ),
                      // Linha 3: Mensagem prévia e Badge numérico
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Visto único/duplo: aparece SOMENTE nas mensagens
                          // ENVIADAS pelo usuário logado (última mensagem da
                          // conversa enviada por mim), para mostrar se foi
                          // lida (azul duplo) ou não (cinza).
                          if (conversa.ultimaMensagemEnviadaPorMim &&
                              (conversa.ultimaMensagem
                                      ?.trim()
                                      .isNotEmpty ==
                                  true)) ...[
                            Icon(
                              conversa.ultimaMensagemLida
                                  ? Icons.done_all
                                  : Icons.done,
                              size: 16,
                              color:
                                  conversa.ultimaMensagemLida
                                      ? _primaryBlue
                                      : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conversa.ultimaMensagem ?? 'Nenhuma mensagem ainda',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: destaqueNaoLida
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: corMensagem,
                              ),
                            ),
                          ),
                          if (conversa.mensagensNaoLidas > 0) ...[
                            const SizedBox(width: 8),
                            _buildBadgeNaoLidas(conversa.mensagensNaoLidas),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeNaoLidas(int quantidade) {
    final texto = quantidade > 99 ? '99+' : '$quantidade';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildAvatar(_ConversaResumo conversa) {
    final online = VerificacaoOnline.estaOnline(conversa.ultimaConexaoContato);
    final temFoto = conversa.fotoUrl.trim().startsWith('http');

    final Widget avatar = temFoto
        ? CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: NetworkImage(conversa.fotoUrl),
          )
        : CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFDCE5EE),
            child: Text(
              obterIniciais(conversa.nomeContato),
              style: const TextStyle(
                color: Color(0xFF5E6F7E),
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
          );

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Formatação em formato 24h BR (ex: "23:00", "Ontem", "Seg", "12/07")
  String _formatarDataHoraUltimaMensagem(DateTime? data) {
    if (data == null) return '';
    final local = data.isUtc ? data.toLocal() : data;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diaMsg = DateTime(local.year, local.month, local.day);
    final diferencaDias = hoje.difference(diaMsg).inDays;

    if (diferencaDias == 0) {
      return DateFormat('HH:mm').format(local);
    }
    if (diferencaDias == 1) return 'Ontem';
    if (diferencaDias < 7 && diferencaDias > 0) {
      final diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return diasSemana[local.weekday - 1];
    }
    return DateFormat('dd/MM').format(local);
  }
}

class _ConversaResumo {
  final int idConversa;
  final String nomeContato;
  final String fotoUrl;
  final String oficioContato;
  final int? idProfissional;
  final String? servicoAssociado;
  final DateTime? ultimaConexaoContato;
  final String? ultimaMensagem;
  final DateTime? dataUltimaMensagem;
  final int mensagensNaoLidas;
  final bool forcarDestaqueNaoLida;
  final bool ultimaMensagemRecebida;
  final bool ultimaMensagemLida;
  final bool ultimaMensagemEnviadaPorMim;

  const _ConversaResumo({
    required this.idConversa,
    required this.nomeContato,
    this.fotoUrl = '',
    this.oficioContato = '',
    this.idProfissional,
    this.servicoAssociado,
    this.ultimaConexaoContato,
    this.ultimaMensagem,
    this.dataUltimaMensagem,
    this.mensagensNaoLidas = 0,
    this.forcarDestaqueNaoLida = false,
    this.ultimaMensagemRecebida = false,
    this.ultimaMensagemLida = false,
    this.ultimaMensagemEnviadaPorMim = false,
  });

  bool get temNaoLidas => mensagensNaoLidas > 0 || forcarDestaqueNaoLida;

  String get subtituloServico {
    if (servicoAssociado != null && servicoAssociado!.trim().isNotEmpty) {
      return servicoAssociado!.trim();
    }
    if (oficioContato.trim().isNotEmpty) {
      return oficioContato.trim();
    }
    return 'Atendimento';
  }
}
