import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/chat_anexos_service.dart';
import 'widgets/skeleton_loading.dart';

/// Tipo de mídia suportada na tela.
enum TipoMidiaChat { imagem, audio }

/// Modelo unificado de item de mídia para a galeria do chat.
class ItemMidiaChat {
  final int id;
  final TipoMidiaChat tipo;
  final String url;
  final String nome;
  final String? legenda;
  final DateTime dataEnvio;
  final bool ehRemetente;
  final int? duracaoSegundos;

  const ItemMidiaChat({
    required this.id,
    required this.tipo,
    required this.url,
    required this.nome,
    this.legenda,
    required this.dataEnvio,
    required this.ehRemetente,
    this.duracaoSegundos,
  });
}

class TelaMidiaChat extends StatefulWidget {
  final int? idConversa;
  final String? nomeContato;

  const TelaMidiaChat({
    super.key,
    required this.idConversa,
    this.nomeContato,
  });

  @override
  State<TelaMidiaChat> createState() => _TelaMidiaChatState();
}

class _TelaMidiaChatState extends State<TelaMidiaChat> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _screenBackground = Color(0xFFF8FAFC);
  static const Color _cardBorderColor = Color(0xFFE2E8F0);

  final _supabase = Supabase.instance.client;

  bool _carregando = true;
  String? _erroCarregamento;
  int? _idUsuarioLogado;

  // Filtro atual: 0 = Imagens, 1 = Áudio
  int _filtroSelecionado = 0;

  // Ordem: true = Mais recentes primeiro, false = Mais antigas primeiro
  bool _ordemDecrescente = true;

  List<ItemMidiaChat> _todasMidias = [];

  // ---- Reprodução de Áudio ----
  final AudioPlayer _player = AudioPlayer();
  int? _idAudioTocando;
  bool _audioPausado = false;
  Duration _posicaoTocando = Duration.zero;
  Duration _duracaoTocando = Duration.zero;
  StreamSubscription? _duracaoSub;
  StreamSubscription? _posicaoSub;
  StreamSubscription? _estadoSub;

  @override
  void initState() {
    super.initState();
    _idUsuarioLogado = _obterIdUsuarioLogado();
    _configurarPlayer();
    _carregarMidias();
  }

  int? _obterIdUsuarioLogado() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata;
    final idMeta = metadata?['id_usuario'] ?? metadata?['sub'];
    if (idMeta is num) return idMeta.toInt();
    if (idMeta is String) return int.tryParse(idMeta);
    return null;
  }

  void _configurarPlayer() {
    _duracaoSub = _player.onDurationChanged.listen((duracao) {
      if (!mounted) return;
      setState(() => _duracaoTocando = duracao);
    });

    _posicaoSub = _player.onPositionChanged.listen((posicao) {
      if (!mounted) return;
      setState(() => _posicaoTocando = posicao);
    });

    _estadoSub = _player.onPlayerStateChanged.listen((estado) {
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

  @override
  void dispose() {
    _duracaoSub?.cancel();
    _posicaoSub?.cancel();
    _estadoSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _carregarMidias() async {
    if (widget.idConversa == null) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erroCarregamento = 'ID da conversa não fornecido.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _carregando = true;
        _erroCarregamento = null;
      });
    }

    try {
      List<Map<String, dynamic>> mensagens;
      try {
        mensagens = await _supabase
            .from('mensagens')
            .select(
              'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem, url_arquivo, legenda, duracao_audio',
            )
            .eq('fk_conversa', widget.idConversa!)
            .order('data_envio', ascending: false);
      } catch (_) {
        try {
          mensagens = await _supabase
              .from('mensagens')
              .select(
                'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem, url_arquivo, legenda',
              )
              .eq('fk_conversa', widget.idConversa!)
              .order('data_envio', ascending: false);
        } catch (_) {
          mensagens = await _supabase
              .from('mensagens')
              .select(
                'id_mensagem, conteudo, data_envio, fk_remitente_usuario, tipo_mensagem',
              )
              .eq('fk_conversa', widget.idConversa!)
              .order('data_envio', ascending: false);
        }
      }

      final lista = <ItemMidiaChat>[];

      for (final m in mensagens) {
        final id = (m['id_mensagem'] as num?)?.toInt() ?? 0;
        final tipo = m['tipo_mensagem']?.toString().toLowerCase() ?? '';
        final conteudo = m['conteudo']?.toString().trim() ?? '';
        final urlArquivo = m['url_arquivo']?.toString().trim();
        final legenda = m['legenda']?.toString().trim();
        final duracao = (m['duracao_audio'] as num?)?.toInt();
        final idRemetente = (m['fk_remitente_usuario'] as num?)?.toInt();
        final rawData = m['data_envio']?.toString();
        final data = rawData != null
            ? DateTime.tryParse(rawData)?.toLocal() ?? DateTime.now()
            : DateTime.now();

        final ehRemetente =
            _idUsuarioLogado != null && idRemetente == _idUsuarioLogado;

        // Extrai URL limpa do anexo
        final documento = ChatAnexosService.separarConteudoDocumento(conteudo);
        final urlFinal = (urlArquivo != null && urlArquivo.isNotEmpty)
            ? urlArquivo
            : (documento?.url ?? conteudo);

        final nomeFinal = documento?.nome.isNotEmpty == true
            ? documento!.nome
            : _extrairNomeArquivoDeUrl(urlFinal);

        // Verifica se é imagem
        final ehImagem = tipo.contains('imagem') ||
            ChatAnexosService.ehImagem(nomeFinal) ||
            ChatAnexosService.ehImagem(urlFinal) ||
            RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp|heic|heif)(\?|$)',
                    caseSensitive: false)
                .hasMatch(urlFinal);

        // Verifica se é áudio
        final ehAudio = tipo.contains('audio') ||
            tipo.contains('áudio') ||
            RegExp(r'\.(m4a|aac|mp3|wav|ogg|webm)(\?|$)',
                    caseSensitive: false)
                .hasMatch(urlFinal);

        if (ehImagem && _urlValida(urlFinal)) {
          lista.add(ItemMidiaChat(
            id: id,
            tipo: TipoMidiaChat.imagem,
            url: urlFinal,
            nome: nomeFinal,
            legenda: legenda,
            dataEnvio: data,
            ehRemetente: ehRemetente,
          ));
        } else if (ehAudio && _urlValida(urlFinal)) {
          lista.add(ItemMidiaChat(
            id: id,
            tipo: TipoMidiaChat.audio,
            url: urlFinal,
            nome: nomeFinal.isNotEmpty ? nomeFinal : 'Mensagem de voz',
            legenda: legenda,
            dataEnvio: data,
            ehRemetente: ehRemetente,
            duracaoSegundos: duracao,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _todasMidias = lista;
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar mídias: $e');
      if (mounted) {
        setState(() {
          _erroCarregamento = 'Falha ao buscar as mídias da conversa.';
          _carregando = false;
        });
      }
    }
  }

  bool _urlValida(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String _extrairNomeArquivoDeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return Uri.decodeComponent(segments.last);
      }
    } catch (_) {}
    return 'Arquivo';
  }

  List<ItemMidiaChat> get _imagens {
    final list = _todasMidias
        .where((m) => m.tipo == TipoMidiaChat.imagem)
        .toList();
    list.sort((a, b) => _ordemDecrescente
        ? b.dataEnvio.compareTo(a.dataEnvio)
        : a.dataEnvio.compareTo(b.dataEnvio));
    return list;
  }

  List<ItemMidiaChat> get _audios {
    final list = _todasMidias
        .where((m) => m.tipo == TipoMidiaChat.audio)
        .toList();
    list.sort((a, b) => _ordemDecrescente
        ? b.dataEnvio.compareTo(a.dataEnvio)
        : a.dataEnvio.compareTo(b.dataEnvio));
    return list;
  }

  Future<void> _alternarTocarAudio(ItemMidiaChat item) async {
    try {
      if (_idAudioTocando == item.id) {
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
        _idAudioTocando = item.id;
        _audioPausado = false;
        _posicaoTocando = Duration.zero;
        _duracaoTocando = item.duracaoSegundos != null
            ? Duration(seconds: item.duracaoSegundos!)
            : Duration.zero;
      });

      await _player.play(UrlSource(item.url));
    } catch (e) {
      debugPrint('Erro ao tocar áudio: $e');
      if (mounted) {
        setState(() {
          _idAudioTocando = null;
          _audioPausado = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível reproduzir o áudio.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _abrirVisualizadorImagem(int indexInicial) {
    final imagens = _imagens;
    if (imagens.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisualizadorGaleriaTelaCheia(
          imagens: imagens,
          indiceInicial: indexInicial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countImagens = _imagens.length;
    final countAudios = _audios.length;

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mídia na conversa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (widget.nomeContato != null &&
                widget.nomeContato!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.nomeContato!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Botão para alternar ordem de envio (mais recentes / mais antigas)
          IconButton(
            tooltip: _ordemDecrescente
                ? 'Mais recentes primeiro'
                : 'Mais antigas primeiro',
            icon: Icon(
              _ordemDecrescente
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: const Color(0xFF475569),
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _ordemDecrescente = !_ordemDecrescente;
              });
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _ordemDecrescente
                        ? 'Mostrando mídias mais recentes primeiro'
                        : 'Mostrando mídias mais antigas primeiro',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF475569),
              size: 22,
            ),
            onPressed: _carregarMidias,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBotaoFiltro(
                      indice: 0,
                      titulo: 'Imagens',
                      icone: Icons.image_rounded,
                      contagem: countImagens,
                    ),
                  ),
                  Expanded(
                    child: _buildBotaoFiltro(
                      indice: 1,
                      titulo: 'Áudios',
                      icone: Icons.graphic_eq_rounded,
                      contagem: countAudios,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildConteudo(),
    );
  }

  Widget _buildBotaoFiltro({
    required int indice,
    required String titulo,
    required IconData icone,
    required int contagem,
  }) {
    final selecionado = _filtroSelecionado == indice;

    return GestureDetector(
      onTap: () {
        if (_filtroSelecionado != indice) {
          setState(() => _filtroSelecionado = indice);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selecionado ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icone,
              size: 17,
              color: selecionado ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
                color: selecionado ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selecionado
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$contagem',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selecionado ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return _buildSkeleton();
    }

    if (_erroCarregamento != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              Text(
                _erroCarregamento!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
                onPressed: _carregarMidias,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh: _carregarMidias,
      child: _filtroSelecionado == 0 ? _buildAbaImagens() : _buildAbaAudios(),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 1: IMAGENS (Grid organizado por data)
  // ---------------------------------------------------------------------------
  Widget _buildAbaImagens() {
    final imagens = _imagens;

    if (imagens.isEmpty) {
      return _buildEstadoVazio(
        icone: Icons.photo_library_outlined,
        titulo: 'Nenhuma imagem compartilhada',
        subtitulo:
            'As fotos e imagens enviadas ou recebidas nesta conversa aparecerão aqui.',
      );
    }

    // Agrupa imagens por dia para exibição com cabeçalho de data
    final agrupadas = _agruparPorDia(imagens);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: agrupadas.length,
      itemBuilder: (context, index) {
        final grupo = agrupadas[index];
        final itensDoGrupo = grupo.itens;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorderColor),
                    ),
                    child: Text(
                      grupo.titulo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${itensDoGrupo.length} ${itensDoGrupo.length == 1 ? 'foto' : 'fotos'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: itensDoGrupo.length,
              itemBuilder: (context, itemIdx) {
                final item = itensDoGrupo[itemIdx];
                final indiceGeral = imagens.indexOf(item);

                return GestureDetector(
                  onTap: () => _abrirVisualizadorImagem(indiceGeral),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item.url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _primaryBlue,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Color(0xFF94A3B8),
                              size: 28,
                            ),
                          ),
                        ),
                        // Gradiente e horário no canto inferior direito
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black54, Colors.transparent],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(item.dataEnvio),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 2: ÁUDIOS (Cards modernos com reprodução em tempo real)
  // ---------------------------------------------------------------------------
  Widget _buildAbaAudios() {
    final audios = _audios;

    if (audios.isEmpty) {
      return _buildEstadoVazio(
        icone: Icons.graphic_eq_rounded,
        titulo: 'Nenhum áudio compartilhado',
        subtitulo:
            'As mensagens de voz e arquivos de áudio desta conversa aparecerão aqui.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: audios.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = audios[index];
        final estaAtivo = _idAudioTocando == item.id;
        final tocando = estaAtivo && !_audioPausado;

        // Duração total
        final duracaoTotal = item.duracaoSegundos != null
            ? _formatarSegundos(item.duracaoSegundos!)
            : (estaAtivo ? _formatarSegundos(_duracaoTocando.inSeconds) : '0:00');

        // Rótulo de reprodução
        final rotuloTempo = estaAtivo
            ? '${_formatarSegundos(_posicaoTocando.inSeconds)} / $duracaoTotal'
            : duracaoTotal;

        // Progresso (0 a 1)
        final totalMs = _duracaoTocando.inMilliseconds;
        final progresso = estaAtivo && totalMs > 0
            ? (_posicaoTocando.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;

        final barras = const [
          10, 18, 14, 26, 32, 22, 16, 28, 20, 12, 24, 30, 18, 14, 22, 16, 12, 20
        ];
        final barrasTocadas = (progresso * barras.length).round();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: estaAtivo
                  ? _primaryBlue.withValues(alpha: 0.5)
                  : _cardBorderColor,
              width: estaAtivo ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Botão Tocar / Pausar
                  GestureDetector(
                    onTap: () => _alternarTocarAudio(item),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tocando
                            ? const Color(0xFF0284C7)
                            : _primaryBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        tocando
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Barras de áudio / onda sonora interativa
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.nome,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              rotuloTempo,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: estaAtivo
                                    ? _primaryBlue
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Formas de onda
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(barras.length, (bIdx) {
                            final ehTocada = bIdx < barrasTocadas;
                            return Container(
                              width: 3,
                              height: barras[bIdx].toDouble(),
                              decoration: BoxDecoration(
                                color: ehTocada
                                    ? _primaryBlue
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Rodapé do card: Data, Remetente
              Row(
                children: [
                  Icon(
                    item.ehRemetente
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded,
                    size: 14,
                    color: item.ehRemetente
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.ehRemetente
                        ? 'Enviado por você'
                        : (widget.nomeContato != null &&
                                widget.nomeContato!.trim().isNotEmpty
                            ? 'Recebido de ${widget.nomeContato!.trim()}'
                            : 'Recebido'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: item.ehRemetente
                          ? const Color(0xFF059669)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatarDataCompleta(item.dataEnvio),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de formatação e agrupamento
  // ---------------------------------------------------------------------------
  String _formatarSegundos(int segundos) {
    final m = segundos ~/ 60;
    final s = segundos % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatarDataCompleta(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final ontem = hoje.subtract(const Duration(days: 1));
    final dataDia = DateTime(data.year, data.month, data.day);

    final hora = DateFormat('HH:mm').format(data);

    if (dataDia == hoje) {
      return 'Hoje às $hora';
    } else if (dataDia == ontem) {
      return 'Ontem às $hora';
    } else {
      return '${DateFormat('dd/MM/yyyy').format(data)} às $hora';
    }
  }

  List<_GrupoPorData> _agruparPorDia(List<ItemMidiaChat> itens) {
    final Map<String, List<ItemMidiaChat>> mapa = {};

    for (final item in itens) {
      final rotulo = _rotuloGrupoData(item.dataEnvio);
      mapa.putIfAbsent(rotulo, () => []).add(item);
    }

    return mapa.entries
        .map((entry) => _GrupoPorData(titulo: entry.key, itens: entry.value))
        .toList();
  }

  String _rotuloGrupoData(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final ontem = hoje.subtract(const Duration(days: 1));
    final dataDia = DateTime(data.year, data.month, data.day);

    if (dataDia == hoje) {
      return 'Hoje';
    } else if (dataDia == ontem) {
      return 'Ontem';
    }

    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    if (data.year == agora.year) {
      return '${data.day} de ${meses[data.month - 1]}';
    }
    return '${data.day} de ${meses[data.month - 1]} de ${data.year}';
  }

  Widget _buildEstadoVazio({
    required IconData icone,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 38, color: _primaryBlue),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SkeletonBox(width: 120, height: 20, borderRadius: 6),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: 9,
          itemBuilder: (context, index) =>
              const SkeletonBox(height: 100, borderRadius: 10),
        ),
      ],
    );
  }
}

class _GrupoPorData {
  final String titulo;
  final List<ItemMidiaChat> itens;

  const _GrupoPorData({required this.titulo, required this.itens});
}

// -----------------------------------------------------------------------------
// Visualizador de Imagens em Tela Cheia com Zoom e Navegação por Swipe
// -----------------------------------------------------------------------------
class _VisualizadorGaleriaTelaCheia extends StatefulWidget {
  final List<ItemMidiaChat> imagens;
  final int indiceInicial;

  const _VisualizadorGaleriaTelaCheia({
    required this.imagens,
    required this.indiceInicial,
  });

  @override
  State<_VisualizadorGaleriaTelaCheia> createState() =>
      _VisualizadorGaleriaTelaCheiaState();
}

class _VisualizadorGaleriaTelaCheiaState
    extends State<_VisualizadorGaleriaTelaCheia> {
  late PageController _pageController;
  late int _indiceAtual;

  @override
  void initState() {
    super.initState();
    _indiceAtual = widget.indiceInicial;
    _pageController = PageController(initialPage: widget.indiceInicial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagemAtual = widget.imagens[_indiceAtual];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Galeria navegável por PageView com pinch zoom
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imagens.length,
            onPageChanged: (novoIndice) {
              setState(() => _indiceAtual = novoIndice);
            },
            itemBuilder: (context, index) {
              final img = widget.imagens[index];
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    img.url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Barra Superior com Voltar, Contagem e Data
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_indiceAtual + 1} de ${widget.imagens.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(imagemAtual.dataEnvio),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Legenda da imagem (se houver) no rodapé
          if (imagemAtual.legenda != null &&
              imagemAtual.legenda!.trim().isNotEmpty) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Text(
                    imagemAtual.legenda!.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
