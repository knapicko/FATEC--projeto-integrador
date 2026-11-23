import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notificacoes/notificacao_service.dart';
import '../widgets/imagem_app.dart';
import '../utils/movimento.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Pedido concluído que o cliente ainda não avaliou.
class PedidoParaAvaliar {
  const PedidoParaAvaliar({
    required this.idSolicitacao,
    required this.titulo,
    required this.prestador,
    this.foto,
  });

  final int idSolicitacao;
  final String titulo;
  final String prestador;
  final String? foto;
}

/// Pede a avaliação do cliente:
/// - logo que um pedido dele é concluído (escuta as notificações, então
///   aparece em qualquer tela do app);
/// - de novo na PRÓXIMA vez que ele abrir o app, se ainda não avaliou.
/// Em uma mesma abertura do app o mesmo pedido só é oferecido uma vez.
class AvaliacoesPendentes {
  AvaliacoesPendentes._();

  static GlobalKey<NavigatorState>? _navegador;
  static StreamSubscription<void>? _sub;
  static Timer? _debounce;
  static final Set<int> _jaOferecidos = {};
  static bool _mostrando = false;

  /// Liga a escuta (chamado pela home do cliente; pode chamar várias vezes).
  static void iniciar(GlobalKey<NavigatorState> navegador) {
    _navegador = navegador;
    _sub ??= NotificacaoService.instance.alteracoes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), verificar);
    });
    verificar();
  }

  static Future<void> verificar() async {
    if (_mostrando) return;
    final ctx = _navegador?.currentContext;
    if (ctx == null) return;
    final pedido = await _proximoPendente();
    if (pedido == null) return;
    final contexto = _navegador?.currentContext;
    if (contexto == null || !contexto.mounted) return;
    _jaOferecidos.add(pedido.idSolicitacao);
    _mostrando = true;
    try {
      await showModalBottomSheet<void>(
        context: contexto,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => SheetAvaliarServico(pedido: pedido),
      );
    } finally {
      _mostrando = false;
    }
  }

  /// Abre a avaliação de um pedido concluído específico (histórico, tela de
  /// serviço concluído). Devolve true se o cliente enviou a avaliação.
  static Future<bool> avaliar(BuildContext context, int idSolicitacao) async {
    final c = await _db
        .from('solicitacoes')
        .select(
          'id_solicitacao, fk_profissional, fk_grupo_empresa, '
          'fk_servico_prof, fk_servico_temp',
        )
        .eq('id_solicitacao', idSolicitacao)
        .maybeSingle();
    if (c == null || !context.mounted) return false;
    final pedido = await _montar(c);
    if (!context.mounted) return false;
    _jaOferecidos.add(idSolicitacao);
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SheetAvaliarServico(pedido: pedido),
    );
    return r == true;
  }

  static Future<PedidoParaAvaliar?> _proximoPendente() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return null;
      final u = await _db
          .from('usuarios')
          .select('id_usuario, tipo_conta')
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();
      final idUsuario = (u?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return null;
      final concluidos = await _db
          .from('solicitacoes')
          .select(
            'id_solicitacao, fk_profissional, fk_grupo_empresa, '
            'fk_servico_prof, fk_servico_temp',
          )
          .eq('fk_usuario', idUsuario)
          .eq('fk_status', 6)
          .order('data_solicitacao', ascending: false)
          .limit(10);
      if (concluidos.isEmpty) return null;
      final ids = [
        for (final c in concluidos) (c['id_solicitacao'] as num).toInt(),
      ];
      final feitas = await _db
          .from('avaliacoes_solicitacao')
          .select('fk_solicitacao')
          .eq('fk_avaliador', idUsuario)
          .inFilter('tipo_avaliacao', ['servico', 'profissional'])
          .inFilter('fk_solicitacao', ids);
      final avaliados = {
        for (final f in feitas) (f['fk_solicitacao'] as num).toInt(),
      };
      for (final c in concluidos) {
        final id = (c['id_solicitacao'] as num).toInt();
        if (avaliados.contains(id) || _jaOferecidos.contains(id)) continue;
        return await _montar(c);
      }
    } catch (e) {
      debugPrint('[avaliações] $e');
    }
    return null;
  }

  static Future<PedidoParaAvaliar> _montar(Map<String, dynamic> c) async {
    var titulo = 'Serviço';
    var nome = 'Profissional';
    String? foto;
    try {
      final idServ = c['fk_servico_prof'];
      final idTemp = c['fk_servico_temp'];
      final s = idServ != null
          ? await _db
                .from('servicos_profissional')
                .select('titulo')
                .eq('id_servico_prof', idServ)
                .maybeSingle()
          : idTemp != null
          ? await _db
                .from('servicos_chat_temporarios')
                .select('titulo')
                .eq('id_servico_temp', idTemp)
                .maybeSingle()
          : null;
      titulo = s?['titulo']?.toString() ?? titulo;
      if (c['fk_grupo_empresa'] != null) {
        final g = await _db
            .from('grupo_empresa')
            .select('nome_empresa, foto_url_empresa')
            .eq('id_grupo_empresa', c['fk_grupo_empresa'])
            .maybeSingle();
        nome = g?['nome_empresa']?.toString() ?? nome;
        foto = g?['foto_url_empresa']?.toString();
      } else {
        final d = await _db
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', c['fk_profissional'])
            .maybeSingle();
        if (d != null) {
          final u = await _db
              .from('usuarios')
              .select('nome, foto_perfil_url')
              .eq('id_usuario', d['fk_usuario'])
              .maybeSingle();
          nome = u?['nome']?.toString() ?? nome;
          foto = u?['foto_perfil_url']?.toString();
        }
      }
    } catch (_) {}
    return PedidoParaAvaliar(
      idSolicitacao: (c['id_solicitacao'] as num).toInt(),
      titulo: titulo,
      prestador: nome,
      foto: (foto ?? '').startsWith('http') ? foto : null,
    );
  }

  /// Tipo do arquivo pelo nome (padrão: JPEG).
  static String _tipoMidia(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' || 'heif' => 'image/heic',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    '3gp' => 'video/3gpp',
    'webm' => 'video/webm',
    _ => 'image/jpeg',
  };

  /// Envia a nota (serviço e profissional), o comentário e as mídias.
  /// Devolve um aviso quando a nota foi salva mas as fotos não (null = ok).
  static Future<String?> enviar({
    required int idSolicitacao,
    required int nota,
    required String comentario,
    required List<XFile> midias,
  }) async {
    // 1) Nota e comentário primeiro: a avaliação não se perde se uma foto
    //    falhar. Já avaliado (tentativa anterior) segue para as fotos.
    try {
      await _db.rpc(
        'registrar_avaliacoes_cliente',
        params: {
          'p_id_solicitacao': idSolicitacao,
          'p_nota_servico': nota,
          'p_comentario_servico': comentario,
          'p_nota_profissional': nota,
          'p_comentario_profissional': comentario,
        },
      );
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    if (midias.isEmpty) return null;

    // 2) Fotos/vídeos.
    try {
      final uid = _db.auth.currentUser!.id;
      final urls = <String>[];
      for (var i = 0; i < midias.length; i++) {
        final m = midias[i];
        final nome = (m.name.isNotEmpty ? m.name : m.path).toLowerCase();
        var ext = nome.contains('.') ? nome.split('.').last : 'jpg';
        if (ext.length > 5) ext = 'jpg';
        final caminho =
            '$uid/$idSolicitacao/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await _db.storage
            .from('Avaliacoes')
            .uploadBinary(
              caminho,
              await m.readAsBytes(),
              fileOptions: FileOptions(
                contentType: _tipoMidia(ext),
                upsert: true,
              ),
            );
        urls.add(_db.storage.from('Avaliacoes').getPublicUrl(caminho));
      }
      var salvas = 0;
      try {
        // Pelo servidor (docs/sql/v0_10_ajustes.sql).
        final r = await _db.rpc(
          'anexar_midias_avaliacao',
          params: {'p_id_solicitacao': idSolicitacao, 'p_midias': urls},
        );
        salvas = (r as num?)?.toInt() ?? 0;
      } catch (_) {
        final atualizadas = await _db
            .from('avaliacoes_solicitacao')
            .update({'midias': urls})
            .eq('fk_solicitacao', idSolicitacao)
            .inFilter('tipo_avaliacao', ['servico', 'profissional'])
            .select('id_avaliacao');
        salvas = (atualizadas as List).length;
      }
      if (salvas == 0) {
        return 'Sua avaliação foi enviada, mas as fotos não foram salvas.';
      }
      return null;
    } catch (e) {
      debugPrint('[avaliações] fotos: $e');
      final t = e.toString().toLowerCase();
      if (t.contains('too large') || t.contains('413') || t.contains('size')) {
        return 'Sua avaliação foi enviada, mas um arquivo era grande demais '
            'e as fotos não foram salvas.';
      }
      return 'Sua avaliação foi enviada, mas as fotos não puderam ser salvas.';
    }
  }
}

