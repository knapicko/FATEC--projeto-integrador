import 'dart:async';

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import 'services/chat_anexos_service.dart';
import 'services/verificacao_online.dart';
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
  static const Color _chatBackground = Color(0xFFF6F8FA);

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
  int? _idAudioTocando;
  bool _contatoDigitando = false;
  Timer? _timerDigitandoTimeout;
  Timer? _debounceDigitandoEnvio;

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
    _notificarDigitando(temTexto);
  }

  void _notificarDigitando(bool digitando) {
    _debounceDigitandoEnvio?.cancel();
    _debounceDigitandoEnvio = Timer(const Duration(milliseconds: 250), () {
      if (_canalMensagens != null && _idUsuarioLogado != null) {
        _canalMensagens!.sendBroadcastMessage(
          event: 'digitando',
          payload: {
            'id_usuario': _idUsuarioLogado,
            'digitando': digitando,
          },
        );
      }
    });
  }

  void _onGravarAudio() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gravação de áudio em breve.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Abre o menu de anexos: foto da galeria, câmera ou documento.
  Future<void> _abrirAnexos() async {
    if (_enviando) return;
    if (_idConversa == null || _idUsuarioLogado == null) {
      _mostrarAviso('Aguarde o carregamento da conversa.');
      return;
    }

    final opcao = await showModalBottomSheet<_OpcaoAnexo>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: _primaryBlue,
              ),
              title: const Text('Foto da galeria'),
              onTap: () => Navigator.pop(sheetContext, _OpcaoAnexo.galeria),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: _primaryBlue,
              ),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(sheetContext, _OpcaoAnexo.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.attach_file_rounded,
                color: _primaryBlue,
              ),
              title: const Text('Documento'),
              subtitle: const Text('PDF, planilha, texto...'),
              onTap: () => Navigator.pop(sheetContext, _OpcaoAnexo.documento),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || opcao == null) return;
    if (opcao == _OpcaoAnexo.galeria) {
      await _enviarImagem(ImageSource.gallery);
    } else if (opcao == _OpcaoAnexo.camera) {
      await _enviarImagem(ImageSource.camera);
    } else {
      await _enviarDocumento();
    }
  }

  /// Escolhe uma foto (galeria ou câmera) e a envia como anexo do chat.
  Future<void> _enviarImagem(ImageSource origem) async {
    try {
      final imagem = await ImagePicker().pickImage(
        source: origem,
        imageQuality: 80,
      );
      if (imagem == null) return;

      await _enviarAnexo(
        nomeArquivo: imagem.name.trim().isEmpty ? 'foto.jpg' : imagem.name,
        ehImagem: true,
        enviar: () => ChatAnexosService.enviarImagem(
          idConversa: _idConversa!,
          idUsuarioLogado: _idUsuarioLogado!,
          imagem: imagem,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao escolher foto: $e');
      _mostrarAviso('Não foi possível abrir a galeria/câmera.');
    }
  }

  /// Escolhe um arquivo (PDF, planilha, etc.) e o envia como anexo do chat.
  Future<void> _enviarDocumento() async {
    try {
      final arquivo = await FilePicker.pickFile();
      if (arquivo == null) return;

      await _enviarAnexo(
        nomeArquivo: arquivo.name,
        ehImagem: ChatAnexosService.ehImagem(arquivo.name),
        enviar: () => ChatAnexosService.enviarDocumento(
          idConversa: _idConversa!,
          idUsuarioLogado: _idUsuarioLogado!,
          nomeArquivo: arquivo.name,
          caminhoLocal: arquivo.path,
          leitorBytes: arquivo.readAsBytes,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao escolher documento: $e');
      _mostrarAviso('Não foi possível abrir o seletor de arquivos.');
    }
  }

  /// Mostra a bolha otimista, faz o upload no bucket e replaceia pela mensagem real.
  Future<void> _enviarAnexo({
    required String nomeArquivo,
    required bool ehImagem,
    required Future<ResultadoEnvioAnexo> Function() enviar,
  }) async {
    if (_idConversa == null || _idUsuarioLogado == null || _enviando) return;

    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final otimista = _Mensagem(
      id: tempId,
      conteudo: ehImagem ? '' : nomeArquivo,
      dataEnvio: DateTime.now(),
      ehRemetente: true,
      tipoMensagem: ehImagem ? 'Imagem' : 'Documento',
      lida: false,
      enviando: true,
    );
    setState(() {
      _enviando = true;
      _mensagens = [..._mensagens, otimista];
    });
    _scrollToBottom();

    try {
      final resultado = await enviar();
      if (!mounted) return;

      if (resultado.sucesso && resultado.linha != null) {
        final real =
            _mensagemDoMap(resultado.linha!) ??
            _Mensagem(
              id: tempId,
              conteudo: nomeArquivo,
              dataEnvio: DateTime.now(),
              ehRemetente: true,
              tipoMensagem: ehImagem ? 'Imagem' : 'Documento',
              lida: false,
            );
        setState(() {
          _mensagens = _mensagens
              .map((m) => m.id == tempId ? real : m)
              .toList();
        });
        _scrollToBottom();
      } else {
        setState(() {
          _mensagens = _mensagens.where((m) => m.id != tempId).toList();
        });
        _mostrarAviso(resultado.erro ?? 'Não foi possível enviar o anexo.');
      }
    } catch (e) {
      debugPrint('Erro ao enviar anexo: $e');
      if (!mounted) return;
      setState(() {
        _mensagens = _mensagens.where((m) => m.id != tempId).toList();
      });
      _mostrarAviso('Não foi possível enviar o anexo. Tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarAviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Abre o documento anexado em outro aplicativo; se falhar, copia o link.
  Future<void> _abrirDocumento(String url, String nome) async {
    if (url.isEmpty) {
      _mostrarAviso('Link do documento indisponível.');
      return;
    }
    try {
      final abriu = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (abriu) return;
      throw Exception('Falha ao abrir o documento');
    } catch (e) {
      debugPrint('Erro ao abrir documento: $e');
      await Clipboard.setData(ClipboardData(text: url));
      _mostrarAviso('Não foi possível abrir "$nome". Link copiado.');
    }
  }

  void _abrirCriarPedido() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Criar novo pedido/orçamento em breve.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _visualizarImagemEmTelaCheia(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingMensagens?.cancel();
    _pollingMensagens = null;
    _timerStatusContato?.cancel();
    _timerStatusContato = null;
    _timerDigitandoTimeout?.cancel();
    _debounceDigitandoEnvio?.cancel();
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
      if (_oficioContato.trim().isEmpty ||
          _oficioContato.trim().toLowerCase() == 'conversa') {
        await _carregarOficioContato();
      }
      await _carregarMensagens();
      await _marcarRecebidasComoLidas();
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
      if (mounted) {
        setState(() => _carregando = false);
        _rolarParaFim(animado: false);
      }
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
        if (mounted) setState(() => _souProfissionalNaConversa = false);
        return;
      }
      if (fkProfissional != null) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', fkProfissional)
            .maybeSingle();
        final fkUsuarioProf = (dadosProf?['fk_usuario'] as num?)?.toInt();
        if (mounted) {
          setState(() => _souProfissionalNaConversa = fkUsuarioProf == _idUsuarioLogado);
        }
        return;
      }
      final perfilProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', _idUsuarioLogado!)
          .maybeSingle();
      if (perfilProf != null && mounted) {
        setState(() => _souProfissionalNaConversa = true);
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
      List<Map<String, dynamic>> mensagens;
      try {
        mensagens = await _supabase
            .from('mensagens')
            .select(
              'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem, url_arquivo, legenda, duracao_audio',
            )
            .eq('fk_conversa', _idConversa!)
            .order('data_envio', ascending: true);
      } catch (_) {
        try {
          mensagens = await _supabase
              .from('mensagens')
              .select(
                'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem',
              )
              .eq('fk_conversa', _idConversa!)
              .order('data_envio', ascending: true);
        } catch (_) {
          mensagens = await _supabase
              .from('mensagens')
              .select(
                'id_mensagem, conteudo, data_envio, fk_remitente_usuario',
              )
              .eq('fk_conversa', _idConversa!)
              .order('data_envio', ascending: true);
        }
      }

      final List<_Mensagem> lista = [];
      for (final msg in mensagens) {
        final m = _mensagemDoMap(msg);
        if (m != null) lista.add(m);
      }

      if (!mounted) return;
      setState(() {
        _mensagens = lista;
        _erroCarregamento = null;
      });
      _rolarParaFim(animado: false);
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

    // Escuta novas mensagens e atualizações (como visto/lida) em tempo real
    canal.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'mensagens',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'fk_conversa',
        value: _idConversa,
      ),
      callback: (payload) {
        if (!mounted) return;

        if (payload.eventType == PostgresChangeEvent.insert) {
          final row = payload.newRecord;
          if (row.isEmpty) return;
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
          if (!nova.ehRemetente) {
            _marcarRecebidasComoLidas();
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final row = payload.newRecord;
          if (row.isEmpty) return;
          final atualizada = _mensagemDoMap(row);
          if (atualizada == null) return;
          setState(() {
            _mensagens = _mensagens
                .map((m) => m.id == atualizada.id ? atualizada : m)
                .toList();
          });
        }
      },
    );

    // Escuta broadcast de digitação em tempo real do contato
    canal.onBroadcast(
      event: 'digitando',
      callback: (payload) {
        if (!mounted) return;
        final idRemetente = (payload['id_usuario'] as num?)?.toInt();
        final digitando = payload['digitando'] == true;
        if (idRemetente != _idUsuarioLogado) {
          _timerDigitandoTimeout?.cancel();
          setState(() => _contatoDigitando = digitando);
          if (digitando) {
            _scrollToBottom();
            _timerDigitandoTimeout = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _contatoDigitando = false);
            });
          }
        }
      },
    );

    // Polling silencioso a cada 4s
    _pollingMensagens = Timer.periodic(const Duration(seconds: 4), (_) {
      _buscarMensagensSilencioso();
    });

    // Atualiza o status online a cada 4s para detectar rapidamente fechamento do app
    _timerStatusContato = Timer.periodic(const Duration(seconds: 4), (_) {
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
      tipoMensagem: msg['tipo_mensagem']?.toString() ?? 'Texto',
      lida: msg['lida'] == true,
      urlArquivo: msg['url_arquivo']?.toString(),
      legenda: msg['legenda']?.toString(),
      duracaoAudio: msg['duracao_audio']?.toString(),
    );
  }

  Future<void> _buscarMensagensSilencioso() async {
    if (_idConversa == null || !mounted) return;
    try {
      List<Map<String, dynamic>> mensagens;
      try {
        mensagens = await _supabase
            .from('mensagens')
            .select(
              'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem, url_arquivo, legenda, duracao_audio',
            )
            .eq('fk_conversa', _idConversa!)
            .order('data_envio', ascending: true);
      } catch (_) {
        try {
          mensagens = await _supabase
              .from('mensagens')
              .select(
                'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem',
              )
              .eq('fk_conversa', _idConversa!)
              .order('data_envio', ascending: true);
        } catch (_) {
          mensagens = await _supabase
              .from('mensagens')
              .select(
                'id_mensagem, conteudo, data_envio, fk_remitente_usuario',
              )
              .eq('fk_conversa', _idConversa!)
              .order('data_envio', ascending: true);
        }
      }

      final lista = <_Mensagem>[];
      for (final msg in mensagens) {
        final m = _mensagemDoMap(msg);
        if (m != null) lista.add(m);
      }
      if (!mounted) return;

      final otimistas = _mensagens.where((m) => m.id < 0).toList();
      final mesclada = [...lista];
      for (final o in otimistas) {
        final jaConfirmada = lista.any(
          (m) => m.conteudo == o.conteudo && m.ehRemetente,
        );
        if (!jaConfirmada) mesclada.add(o);
      }
      mesclada.sort((a, b) {
        if (a.id < 0 && b.id < 0) return a.dataEnvio.compareTo(b.dataEnvio);
        if (a.id < 0) return 1;
        if (b.id < 0) return -1;
        return a.dataEnvio.compareTo(b.dataEnvio);
      });

      var mudou = mesclada.length != _mensagens.length;
      if (!mudou) {
        for (var i = 0; i < mesclada.length; i++) {
          if (mesclada[i].id != _mensagens[i].id ||
              mesclada[i].lida != _mensagens[i].lida) {
            mudou = true;
            break;
          }
        }
      }

      if (mudou) {
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
    _notificarDigitando(false);

    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final msgOtimista = _Mensagem(
      id: tempId,
      conteudo: textoParaEnviar,
      dataEnvio: DateTime.now(),
      ehRemetente: true,
      tipoMensagem: 'Texto',
      lida: false,
    );
    setState(() => _mensagens = [..._mensagens, msgOtimista]);
    _scrollToBottom();

    try {
      Map<String, dynamic>? inserida;
      try {
        inserida = await _supabase
            .from('mensagens')
            .insert({
              'fk_conversa': _idConversa!,
              'tipo_mensagem': 'Texto',
              'conteudo': textoParaEnviar,
              'fk_remitente_usuario': _idUsuarioLogado!,
              'lida': false,
            })
            .select(
              'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem',
            )
            .maybeSingle();
      } on PostgrestException {
        inserida = await _supabase
            .from('mensagens')
            .insert({
              'fk_conversa': _idConversa!,
              'tipo_mensagem': 'Texto',
              'conteudo': textoParaEnviar,
              'fk_remitente_usuario': _idUsuarioLogado!,
            })
            .select('id_mensagem, conteudo, data_envio, fk_remitente_usuario')
            .maybeSingle();
      }

      if (!mounted) return;
      if (inserida != null) {
        final real = _mensagemDoMap(inserida) ??
            _Mensagem(
              id: (inserida['id_mensagem'] as num?)?.toInt() ?? tempId,
              conteudo: textoParaEnviar,
              dataEnvio: DateTime.now(),
              ehRemetente: true,
              tipoMensagem: 'Texto',
              lida: false,
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
    _rolarParaFim();
  }

  Future<void> _carregarOficioContato() async {
    try {
      if (_souProfissionalNaConversa) return;
      int? idProf = widget.idProfissional;
      if (idProf == null && _idConversa != null) {
        final conversa = await _supabase
            .from('conversas')
            .select('fk_profissional')
            .eq('id_conversa', _idConversa!)
            .maybeSingle();
        idProf = (conversa?['fk_profissional'] as num?)?.toInt();
      }
      if (idProf == null) return;

      final assocs = await _supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', idProf)
          .limit(1);
      if (assocs.isEmpty) return;

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
      }
    } catch (e) {
      debugPrint('Erro ao carregar ofício do contato: $e');
    }
  }

  Future<void> _carregarStatusContato() async {
    if (_idConversa == null) return;
    try {
      int? idUsuarioContato;
      if (_souProfissionalNaConversa) {
        final conversa = await _supabase
            .from('conversas')
            .select('fk_usuario')
            .eq('id_conversa', _idConversa!)
            .maybeSingle();
        idUsuarioContato = (conversa?['fk_usuario'] as num?)?.toInt();
      } else {
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

  bool get _contatoOnline =>
      VerificacaoOnline.estaOnline(_ultimaConexaoContato);

  Future<void> _marcarRecebidasComoLidas() async {
    if (_idConversa == null || _idUsuarioLogado == null) return;
    try {
      await _supabase
          .from('mensagens')
          .update({'lida': true})
          .eq('fk_conversa', _idConversa!)
          .neq('fk_remitente_usuario', _idUsuarioLogado!)
          .eq('lida', false);
    } catch (e) {
      debugPrint('Erro ao marcar mensagens como lidas: $e');
    }
  }

  String _etiquetaDia(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(data.year, data.month, data.day);
    final dias = hoje.difference(dia).inDays;
    if (dias == 0) return 'HOJE';
    if (dias == 1) return 'ONTEM';
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    return '$dd/$mm/${data.year}';
  }

  String _mensagemErroBanco(String code, String message) {
    final msg = message.toLowerCase();
    if (code == '42501' ||
        msg.contains('row-level security') ||
        msg.contains('permission denied')) {
      return 'Sem permissão (RLS). Rode o script SQL do chat no Supabase.';
    }
    if (code == '42P01' ||
        msg.contains('does not exist') ||
        msg.contains('relation') ||
        msg.contains('schema cache')) {
      return 'Tabela do chat não encontrada no Supabase.';
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
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _erroCarregamento!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
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
    final oficioExibido = _oficioContato.trim().isNotEmpty
        ? _oficioContato.trim()
        : widget.oficioPrincipal.trim();
    final mostrarOficio = oficioExibido.isNotEmpty &&
        oficioExibido.toLowerCase() != 'conversa' &&
        oficioExibido.toLowerCase() != 'cliente';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE5E7EB)),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF1F2937)),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAvatarContato(),
                if (_contatoOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
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
                          color: Color(0xFF111827),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: _primaryBlue,
                      size: 17,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (mostrarOficio) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F6FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          oficioExibido.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                    if (_contatoOnline) ...[
                      if (mostrarOficio) const SizedBox(width: 6),
                      const Text(
                        '• Online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
        ),
      ],
    );
  }

  Widget _buildAvatarContato() {
    final foto = widget.fotoProfissional.trim();
    if (foto.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(foto),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFDCE5EE),
      child: Text(
        obterIniciais(widget.nomeProfissional),
        style: const TextStyle(
          color: Color(0xFF5E6F7E),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMiniAvatarContato() {
    final foto = widget.fotoProfissional.trim();
    if (foto.startsWith('http')) {
      return CircleAvatar(
        radius: 13,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(foto),
      );
    }
    return CircleAvatar(
      radius: 13,
      backgroundColor: const Color(0xFFDCE5EE),
      child: Text(
        obterIniciais(widget.nomeProfissional),
        style: const TextStyle(
          color: Color(0xFF5E6F7E),
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  List<Widget> _construirItensComDivisoresDeDia(List<_Mensagem> mensagens) {
    final itens = <Widget>[];
    String? etiquetaAtual;
    for (final mensagem in mensagens) {
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  List<_Mensagem> get _mensagensExibidas {
    // Sem nada estático: se não há mensagens no Supabase, a lista é vazia.
    return _mensagens;
  }

  Widget _buildListaMensagens() {
    final exibidas = _mensagensExibidas;
    if (exibidas.isEmpty && !_carregando) {
      if (_contatoDigitando) {
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: const [_IndicadorDigitando()],
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                  Icons.chat_bubble_outline,
                  size: 36,
                  color: Color(0xFF0FB3FF),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma mensagem ainda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Envie a primeira mensagem para iniciar a conversa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }
    final itens = _construirItensComDivisoresDeDia(exibidas);
    if (_contatoDigitando) {
      itens.add(const _IndicadorDigitando());
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: itens.length,
      itemBuilder: (context, index) => itens[index],
    );
  }

  Widget _buildBalaoMensagem(_Mensagem mensagem) {
    if (mensagem.enviando) {
      return _buildBalaoEnviando(mensagem);
    }

    final tipo = mensagem.tipoMensagem.toLowerCase();
    if (tipo == 'imagem') {
      return _buildBalaoImagem(mensagem);
    }
    if (tipo == 'documento') {
      return _buildBalaoDocumento(mensagem);
    }
    if (tipo == 'audio') {
      return _buildBalaoAudio(mensagem);
    }
    return mensagem.ehRemetente
        ? _buildBalaoTextoEnviado(mensagem)
        : _buildBalaoTextoRecebido(mensagem);
  }

  /// Resolve nome e URL de uma mensagem do tipo documento.
  ({String nome, String url}) _dadosDocumento(_Mensagem mensagem) {
    final legenda = mensagem.legenda?.trim() ?? '';
    final conteudo = mensagem.conteudo.trim();
    final urlArquivo = mensagem.urlArquivo?.trim() ?? '';
    final separado = ChatAnexosService.separarConteudoDocumento(conteudo);

    final url = urlArquivo.isNotEmpty
        ? urlArquivo
        : (separado?.url ??
              (conteudo.startsWith('http') ? conteudo : ''));

    final nome = legenda.isNotEmpty
        ? legenda
        : (separado != null && separado.nome.isNotEmpty
              ? separado.nome
              : 'Documento');

    return (nome: nome, url: url);
  }

  /// Bolha temporária exibida enquanto o anexo é enviado para o Supabase.
  Widget _buildBalaoEnviando(_Mensagem mensagem) {
    final texto = mensagem.tipoMensagem.toLowerCase() == 'imagem'
        ? 'Enviando foto...'
        : 'Enviando arquivo...';

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalaoTextoEnviado(_Mensagem mensagem) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: _primaryBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensagem.conteudo,
              style: const TextStyle(
                fontSize: 14.5,
                color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  mensagem.lida ? Icons.done_all : Icons.done,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalaoTextoRecebido(_Mensagem mensagem) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensagem.conteudo,
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(mensagem.dataEnvio),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalaoImagem(_Mensagem mensagem) {
    final fotoUrl = mensagem.urlArquivo?.trim().isNotEmpty == true
        ? mensagem.urlArquivo!.trim()
        : (mensagem.conteudo.trim().startsWith('http')
            ? mensagem.conteudo.trim()
            : '');
    // Sem URL real vinda do Supabase: não mostra imagem estática, usa texto.
    if (fotoUrl.isEmpty) {
      return mensagem.ehRemetente
          ? _buildBalaoTextoEnviado(mensagem)
          : _buildBalaoTextoRecebido(mensagem);
    }
    return Align(
      alignment: mensagem.ehRemetente
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _visualizarImagemEmTelaCheia(fotoUrl),
                      child: Image.network(
                        fotoUrl,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _visualizarImagemEmTelaCheia(fotoUrl),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(mensagem.dataEnvio),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (mensagem.ehRemetente) ...[
                              const SizedBox(width: 4),
                              Icon(
                                mensagem.lida ? Icons.done_all : Icons.done,
                                size: 13,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (mensagem.legenda != null && mensagem.legenda!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    mensagem.legenda!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalaoDocumento(_Mensagem mensagem) {
    final dados = _dadosDocumento(mensagem);
    final enviada = mensagem.ehRemetente;
    final extensao = ChatAnexosService.extensaoDe(dados.nome).toUpperCase();

    return Align(
      alignment: enviada ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrirDocumento(dados.url, dados.nome),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _iconeDocumento(dados.nome),
                        color: _primaryBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dados.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            extensao.isEmpty
                                ? 'Toque para abrir'
                                : '$extensao • Toque para abrir',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(mensagem.dataEnvio),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    if (enviada) ...[
                      const SizedBox(width: 4),
                      Icon(
                        mensagem.lida ? Icons.done_all : Icons.done,
                        size: 14,
                        color: _primaryBlue,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ícone exibido no cartão do documento, de acordo com a extensão.
  IconData _iconeDocumento(String nome) {
    switch (ChatAnexosService.extensaoDe(nome)) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildBalaoAudio(_Mensagem mensagem) {
    final tocando = _idAudioTocando == mensagem.id;
    final barras = [10, 16, 22, 18, 14, 26, 30, 20, 14, 18, 24, 16, 12, 8, 14];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _idAudioTocando = tocando ? null : mensagem.id;
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: _primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tocando ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(barras.length, (index) {
                        final ehParteTocada = index < 6;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          width: 2.8,
                          height: barras[index].toDouble(),
                          decoration: BoxDecoration(
                            color: ehParteTocada
                                ? _primaryBlue
                                : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      mensagem.duracaoAudio ?? '0:42 / 1:32',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: _buildMiniAvatarContato(),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(mensagem.dataEnvio),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEDF2F7), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _abrirAnexos,
              icon: const Icon(
                Icons.attach_file_rounded,
                color: Color(0xFF64748B),
                size: 26,
              ),
              splashRadius: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.only(left: 18, right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mensagemController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Mensagem...',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      onPressed: _abrirAnexos,
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        color: Color(0xFF94A3B8),
                        size: 23,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    if (_souProfissionalNaConversa) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _abrirCriarPedido,
                        icon: const Icon(
                          Icons.receipt_long_outlined,
                          color: Color(0xFF94A3B8),
                          size: 23,
                        ),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _enviando
                  ? null
                  : (_temTexto ? _enviarMensagem : _onGravarAudio),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _temTexto ? Icons.send_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: _temTexto ? 22 : 25,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rolarParaFim({bool animado = true}) {
    if (_mensagens.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      try {
        final pos = _scrollController.position.maxScrollExtent;
        if (animado) {
          _scrollController.animateTo(
            pos,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(pos);
        }
      } catch (_) {}

      // Segundo frame de segurança para acomodar layout completo
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!mounted || !_scrollController.hasClients) return;
        try {
          final novoMax = _scrollController.position.maxScrollExtent;
          if (novoMax > _scrollController.offset) {
            if (animado) {
              _scrollController.animateTo(
                novoMax,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            } else {
              _scrollController.jumpTo(novoMax);
            }
          }
        } catch (_) {}
      });
    });
  }
}

class _Mensagem {
  final int id;
  final String conteudo;
  final DateTime dataEnvio;
  final bool ehRemetente;
  final String tipoMensagem;
  final bool lida;
  final String? urlArquivo;
  final String? legenda;
  final String? duracaoAudio;

  /// `true` enquanto o anexo ainda está subindo para o Supabase Storage.
  final bool enviando;

  _Mensagem({
    required this.id,
    required this.conteudo,
    required this.dataEnvio,
    required this.ehRemetente,
    this.tipoMensagem = 'Texto',
    this.lida = false,
    this.urlArquivo,
    this.legenda,
    this.duracaoAudio,
    this.enviando = false,
  });
}

/// Opções do menu de anexos do chat.
enum _OpcaoAnexo { galeria, camera, documento }

/// Animação de 3 pontinhos brancos pulando indicando digitação do contato
class _IndicadorDigitando extends StatefulWidget {
  const _IndicadorDigitando();

  @override
  State<_IndicadorDigitando> createState() => _IndicadorDigitandoState();
}

class _IndicadorDigitandoState extends State<_IndicadorDigitando>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0FB3FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final t = (_controller.value - delay) % 1.0;
                final translateY =
                    -4.0 * (t < 0.5 ? (1.0 - (2.0 * (t - 0.25)).abs()) : 0.0);

                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}