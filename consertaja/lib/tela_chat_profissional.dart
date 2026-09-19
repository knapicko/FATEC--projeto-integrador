import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart'
    show FilePicker, FileType, WindowsOptions;
import 'package:file_selector/file_selector.dart'
    show XTypeGroup, openFile;
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, MissingPluginException;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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

  /// Quando informado, o chat é da EMPRESA (grupo_empresa) e não do
  /// profissional individual: a conversa usa fk_grupo_empresa.
  final int? idGrupoEmpresa;

  /// Permite abrir um chat já existente a partir da lista de mensagens.
  final int? idConversa;

  const TelaChatProfissional({
    super.key,
    required this.nomeProfissional,
    required this.fotoProfissional,
    required this.oficioPrincipal,
    this.idProfissional,
    this.idGrupoEmpresa,
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
  bool _souEmpresaNaConversa = false;
  int? _idGrupoEmpresaConversa;
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

  // ---- Gravação de áudio (estilo WhatsApp) ----
  final _gravador = AudioRecorder();
  bool _gravando = false;
  int _segundosGravando = 0;
  String _caminhoGravacao = '';
  String _extensaoGravacao = 'm4a';
  double _deslizeCancelarDx = 0;
  Timer? _timerGravacao;
  StreamSubscription? _subAmplitude;
  final ValueNotifier<double> _nivelGravacao = ValueNotifier(0);

  // ---- Reprodução de áudio ----
  final _player = AudioPlayer();
  Duration _posicaoTocando = Duration.zero;
  Duration _duracaoTocando = Duration.zero;
  bool _audioPausado = false;

  @override
  void initState() {
    super.initState();
    _mensagemController.addListener(_atualizarEstadoTexto);
    _configurarPlayer();
    _inicializarChat();
  }

  /// Escutas do player para atualizar o balão de áudio em reprodução.
  void _configurarPlayer() {
    _player.onDurationChanged.listen((duracao) {
      if (!mounted) return;
      setState(() => _duracaoTocando = duracao);
    });
    _player.onPositionChanged.listen((posicao) {
      if (!mounted) return;
      setState(() => _posicaoTocando = posicao);
    });
    _player.onPlayerStateChanged.listen((estado) {
      if (!mounted) return;
      if (estado == PlayerState.completed) {
        setState(() {
          _idAudioTocando = null;
          _audioPausado = false;
          _posicaoTocando = Duration.zero;
        });
      }
    });
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

  /// Inicia a gravação de áudio (estilo WhatsApp: o input vira a barra de
  /// gravação com cronômetro, cancelar e enviar).
  Future<void> _onGravarAudio() async {
    if (_gravando || _enviando) return;
    if (_idConversa == null || _idUsuarioLogado == null) {
      _mostrarAviso('Aguarde o carregamento da conversa.');
      return;
    }

    try {
      if (!await _gravador.hasPermission()) {
        _mostrarAviso(
          'Permita o acesso ao microfone para gravar mensagens de áudio.',
        );
        return;
      }

      // Na web o `path` é ignorado (stop() devolve um blob URL); no mobile
      // gravamos direto num arquivo temporário .m4a.
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        _caminhoGravacao =
            '${dir.path}/audio_chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _extensaoGravacao = 'm4a';
      } else {
        _caminhoGravacao = '';
        final suportaAac =
            await _gravador.isEncoderSupported(AudioEncoder.aacLc);
        _extensaoGravacao = suportaAac ? 'm4a' : 'webm';
      }

      var encoder = AudioEncoder.aacLc;
      if (kIsWeb && _extensaoGravacao == 'webm') {
        encoder = AudioEncoder.opus;
      }

      await _gravador.start(
        RecordConfig(encoder: encoder),
        path: _caminhoGravacao,
      );

      _segundosGravando = 0;
      _subAmplitude?.cancel();
      _subAmplitude = _gravador
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen((amplitude) {
            // amplitude.current vai de 0 (silêncio) a -60dB (máximo).
            final nivel = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
            _nivelGravacao.value = nivel;
          });

      if (!mounted) return;
      setState(() {
        _gravando = true;
      });
      FocusScope.of(context).unfocus();
      _timerGravacao = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _segundosGravando += 1);
      });
    } catch (e) {
      debugPrint('Erro ao iniciar gravação: $e');
      if (mounted) {
        if (e is MissingPluginException) {
          _mostrarAviso(
            'Feche o app por completo e rode novamente (flutter run) para '
            'registrar o módulo de gravação.',
          );
        } else {
          _mostrarAviso('Não foi possível iniciar a gravação de áudio.');
        }
      }
    }
  }

  /// Para a gravação: [enviar] = true envia o áudio, false cancela e apaga.
  Future<void> _pararGravacao({required bool enviar}) async {
    if (!_gravando) return;

    _timerGravacao?.cancel();
    _timerGravacao = null;
    await _subAmplitude?.cancel();
    _subAmplitude = null;
    _nivelGravacao.value = 0;

    final emWeb = kIsWeb;
    final caminho = _caminhoGravacao;
    final extensao = _extensaoGravacao;
    final segundos = _segundosGravando;
    _caminhoGravacao = '';
    if (mounted) setState(() => _gravando = false);

    // stop() devolve o caminho do arquivo (mobile) ou um blob URL (web).
    String? resultado;
    try {
      resultado = await _gravador.stop();
    } catch (e) {
      debugPrint('Erro ao parar gravação: $e');
    }

    // Cancelamento (ou gravação curta demais): apaga o arquivo.
    if (!enviar || segundos < 1) {
      if (!emWeb) {
        try {
          final arquivo = File(caminho);
          if (await arquivo.exists()) await arquivo.delete();
        } catch (_) {}
      }
      return;
    }

    try {
      final Uint8List bytes;
      if (emWeb) {
        // Web: baixa o áudio do blob gerado pelo navegador.
        final url = resultado;
        if (url == null || url.isEmpty) {
          throw Exception('Gravação vazia.');
        }
        bytes = await http.readBytes(Uri.parse(url));
      } else {
        bytes = await File(caminho).readAsBytes();
        try {
          final arquivo = File(caminho);
          if (await arquivo.exists()) await arquivo.delete();
        } catch (_) {}
      }
      await _enviarAnexoAudio(
        bytes: bytes,
        duracaoSegundos: segundos,
        extensao: extensao,
      );
    } catch (e) {
      debugPrint('Erro ao ler áudio gravado: $e');
      _mostrarAviso('Não foi possível enviar o áudio. Tente de novo.');
    }
  }

  /// Mostra a bolha otimista, faz o upload e replaceia pela mensagem real.
  Future<void> _enviarAnexoAudio({
    required Uint8List bytes,
    required int duracaoSegundos,
    String extensao = 'm4a',
  }) async {
    if (_idConversa == null || _idUsuarioLogado == null || _enviando) return;

    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final otimista = _Mensagem(
      id: tempId,
      conteudo: '',
      dataEnvio: DateTime.now(),
      ehRemetente: true,
      tipoMensagem: 'Audio',
      lida: false,
      enviando: true,
    );
    setState(() {
      _enviando = true;
      _mensagens = [..._mensagens, otimista];
    });
    _scrollToBottom();

    try {
      final resultado = await ChatAnexosService.enviarAudio(
        idConversa: _idConversa!,
        idUsuarioLogado: _idUsuarioLogado!,
        bytes: bytes,
        duracaoSegundos: duracaoSegundos,
        extensao: extensao,
        contentType: extensao == 'webm' ? 'audio/webm' : 'audio/mp4',
      );
      if (!mounted) return;

      if (resultado.sucesso && resultado.linha != null) {
        final real = _mensagemDoMap(resultado.linha!) ?? otimista;
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
        _mostrarAviso(resultado.erro ?? 'Não foi possível enviar o áudio.');
      }
    } catch (e) {
      debugPrint('Erro ao enviar áudio: $e');
      if (!mounted) return;
      setState(() {
        _mensagens = _mensagens.where((m) => m.id != tempId).toList();
      });
      _mostrarAviso('Não foi possível enviar o áudio. Tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Formata segundos em `m:ss`.
  static String _formatarDuracao(int segundos) {
    final m = segundos ~/ 60;
    final s = segundos % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Toca ou pausa o áudio de uma mensagem no balão.
  Future<void> _alternarTocarAudio(_Mensagem mensagem) async {
    final url = (mensagem.urlArquivo?.trim().isNotEmpty ?? false)
        ? mensagem.urlArquivo!.trim()
        : mensagem.conteudo.trim();
    if (url.isEmpty) {
      _mostrarAviso('Áudio indisponível.');
      return;
    }

    try {
      if (_idAudioTocando == mensagem.id) {
        // Mesma mensagem: pausa ou retoma de onde parou.
        if (_audioPausado) {
          await _player.resume();
          if (mounted) setState(() => _audioPausado = false);
        } else {
          await _player.pause();
          if (mounted) setState(() => _audioPausado = true);
        }
        return;
      }

      await _player.stop();
      setState(() {
        _idAudioTocando = mensagem.id;
        _audioPausado = false;
        _posicaoTocando = Duration.zero;
      });
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('Erro ao tocar áudio: $e');
      if (mounted) {
        setState(() {
          _idAudioTocando = null;
          _audioPausado = false;
        });
        if (e is MissingPluginException) {
          _mostrarAviso(
            'Feche o app por completo e rode novamente (flutter run) para '
            'registrar o módulo de áudio.',
          );
        } else {
          _mostrarAviso('Não foi possível reproduzir o áudio.');
        }
      }
    }
  }

  /// Botão da câmera (ao lado do input): abre a câmera direto,
  /// sem passar pelo menu de anexos.
  Future<void> _abrirCamera() async {
    if (_enviando) return;
    if (_idConversa == null || _idUsuarioLogado == null) {
      _mostrarAviso('Aguarde o carregamento da conversa.');
      return;
    }
    await _enviarImagem(ImageSource.camera);
  }

  /// Abre o menu de anexos: foto da galeria ou documento.
  /// (A câmera tem botão próprio e abre direto.)
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
      _mostrarAviso('Não foi possível abrir a câmera/galeria.');
    }
  }

  /// Escolhe um arquivo (PDF, planilha, etc.) e o envia como anexo do chat.
  ///
  /// No celular usa o `file_picker`. No Windows usa o `file_selector`
  /// (plugin C++ nativo); se o app foi instalado sem rebuild após adicionar
  /// o plugin, o Windows lança `MissingPluginException` e mostramos um aviso
  /// pedindo rebuild em vez de cair no `file_picker` quebrado.
  Future<void> _enviarDocumento() async {
    String? nomeArquivo;
    String? caminhoLocal;
    Future<Uint8List> Function()? leitorBytes;

    try {
      // No Windows, o file_picker v13 usa o windows_file_picker via FFI, que
      // falha no `flutter run` (UnimplementedError). Vai direto no nativo.
      // (defaultTargetPlatform em vez de dart:io Platform: funciona na web.)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final arquivo = await _escolherDocumentoWindows();
        if (arquivo == null) return;
        nomeArquivo = arquivo.$1;
        caminhoLocal = arquivo.$2;
        leitorBytes = arquivo.$3;
      } else {
        final arquivo = await _escolherDocumentoFilePicker();
        if (arquivo == null) return;
        nomeArquivo = arquivo.$1;
        caminhoLocal = arquivo.$2;
        leitorBytes = arquivo.$3;
      }

      await _enviarAnexo(
        nomeArquivo: nomeArquivo,
        ehImagem: ChatAnexosService.ehImagem(nomeArquivo),
        enviar: () => ChatAnexosService.enviarDocumento(
          idConversa: _idConversa!,
          idUsuarioLogado: _idUsuarioLogado!,
          nomeArquivo: nomeArquivo!,
          caminhoLocal: caminhoLocal,
          leitorBytes: leitorBytes!,
        ),
      );
    } on MissingPluginException catch (e) {
      // App Windows compilado sem o file_selector registrado:
      // é preciso rebuild limpo.
      debugPrint('Plugin nativo ausente (rebuild necessário): $e');
      _mostrarAviso(
        'O app do Windows precisa ser recompilado para abrir arquivos. '
        'Rode: flutter clean e depois flutter run -d windows.',
      );
    } catch (e) {
      debugPrint('Erro ao escolher documento: $e');
      _mostrarAviso('Não foi possível abrir o seletor de arquivos.');
    }
  }

  /// Seletor nativo via `file_selector` (Windows/desktop).
  /// Retorna (nome, caminhoLocal, leitorBytes).
  /// Retorna null se o usuário cancelar. Deixa MissingPluginException
  /// subir para o chamador (significa que o app precisa de rebuild).
  Future<(String, String?, Future<Uint8List> Function())?>
  _escolherDocumentoWindows() async {
    const grupo = XTypeGroup(
      label: 'Documentos e imagens',
      extensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'zip',
        'rar',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );
    final arquivo = await openFile(
      acceptedTypeGroups: [grupo],
      confirmButtonText: 'Escolher documento',
    ).timeout(const Duration(minutes: 2));
    if (arquivo == null) return null;
    final caminho = arquivo.path;
    final nome = caminho.split(RegExp(r'[\\/]')).last;
    if (nome.trim().isEmpty) return null;
    return (
      nome,
      caminho.isEmpty ? null : caminho,
      () async {
        final bytes = await arquivo.readAsBytes();
        return Uint8List.fromList(bytes);
      },
    );
  }

  /// Seletor via `file_picker` (celular + fallback desktop).
  /// Retorna (nome, caminhoLocal, leitorBytes) ou null se cancelar.
  Future<(String, String?, Future<Uint8List> Function())?>
  _escolherDocumentoFilePicker() async {
    final arquivo = await FilePicker.pickFile(
      dialogTitle: 'Escolher documento',
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'zip',
        'rar',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
      // Sem lockParentWindow: no Windows ele pode travar o diálogo
      // do windows_file_picker atrás da janela do app (`flutter run`).
      windowsOptions: const WindowsOptions(lockParentWindow: false),
    );
    if (arquivo == null) return null;
    return (arquivo.name, arquivo.path, arquivo.readAsBytes);
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
    _timerGravacao?.cancel();
    _subAmplitude?.cancel();
    _nivelGravacao.dispose();
    _gravador.dispose();
    _player.dispose();
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
        if (widget.idGrupoEmpresa != null) {
          // Chat da EMPRESA (grupo_empresa): conversa cliente x empresa.
          _souEmpresaNaConversa =
              await _souMembroDoGrupo(widget.idGrupoEmpresa!);
          _idGrupoEmpresaConversa = widget.idGrupoEmpresa;
          await _obterOuCriarConversaEmpresa(widget.idGrupoEmpresa!);
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
      // Primeiro tenta descobrir se a coluna fk_grupo_empresa existe.
      bool temColunaGrupo = true;
      try {
        await _supabase
            .from('conversas')
            .select('id_conversa, fk_usuario, fk_profissional, fk_grupo_empresa')
            .limit(0);
      } catch (_) {
        temColunaGrupo = false;
      }
      final conversa = await _supabase
          .from('conversas')
          .select(temColunaGrupo
              ? 'fk_usuario, fk_profissional, fk_grupo_empresa'
              : 'fk_usuario, fk_profissional')
          .eq('id_conversa', _idConversa!)
          .maybeSingle();
      if (conversa == null) return;
      final fkUsuario = (conversa['fk_usuario'] as num?)?.toInt();
      final fkProfissional = (conversa['fk_profissional'] as num?)?.toInt();
      final fkGrupo = temColunaGrupo
          ? (conversa['fk_grupo_empresa'] as num?)?.toInt()
          : null;
      if (fkGrupo != null) {
        _idGrupoEmpresaConversa = fkGrupo;
        _souEmpresaNaConversa = await _souMembroDoGrupo(fkGrupo);
        // Numa conversa da empresa, o cliente é o fk_usuario.
        if (fkUsuario != null && fkUsuario == _idUsuarioLogado) {
          if (mounted) {
            setState(() {
              _souProfissionalNaConversa = false;
              _souEmpresaNaConversa = false;
            });
          }
          return;
        }
        if (mounted) {
          setState(() => _souProfissionalNaConversa = _souEmpresaNaConversa);
        }
        return;
      }
      _idGrupoEmpresaConversa = null;
      _souEmpresaNaConversa = false;
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

  /// Verifica se o usuário logado é membro do grupo_empresa (dono/funcionário).
  Future<bool> _souMembroDoGrupo(int idGrupo) async {
    try {
      if (_idUsuarioLogado == null) return false;
      final vinculo = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', _idUsuarioLogado!)
          .eq('fk_grupo_empresa', idGrupo)
          .maybeSingle();
      return vinculo != null;
    } catch (e) {
      debugPrint('Erro ao verificar membro do grupo: $e');
      return false;
    }
  }

  /// Abre ou cria a conversa cliente x EMPRESA (fk_grupo_empresa).
  /// Uma conversa por par (fk_usuario cliente, fk_grupo_empresa).
  Future<void> _obterOuCriarConversaEmpresa(int idGrupo) async {
    _souProfissionalNaConversa = _souEmpresaNaConversa;
    // Se quem abre é da empresa, não há cliente definido aqui — a conversa
    // da empresa só pode ser aberta via idConversa (lista de mensagens),
    // onde o fk_usuario já é o cliente. Se sou cliente, crio/busco a minha.
    if (_souEmpresaNaConversa) {
      setState(() {
        _carregando = false;
        _erroCarregamento =
            'Abra a conversa da empresa pela lista de mensagens.';
      });
      _idConversa = null;
      return;
    }

    final conversaExistente = await _supabase
        .from('conversas')
        .select('id_conversa')
        .eq('fk_usuario', _idUsuarioLogado!)
        .eq('fk_grupo_empresa', idGrupo)
        .maybeSingle();

    if (conversaExistente != null) {
      _idConversa = (conversaExistente['id_conversa'] as num?)?.toInt();
    } else {
      // Monta o insert pedindo fk_profissional NULL + fk_grupo_empresa;
      // se o banco antigo ainda exige fk_profissional NOT NULL, cai para o
      // fluxo do chat individual? Não — nesse caso avisa para rodar o SQL.
      try {
        final novaConversa = await _supabase
            .from('conversas')
            .insert({
              'fk_usuario': _idUsuarioLogado!,
              'fk_profissional': null,
              'fk_grupo_empresa': idGrupo,
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
              .eq('fk_grupo_empresa', idGrupo)
              .maybeSingle();
          _idConversa = (conversaCriada?['id_conversa'] as num?)?.toInt();
        } else {
          rethrow;
        }
      }
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
            bool ehOtimista(_Mensagem m) =>
                m.id < 0 &&
                m.ehRemetente == nova.ehRemetente &&
                (m.conteudo == nova.conteudo ||
                    // Anexo em upload: o conteudo otimista ainda é vazio/nome,
                    // casa pelo tipo enquanto `enviando` é verdadeiro.
                    (m.enviando && m.tipoMensagem == nova.tipoMensagem));
            final temOtimista = _mensagens.any(ehOtimista);
            if (temOtimista) {
              var trocou = false;
              _mensagens = _mensagens.map((m) {
                if (!trocou && ehOtimista(m)) {
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
      duracaoAudio: (msg['duracao_audio'] as num?)?.toInt(),
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
            ) ||
            // Anexo em upload: enquanto `enviando`, casa pelo tipo recente.
            (o.enviando &&
                lista.any(
                  (m) =>
                      m.ehRemetente &&
                      m.tipoMensagem == o.tipoMensagem &&
                      m.dataEnvio.isAfter(
                        o.dataEnvio.subtract(const Duration(minutes: 2)),
                      ),
                ));
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
    final tipo = mensagem.tipoMensagem.toLowerCase();
    final texto = tipo == 'imagem'
        ? 'Enviando foto...'
        : tipo == 'audio'
            ? 'Enviando áudio...'
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
          color: mensagem.ehRemetente ? _primaryBlue : Colors.white,
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
                    style: TextStyle(
                      fontSize: 13.5,
                      color: mensagem.ehRemetente
                          ? Colors.white
                          : const Color(0xFF374151),
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
    final ativa = _idAudioTocando == mensagem.id;
    final tocando = ativa && !_audioPausado;
    final barras = [10, 16, 22, 18, 14, 26, 30, 20, 14, 18, 24, 16, 12, 8, 14];

    // Progresso da reprodução (0 a 1) para pintar as barras.
    final totalMs = _duracaoTocando.inMilliseconds;
    final progresso = ativa && totalMs > 0
        ? (_posicaoTocando.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final barrasTocadas = (progresso * barras.length).round();

    final duracaoTotal = mensagem.duracaoAudio != null
        ? _formatarDuracao(mensagem.duracaoAudio!)
        : (ativa ? _formatarDuracao(_duracaoTocando.inSeconds) : '0:00');
    final rotulo = ativa
        ? '${_formatarDuracao(_posicaoTocando.inSeconds)} / $duracaoTotal'
        : duracaoTotal;

    return Align(
      alignment: mensagem.ehRemetente
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mensagem.ehRemetente
              ? _primaryBlue
              : Colors.white,
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
                  onTap: () => _alternarTocarAudio(mensagem),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: mensagem.ehRemetente
                          ? Colors.white.withValues(alpha: 0.22)
                          : _primaryBlue,
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
                        final ehParteTocada = index < barrasTocadas;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          width: 2.8,
                          height: barras[index].toDouble(),
                          decoration: BoxDecoration(
                            color: ehParteTocada
                                ? Colors.white
                                : (mensagem.ehRemetente
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      rotulo,
                      style: TextStyle(
                        fontSize: 11,
                        color: mensagem.ehRemetente
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (!mensagem.ehRemetente) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: _buildMiniAvatarContato(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(mensagem.dataEnvio),
              style: TextStyle(
                fontSize: 11,
                color: mensagem.ehRemetente
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraInput() {
    if (_gravando) return _buildBarraGravando();
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
                      onPressed: _abrirCamera,
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

  /// Barra de gravação (estilo WhatsApp): lixeira = cancelar, botão azul =
  /// parar e enviar. Mostra cronômetro e onda animada com o volume real.
  Widget _buildBarraGravando() {
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
              onPressed: () => _pararGravacao(enviar: false),
              tooltip: 'Cancelar gravação',
              splashRadius: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 26,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              // Deslizar para a esquerda cancela a gravação (estilo WhatsApp).
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (detalhes) =>
                    _deslizeCancelarDx += detalhes.delta.dx,
                onHorizontalDragEnd: (_) {
                  final cancelou = _deslizeCancelarDx < -100;
                  _deslizeCancelarDx = 0;
                  if (cancelou) _pararGravacao(enviar: false);
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _PulsoVermelho(),
                      const SizedBox(width: 8),
                      Text(
                        _formatarDuracao(_segundosGravando),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OndaGravacao(nivel: _nivelGravacao),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _pararGravacao(enviar: true),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
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
  final int? duracaoAudio;

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
enum _OpcaoAnexo { galeria, documento }

/// Bolinha vermelha pulsando indicando gravação em andamento.
class _PulsoVermelho extends StatefulWidget {
  const _PulsoVermelho();

  @override
  State<_PulsoVermelho> createState() => _PulsoVermelhoState();
}

class _PulsoVermelhoState extends State<_PulsoVermelho>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Onda de barras que reage ao volume do microfone em tempo real.
class _OndaGravacao extends StatelessWidget {
  final ValueNotifier<double> nivel;

  const _OndaGravacao({required this.nivel});

  @override
  Widget build(BuildContext context) {
    const barras = [12, 20, 28, 22, 16, 24, 30, 20, 14, 26, 18, 22, 12];
    return ValueListenableBuilder<double>(
      valueListenable: nivel,
      builder: (context, valor, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(barras.length, (index) {
            final fator = 0.35 + (valor * 0.65);
            final base = barras[index] * fator;
            // Onda senoidal para dar movimento mesmo com volume constante.
            final onda =
                1 + 0.25 * (index % 2 == 0 ? valor : -valor * 0.5);
            return Container(
              width: 3,
              height: (base * onda).clamp(4.0, 30.0),
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

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