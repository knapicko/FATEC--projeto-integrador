import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'utils/iniciais.dart';

class TelaChatProfissional extends StatefulWidget {
  final String nomeProfissional;
  final String fotoProfissional;
  final String oficioPrincipal;
  final int? idProfissional;

  /// Permite abrir um chat já existente a partir da lista de mensagens.
  final int? idConversa;

  const TelaChatProfissional({
    super.key,
    required this.nomeProfissional,
    required this.fotoProfissional,
    required this.oficioPrincipal,
    this.idProfissional,
    this.idConversa,
  });

  @override
  State<TelaChatProfissional> createState() => _TelaChatProfissionalState();
}

class _TelaChatProfissionalState extends State<TelaChatProfissional> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF0F2F5);
  static const Color _chatBackground = Color(0xFFE5DDD5);
  static const Color _myMessageColor = _primaryBlue;
  static const Color _myMessageTextColor = Colors.white;
  static const Color _otherMessageColor = Colors.white;

  final _supabase = Supabase.instance.client;
  final _mensagemController = TextEditingController();
  final _scrollController = ScrollController();

  int? _idConversa;
  int? _idUsuarioLogado;
  bool _souProfissionalNaConversa = false;
  bool _carregando = true;
  bool _enviando = false;
  bool _temTexto = false;
  String? _erroCarregamento;
  List<_Mensagem> _mensagens = [];
  DateTime? _ultimaConexaoContato;
  String _oficioContato = '';
  RealtimeChannel? _canalMensagens;
  Timer? _pollingMensagens;
  Timer? _timerStatusContato;

  @override
  void initState() {
    super.initState();
    _mensagemController.addListener(_atualizarEstadoTexto);
    _inicializarChat();
  }

  void _atualizarEstadoTexto() {
    final temTexto = _mensagemController.text.trim().isNotEmpty;
    if (temTexto != _temTexto && mounted) {
      setState(() => _temTexto = temTexto);
    }
  }

  void _onGravarAudio() {
    // TODO: integrar gravação de áudio (ex.: record + upload no Supabase Storage).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gravação de áudio em breve.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _pollingMensagens?.cancel();
    _pollingMensagens = null;
    _timerStatusContato?.cancel();
    _timerStatusContato = null;
    if (_canalMensagens != null) {
      _supabase.removeChannel(_canalMensagens!);
      _canalMensagens = null;
    }
    _mensagemController.removeListener(_atualizarEstadoTexto);
    _mensagemController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _inicializarChat() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        setState(() {
          _carregando = false;
          _erroCarregamento = 'Faça login para conversar.';
        });
        return;
      }

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      _idUsuarioLogado = (usuario?['id_usuario'] as num?)?.toInt();
      if (_idUsuarioLogado == null) {
        setState(() {
          _carregando = false;
          _erroCarregamento = 'Não foi possível identificar seu usuário.';
        });
        return;
      }

      if (widget.idConversa != null) {
        _idConversa = widget.idConversa;
        await _carregarPapelNaConversa();
        await _carregarStatusContato();
      } else {
        if (widget.idProfissional == null) {
          setState(() {
            _carregando = false;
            _erroCarregamento = 'Profissional não identificado.';
          });
          return;
        }
        await _abrirOuCriarConversa();
      }

      if (_idConversa == null) {
        setState(() {
          _carregando = false;
          _erroCarregamento ??= 'Não foi possível abrir a conversa.';
        });
        return;
      }

      _oficioContato = widget.oficioPrincipal;
      await _carregarStatusContato();
      // Se veio "Conversa"/vazio da lista, busca o ofício real no banco.
      if (_oficioContato.trim().isEmpty ||
          _oficioContato.trim().toLowerCase() == 'conversa') {
        await _carregarOficioContato();
      }
      await _carregarMensagens();
      _assinarMensagensTempoReal();
    } on PostgrestException catch (e) {
      debugPrint('Erro ao inicializar chat: ${e.code} ${e.message}');
      setState(() {
        _carregando = false;
        _erroCarregamento = _mensagemErroBanco(e.code ?? '', e.message);
      });
    } catch (e) {
      debugPrint('Erro ao inicializar chat: $e');
      setState(() {
        _carregando = false;
        _erroCarregamento = 'Não foi possível abrir a conversa.';
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarPapelNaConversa() async {
    try {
      final conversa = await _supabase
          .from('conversas')
          .select('fk_usuario, fk_profissional')
          .eq('id_conversa', _idConversa!)
          .maybeSingle();
      if (conversa == null) return;
      final fkUsuario = (conversa['fk_usuario'] as num?)?.toInt();
      final fkProfissional = (conversa['fk_profissional'] as num?)?.toInt();
      if (fkUsuario != null && fkUsuario == _idUsuarioLogado) {
        _souProfissionalNaConversa = false;
        return;
      }
      if (fkProfissional != null) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', fkProfissional)
            .maybeSingle();
        final fkUsuarioProf = (dadosProf?['fk_usuario'] as num?)?.toInt();
        _souProfissionalNaConversa = fkUsuarioProf == _idUsuarioLogado;
      }
    } catch (e) {
      debugPrint('Erro ao carregar papel na conversa: $e');
    }
  }

  Future<void> _abrirOuCriarConversa() async {
    _souProfissionalNaConversa = false;
    final conversaExistente = await _supabase
        .from('conversas')
        .select('id_conversa')
        .eq('fk_usuario', _idUsuarioLogado!)
        .eq('fk_profissional', widget.idProfissional!)
        .maybeSingle();

    if (conversaExistente != null) {
      _idConversa = (conversaExistente['id_conversa'] as num?)?.toInt();
    } else {
      try {
        final novaConversa = await _supabase
            .from('conversas')
            .insert({
              'fk_usuario': _idUsuarioLogado!,
              'fk_profissional': widget.idProfissional!,
            })
            .select('id_conversa')
            .maybeSingle();
        _idConversa = (novaConversa?['id_conversa'] as num?)?.toInt();
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          final conversaCriada = await _supabase
              .from('conversas')
              .select('id_conversa')
              .eq('fk_usuario', _idUsuarioLogado!)
              .eq('fk_profissional', widget.idProfissional!)
              .maybeSingle();
          _idConversa = (conversaCriada?['id_conversa'] as num?)?.toInt();
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _carregarMensagens() async {
    if (_idConversa == null) return;

    try {
      final mensagens = await _supabase
          .from('mensagens')
          .select('id_mensagem, conteudo, data_envio, fk_remitente_usuario')
          .eq('fk_conversa', _idConversa!)
          .order('data_envio', ascending: true);

      final List<_Mensagem> lista = [];
      for (final msg in mensagens) {
        final idRemetente = (msg['fk_remitente_usuario'] as num?)?.toInt();
        final dataRaw = msg['data_envio']?.toString();
        lista.add(_Mensagem(
          id: (msg['id_mensagem'] as num?)?.toInt() ?? 0,
          conteudo: msg['conteudo']?.toString() ?? '',
          dataEnvio: dataRaw == null
              ? DateTime.now()
              : DateTime.tryParse(dataRaw)?.toLocal() ?? DateTime.now(),
          ehRemetente: idRemetente == _idUsuarioLogado,
        ));
      }

      if (!mounted) return;
      setState(() {
        _mensagens = lista;
        _erroCarregamento = null;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Erro ao carregar mensagens: $e');
      if (mounted) {
        setState(
          () => _erroCarregamento ??= 'Não foi possível carregar as mensagens.',
        );
      }
    }
  }

  void _assinarMensagensTempoReal() {
    if (_idConversa == null) return;
    _pollingMensagens?.cancel();
    _timerStatusContato?.cancel();
    if (_canalMensagens != null) {
      _supabase.removeChannel(_canalMensagens!);
      _canalMensagens = null;
    }

    final canal = _supabase.channel('chat_conversa_${_idConversa!}');
    _canalMensagens = canal;

    // 1) Postgres Changes (INSERT em mensagens dessa conversa).
    // Usa merge (mantém otimistas) em vez de reload total.
    canal.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'mensagens',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'fk_conversa',
        value: _idConversa,
      ),
      callback: (payload) {
        final row = payload.newRecord;
        if (row.isEmpty || !mounted) return;
        final nova = _mensagemDoMap(row);
        if (nova == null) return;
        setState(() {
          final temOtimista = _mensagens.any(
            (m) =>
                m.id < 0 &&
                m.conteudo == nova.conteudo &&
                m.ehRemetente == nova.ehRemetente,
          );
          if (temOtimista) {
            // Troca o balão otimista (id negativo) pelo real vindo do banco.
            var trocou = false;
            _mensagens = _mensagens.map((m) {
              if (!trocou &&
                  m.id < 0 &&
                  m.conteudo == nova.conteudo &&
                  m.ehRemetente == nova.ehRemetente) {
                trocou = true;
                return nova;
              }
              return m;
            }).toList();
          } else if (!_mensagens.any((m) => m.id == nova.id)) {
            _mensagens = [..._mensagens, nova];
          }
        });
        _scrollToBottom();
      },
    );

    // 2) Polling leve como fallback (caso o Realtime esteja desligado)
    _pollingMensagens =
        Timer.periodic(const Duration(seconds: 5), (_) {
      _buscarMensagensSilencioso();
    });
    // 3) Atualiza o Online / visto por último a cada 30s
    _timerStatusContato = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _carregarStatusContato();
    });

    canal.subscribe();
  }

  _Mensagem? _mensagemDoMap(Map<String, dynamic> msg) {
    final id = (msg['id_mensagem'] as num?)?.toInt();
    if (id == null) return null;
    final idRemetente = (msg['fk_remitente_usuario'] as num?)?.toInt();
    final dataRaw = msg['data_envio']?.toString();
    return _Mensagem(
      id: id,
      conteudo: msg['conteudo']?.toString() ?? '',
      dataEnvio: dataRaw == null
          ? DateTime.now()
          : DateTime.tryParse(dataRaw)?.toLocal() ?? DateTime.now(),
      ehRemetente: idRemetente == _idUsuarioLogado,
    );
  }

  /// Recarrega sem mexer no loading/erro — usado pelo polling.
  /// Faz merge: preserva balões otimistas (id < 0) até o banco confirmar.
  Future<void> _buscarMensagensSilencioso() async {
    if (_idConversa == null || !mounted) return;
    try {
      final mensagens = await _supabase
          .from('mensagens')
          .select('id_mensagem, conteudo, data_envio, fk_remitente_usuario')
          .eq('fk_conversa', _idConversa!)
          .order('data_envio', ascending: true);
      final lista = <_Mensagem>[];
      for (final msg in mensagens) {
        final m = _mensagemDoMap(msg);
        if (m != null) lista.add(m);
      }
      if (!mounted) return;
      final otimistas = _mensagens.where((m) => m.id < 0).toList();
      final mesclada = [...lista];
      for (final o in otimistas) {
        // Mantém o otimista se ainda não há equivalente no banco
        // (mesmo conteúdo enviado por mim).
        final jaConfirmada = lista.any(
          (m) => m.conteudo == o.conteudo && m.ehRemetente,
        );
        if (!jaConfirmada) mesclada.add(o);
      }
      mesclada.sort((a, b) {
        // Otimistas (id < 0) vão pro fim, na ordem de envio.
        if (a.id < 0 && b.id < 0) return a.dataEnvio.compareTo(b.dataEnvio);
        if (a.id < 0) return 1;
        if (b.id < 0) return -1;
        return a.dataEnvio.compareTo(b.dataEnvio);
      });
      final idsAtuais = _mensagens.map((m) => m.id).join(',');
      final idsNovos = mesclada.map((m) => m.id).join(',');
      if (idsAtuais != idsNovos || mesclada.length != _mensagens.length) {
        setState(() => _mensagens = mesclada);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Polling mensagens: $e');
    }
  }

  Future<void> _enviarMensagem() async {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty || _idConversa == null || _enviando) return;
    if (_idUsuarioLogado == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para enviar mensagens.')),
      );
      return;
    }

    final textoParaEnviar = texto;
    setState(() => _enviando = true);
    _mensagemController.clear();

    // Otimista: mostra na hora antes do Supabase confirmar.
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final msgOtimista = _Mensagem(
      id: tempId,
      conteudo: textoParaEnviar,
      dataEnvio: DateTime.now(),
      ehRemetente: true,
    );
    setState(() => _mensagens = [..._mensagens, msgOtimista]);
    _scrollToBottom();

    try {
      final inserida = await _supabase
          .from('mensagens')
          .insert({
            'fk_conversa': _idConversa!,
            'tipo_mensagem': 'Texto',
            'conteudo': textoParaEnviar,
            'fk_remitente_usuario': _idUsuarioLogado!,
          })
          .select('id_mensagem, conteudo, data_envio, fk_remitente_usuario')
          .maybeSingle();

      if (!mounted) return;
      if (inserida != null) {
        final idRemetente =
            (inserida['fk_remitente_usuario'] as num?)?.toInt();
        final dataRaw = inserida['data_envio']?.toString();
        final real = _Mensagem(
          id: (inserida['id_mensagem'] as num?)?.toInt() ?? tempId,
          conteudo: inserida['conteudo']?.toString() ?? textoParaEnviar,
          dataEnvio: dataRaw == null
              ? DateTime.now()
              : DateTime.tryParse(dataRaw)?.toLocal() ?? DateTime.now(),
          ehRemetente: idRemetente == _idUsuarioLogado,
        );
        setState(() {
          _mensagens =
              _mensagens.map((m) => m.id == tempId ? real : m).toList();
        });
        _scrollToBottom();
      } else {
        await _carregarMensagens();
      }
    } on PostgrestException catch (e) {
      debugPrint('Erro ao enviar mensagem: ${e.message}');
      if (!mounted) return;
      setState(() => _mensagens =
          _mensagens.where((m) => m.id != tempId).toList());
      _mensagemController.text = textoParaEnviar;
      _mensagemController.selection = TextSelection.fromPosition(
        TextPosition(offset: _mensagemController.text.length),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == '42501'
                ? 'Sem permissão (RLS). Rode o SQL de políticas do chat.'
                : 'Não foi possível enviar. Tente de novo.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao enviar mensagem: $e');
      if (!mounted) return;
      setState(() => _mensagens =
          _mensagens.where((m) => m.id != tempId).toList());
      _mensagemController.text = textoParaEnviar;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar. Tente de novo.')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Busca o ofício real do contato quando o header veio sem ele
  /// (ex: lista passou "Conversa"). Funciona pros dois lados.
  Future<void> _carregarOficioContato() async {
    try {
      int? idProf;
      if (_souProfissionalNaConversa) {
        // Eu sou o profissional: não há ofício do cliente.
        return;
      }
      idProf = widget.idProfissional;
      if (idProf == null && _idConversa != null) {
        final conversa = await _supabase
            .from('conversas')
            .select('fk_profissional')
            .eq('id_conversa', _idConversa!)
            .maybeSingle();
        idProf = (conversa?['fk_profissional'] as num?)?.toInt();
      }
      if (idProf == null) {
        debugPrint('Ofício contato: idProfissional nulo, mantendo header.');
        return;
      }

      final assocs = await _supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', idProf)
          .limit(1);
      if (assocs.isEmpty) {
        debugPrint(
          'Ofício contato: nenhum ofício em ass_oficio_profissional p/ $idProf.',
        );
        return;
      }
      final idOficio = (assocs.first['fk_oficio'] as num?)?.toInt();
      if (idOficio == null) return;

      final oficio = await _supabase
          .from('oficios')
          .select('funcao')
          .eq('id_oficio', idOficio)
          .maybeSingle();
      final funcao = oficio?['funcao']?.toString().trim() ?? '';
      if (funcao.isNotEmpty && mounted) {
        setState(() => _oficioContato = funcao);
      } else {
        debugPrint('Ofício contato: funcao vazia p/ id_oficio=$idOficio.');
      }
    } on PostgrestException catch (e) {
      debugPrint('Ofício contato RLS/banco: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('Erro ao carregar ofício do contato: $e');
    }
  }

  /// Busca a última conexão do contato para exibir Online / visto por último.
  Future<void> _carregarStatusContato() async {
    if (_idConversa == null) return;
    try {

      int? idUsuarioContato;
      if (_souProfissionalNaConversa) {
        // Eu sou o profissional: contato é o cliente (fk_usuario da conversa).
        final conversa = await _supabase
            .from('conversas')
            .select('fk_usuario')
            .eq('id_conversa', _idConversa!)
            .maybeSingle();
        idUsuarioContato = (conversa?['fk_usuario'] as num?)?.toInt();
      } else {
        // Eu sou o cliente: contato é o profissional.
        int? idProf = widget.idProfissional;
        if (idProf == null && _idConversa != null) {
          final conversa = await _supabase
              .from('conversas')
              .select('fk_profissional')
              .eq('id_conversa', _idConversa!)
              .maybeSingle();
          idProf = (conversa?['fk_profissional'] as num?)?.toInt();
        }
        if (idProf != null) {
          final dadosProf = await _supabase
              .from('dados_profissionais')
              .select('fk_usuario')
              .eq('id_profissional', idProf)
              .maybeSingle();
          idUsuarioContato = (dadosProf?['fk_usuario'] as num?)?.toInt();
        }
      }
      if (idUsuarioContato == null) return;

      final usuario = await _supabase
          .from('usuarios')
          .select('ultima_conexao')
          .eq('id_usuario', idUsuarioContato)
          .maybeSingle();
      final raw = usuario?['ultima_conexao']?.toString();
      if (!mounted) return;
      setState(() {
        _ultimaConexaoContato =
            raw == null ? null : DateTime.tryParse(raw)?.toLocal();
      });
    } catch (e) {
      debugPrint('Erro ao carregar status do contato: $e');
    }
  }

  bool get _contatoOnline {
    final conexao = _ultimaConexaoContato;
    if (conexao == null) return false;
    return DateTime.now().difference(conexao).inMinutes <= 2;
  }

  /// Texto + cor do status: verde "Online" ou cinza "visto por último ...".
  (String, Color) _textoCorStatusContato() {
    const verde = Color(0xFF1F9D55);
    final cinza = Colors.grey.shade600;
    final conexao = _ultimaConexaoContato;
    if (conexao == null) return ('', cinza);
    if (_contatoOnline) return ('Online', verde);
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diaConexao = DateTime(conexao.year, conexao.month, conexao.day);
    final dias = hoje.difference(diaConexao).inDays;
    final hh = conexao.hour.toString().padLeft(2, '0');
    final mm = conexao.minute.toString().padLeft(2, '0');
    if (dias == 0) return ('visto por último hoje às $hh:$mm', cinza);
    if (dias == 1) return ('visto por último ontem às $hh:$mm', cinza);
    final dd = conexao.day.toString().padLeft(2, '0');
    final mes = conexao.month.toString().padLeft(2, '0');
    return (
      'visto por último em $dd/$mes/${conexao.year} às $hh:$mm',
      cinza
    );
  }

  /// Etiqueta de dia estilo WhatsApp: Hoje / Ontem / dd/MM/yyyy.
  String _etiquetaDia(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(data.year, data.month, data.day);
    final dias = hoje.difference(dia).inDays;
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Ontem';
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    return '$dd/$mm/${data.year}';
  }

  String _mensagemErroBanco(String code, String message) {
    final msg = message.toLowerCase();
    if (code == '42501' ||
        msg.contains('row-level security') ||
        msg.contains('permission denied')) {
      return 'Sem permissão (RLS). Rode o SQL docs/sql/chat.sql no Supabase.';
    }
    if (code == '42P01' ||
        msg.contains('does not exist') ||
        msg.contains('relation') ||
        msg.contains('schema cache')) {
      return 'Tabela do chat não encontrada. Rode o SQL docs/sql/chat.sql no Supabase.';
    }
    return 'Não foi possível abrir a conversa ($code). Tente de novo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatBackground,
      appBar: _buildBarraContato(),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : _erroCarregamento != null && _mensagens.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _erroCarregamento!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dica: rode docs/sql/chat.sql no SQL Editor do Supabase.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black38, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _carregando = true;
                              _erroCarregamento = null;
                            });
                            _inicializarChat();
                          },
                          child: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _buildListaMensagens()),
                    _buildBarraInput(),
                  ],
                ),
    );
  }

  PreferredSizeWidget _buildBarraContato() {
    final (textoStatus, corStatus) = _textoCorStatusContato();
    final oficioExibido = _oficioContato.trim().isNotEmpty
        ? _oficioContato.trim()
        : widget.oficioPrincipal.trim();
    final mostrarOficio = oficioExibido.isNotEmpty;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade300),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE6EFF2),
            child: _buildAvatarContato(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.nomeProfissional,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: _primaryBlue,
                      size: 16,
                    ),
                  ],
                ),
                if (mostrarOficio || textoStatus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (mostrarOficio)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCEAF4),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _primaryBlue.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              oficioExibido,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _primaryBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (mostrarOficio && textoStatus.isNotEmpty)
                        const SizedBox(width: 8),
                      if (textoStatus.isNotEmpty)
                        Flexible(
                          child: Text(
                            textoStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: corStatus,
                              fontWeight: _contatoOnline
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_vert, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildAvatarContato() {
    if (widget.fotoProfissional.startsWith('http')) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(widget.fotoProfissional),
      );
    }
    return Text(
      obterIniciais(widget.nomeProfissional),
      style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
    );
  }

  /// Monta a lista com divisores de dia estilo WhatsApp.
  /// Retorna widgets intercalando etiqueta (Hoje/Ontem/dd-MM-yyyy) + balões.
  List<Widget> _construirItensComDivisoresDeDia() {
    final itens = <Widget>[];
    String? etiquetaAtual;
    for (final mensagem in _mensagens) {
      final etiqueta = _etiquetaDia(mensagem.dataEnvio);
      if (etiqueta != etiquetaAtual) {
        etiquetaAtual = etiqueta;
        itens.add(_buildDivisorDia(etiqueta));
      }
      itens.add(_buildBalaoMensagem(mensagem));
    }
    return itens;
  }

  Widget _buildDivisorDia(String etiqueta) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2F3FD),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaMensagens() {
    if (_mensagens.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma mensagem ainda.\nEnvie a primeira!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      );
    }

    final itens = _construirItensComDivisoresDeDia();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: itens.length,
      itemBuilder: (context, index) => itens[index],
    );
  }

  Widget _buildBalaoMensagem(_Mensagem mensagem) {
    final ehMinha = mensagem.ehRemetente;

    return Align(
      alignment: ehMinha ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: ehMinha ? _myMessageColor : _otherMessageColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(ehMinha ? 12 : 0),
            bottomRight: Radius.circular(ehMinha ? 0 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensagem.conteudo,
              style: TextStyle(
                fontSize: 14,
                color: ehMinha ? _myMessageTextColor : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(mensagem.dataEnvio),
                  style: TextStyle(
                    fontSize: 11,
                    color: ehMinha
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.grey.shade600,
                  ),
                ),
                if (ehMinha) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mensagemController,
                        decoration: InputDecoration(
                          hintText: 'Mensagem',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.camera_alt, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _enviando
                  ? null
                  : (_temTexto ? _enviarMensagem : _onGravarAudio),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: _enviando
                        ? const SizedBox(
                            key: ValueKey('enviando'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _temTexto ? Icons.send : Icons.mic,
                            key: ValueKey(_temTexto ? 'enviar' : 'mic'),
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensagem {
  final int id;
  final String conteudo;
  final DateTime dataEnvio;
  final bool ehRemetente;

  _Mensagem({
    required this.id,
    required this.conteudo,
    required this.dataEnvio,
    required this.ehRemetente,
  });
}