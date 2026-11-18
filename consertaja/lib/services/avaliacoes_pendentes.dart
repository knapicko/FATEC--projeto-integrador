import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notificacoes/notificacao_service.dart';

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

  /// Envia a nota (serviço e profissional), o comentário e as mídias.
  static Future<void> enviar({
    required int idSolicitacao,
    required int nota,
    required String comentario,
    required List<XFile> midias,
  }) async {
    final uid = _db.auth.currentUser!.id;
    final urls = <String>[];
    for (var i = 0; i < midias.length; i++) {
      final m = midias[i];
      final nome = m.name.toLowerCase();
      final ext = nome.contains('.') ? nome.split('.').last : 'jpg';
      final video = const ['mp4', 'mov', 'm4v', '3gp', 'webm'].contains(ext);
      final caminho =
          '$uid/$idSolicitacao/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      await _db.storage
          .from('Avaliacoes')
          .uploadBinary(
            caminho,
            await m.readAsBytes(),
            fileOptions: FileOptions(
              contentType: video
                  ? 'video/${ext == 'mov' ? 'quicktime' : ext}'
                  : 'image/${ext == 'jpg' ? 'jpeg' : ext}',
            ),
          );
      urls.add(_db.storage.from('Avaliacoes').getPublicUrl(caminho));
    }
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
    if (urls.isNotEmpty) {
      await _db
          .from('avaliacoes_solicitacao')
          .update({'midias': urls})
          .eq('fk_solicitacao', idSolicitacao)
          .inFilter('tipo_avaliacao', ['servico', 'profissional']);
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

  Future<void> _anexar() async {
    try {
      final novos = await ImagePicker().pickMultipleMedia(limit: 6);
      if (novos.isNotEmpty) {
        setState(() {
          _midias.addAll(novos);
          if (_midias.length > 6) _midias.removeRange(6, _midias.length);
        });
      }
    } catch (_) {}
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
      await AvaliacoesPendentes.enviar(
        idSolicitacao: widget.pedido.idSolicitacao,
        nota: _nota,
        comentario: _comentario.text.trim(),
        midias: _midias,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Avaliação enviada. Obrigado!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[avaliações] enviar: $e');
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = 'Não foi possível enviar agora. Tente de novo.';
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
              CircleAvatar(
                radius: 32,
                backgroundColor: _azul,
                backgroundImage: p.foto != null ? NetworkImage(p.foto!) : null,
                child: p.foto == null
                    ? const Icon(Icons.handyman_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 10),
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
                '${p.titulo} • ${p.prestador}',
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
                      duration: const Duration(milliseconds: 160),
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
                child: FilledButton(
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
                ),
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