/// Bottom sheet: 5 estrelas, comentário e fotos/vídeos.
class SheetAvaliarServico extends StatefulWidget {
  const SheetAvaliarServico({super.key, required this.pedido});

  final PedidoParaAvaliar pedido;

  @override
  State<SheetAvaliarServico> createState() => _SheetAvaliarServicoState();
}

class _SheetAvaliarServicoState extends State<SheetAvaliarServico> {
  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);
  static const _rotulos = ['Ruim', 'Regular', 'Bom', 'Muito bom', 'Excelente'];

  int _nota = 0;
  final _comentario = TextEditingController();
  final List<XFile> _midias = [];
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  /// Fotos (várias), vídeo ou câmera. Antes usava pickMultipleMedia com
  /// limite, que falha em vários Androids sem avisar nada.
  Future<void> _anexar() async {
    final origem = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _azul),
              title: const Text('Fotos da galeria'),
              onTap: () => Navigator.pop(ctx, 'fotos'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _azul),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: _azul),
              title: const Text('Vídeo da galeria'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;
    try {
      final picker = ImagePicker();
      final novos = <XFile>[];
      if (origem == 'fotos') {
        novos.addAll(
          await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600),
        );
      } else if (origem == 'camera') {
        final f = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1600,
        );
        if (f != null) novos.add(f);
      } else {
        final f = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 2),
        );
        if (f != null) novos.add(f);
      }
      if (novos.isNotEmpty && mounted) {
        setState(() {
          _midias.addAll(novos);
          if (_midias.length > 6) _midias.removeRange(6, _midias.length);
          _erro = null;
        });
      }
    } catch (e) {
      debugPrint('[avaliações] anexar: $e');
      if (mounted) {
        setState(
          () => _erro =
              'Não foi possível abrir a galeria/câmera. Confira a permissão '
              'de fotos do app.',
        );
      }
    }
  }

  Future<void> _enviar() async {
    if (_nota == 0) {
      setState(() => _erro = 'Escolha de 1 a 5 estrelas.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final aviso = await AvaliacoesPendentes.enviar(
        idSolicitacao: widget.pedido.idSolicitacao,
        nota: _nota,
        comentario: _comentario.text.trim(),
        midias: _midias,
      );
      if (!mounted) return;
      final mensageiro = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context, true);
      mensageiro?.showSnackBar(
        SnackBar(
          content: Text(aviso ?? 'Avaliação enviada. Obrigado!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[avaliações] enviar: $e');
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = e is PostgrestException && e.message.trim().isNotEmpty
              ? 'Não foi possível enviar: ${e.message}'
              : 'Não foi possível enviar agora. Tente de novo.';
        });
      }
    }
  }

  bool _ehVideo(XFile f) {
    final n = f.name.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.m4v') ||
        n.endsWith('.3gp') ||
        n.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              // Foto e nome de quem fez o serviço.
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: CorOriginal(child: CircleAvatar(
                  radius: 36,
                  backgroundColor: _azul,
                  backgroundImage: p.foto != null
                      ? NetworkImage(p.foto!)
                      : null,
                  child: p.foto == null
                      ? Text(
                          p.prestador.trim().isEmpty
                              ? '?'
                              : p.prestador.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                )),
              ),
              const SizedBox(height: 8),
              Text(
                p.prestador,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Como foi o serviço?',
                style: TextStyle(
                  color: _texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _sec),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final ativo = i < _nota;
                  return GestureDetector(
                    onTap: () => setState(() => _nota = i + 1),
                    child: AnimatedScale(
                      scale: ativo ? 1.12 : 1,
                      duration: duracao(const Duration(milliseconds: 160)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          ativo
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 44,
                          color: ativo
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(
                height: 22,
                child: Text(
                  _nota == 0 ? '' : _rotulos[_nota - 1],
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _comentario,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Conte como foi (opcional)',
                  filled: true,
                  fillColor: const Color(0xFFF3F5F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    InkWell(
                      onTap: _midias.length >= 6 ? null : _anexar,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: _azul),
                            SizedBox(height: 4),
                            Text(
                              'Fotos/vídeos',
                              style: TextStyle(
                                color: _azul,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (var i = 0; i < _midias.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 72,
                                height: 76,
                                child: _ehVideo(_midias[i])
                                    ? Container(
                                        color: const Color(0xFF1F2937),
                                        child: const Icon(
                                          Icons.play_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      )
                                    : FutureBuilder(
                                        future: _midias[i].readAsBytes(),
                                        builder: (_, snap) => snap.hasData
                                            ? Image.memory(
                                                snap.data!,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: const Color(0xFFF3F4F6),
                                              ),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _midias.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _erro!,
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: CorOriginal(interface: true, child: FilledButton(
                  onPressed: _enviando ? null : _enviar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    shape: const StadiumBorder(),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar avaliação',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                )),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Avaliar depois',
                  style: TextStyle(color: _sec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
