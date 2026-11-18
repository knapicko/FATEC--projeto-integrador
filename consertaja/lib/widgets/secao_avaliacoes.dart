import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/iniciais.dart';
import 'skeleton_loading.dart';

class _Avaliacao {
  const _Avaliacao({
    required this.nota,
    required this.comentario,
    required this.data,
    required this.autor,
    this.foto,
    this.midias = const [],
  });

  final int nota;
  final String comentario;
  final DateTime data;
  final String autor;
  final String? foto;
  final List<String> midias;
}

/// Avaliações dos clientes (estrelas, comentário e fotos/vídeos).
/// - [idServico]: avaliações do serviço (tela_servico.dart);
/// - [idProfissional] / [idGrupoEmpresa]: avaliações do profissional ou da
///   loja (perfil).
class SecaoAvaliacoes extends StatefulWidget {
  const SecaoAvaliacoes({
    super.key,
    this.idServico,
    this.idProfissional,
    this.idGrupoEmpresa,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final int? idServico;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final EdgeInsets padding;

  @override
  State<SecaoAvaliacoes> createState() => _SecaoAvaliacoesState();
}

class _SecaoAvaliacoesState extends State<SecaoAvaliacoes> {
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);

  List<_Avaliacao>? _lista;
  bool _verTodas = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant SecaoAvaliacoes old) {
    super.didUpdateWidget(old);
    if (old.idServico != widget.idServico ||
        old.idProfissional != widget.idProfissional ||
        old.idGrupoEmpresa != widget.idGrupoEmpresa) {
      _carregar();
    }
  }

  Future<void> _carregar() async {
    final db = Supabase.instance.client;
    try {
      var q = db.from('solicitacoes').select('id_solicitacao');
      if (widget.idServico != null) {
        q = q.eq('fk_servico_prof', widget.idServico!);
      } else if (widget.idGrupoEmpresa != null) {
        q = q.eq('fk_grupo_empresa', widget.idGrupoEmpresa!);
      } else if (widget.idProfissional != null) {
        q = q.eq('fk_profissional', widget.idProfissional!);
      } else {
        if (mounted) setState(() => _lista = const []);
        return;
      }
      final sols = await q;
      final ids = [for (final s in sols) (s['id_solicitacao'] as num).toInt()];
      if (ids.isEmpty) {
        if (mounted) setState(() => _lista = const []);
        return;
      }
      final avs = await db
          .from('avaliacoes_solicitacao')
          .select()
          .eq(
            'tipo_avaliacao',
            widget.idServico != null ? 'servico' : 'profissional',
          )
          .inFilter('fk_solicitacao', ids)
          .order('data_criacao', ascending: false);
      final idsAutor = {
        for (final a in avs)
          if (a['fk_avaliador'] != null) (a['fk_avaliador'] as num).toInt(),
      };
      final autores = <int, Map<String, dynamic>>{};
      if (idsAutor.isNotEmpty) {
        final us = await db
            .from('usuarios')
            .select('id_usuario, nome, foto_perfil_url')
            .inFilter('id_usuario', idsAutor.toList());
        for (final u in us) {
          autores[(u['id_usuario'] as num).toInt()] = u;
        }
      }
      final lista = [
        for (final a in avs)
          _Avaliacao(
            nota: (a['nota'] as num?)?.toInt() ?? 5,
            comentario: a['comentario']?.toString().trim() ?? '',
            data:
                DateTime.tryParse(
                  a['data_criacao']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            autor:
                autores[(a['fk_avaliador'] as num?)?.toInt() ?? -1]?['nome']
                    ?.toString() ??
                'Cliente',
            foto:
                autores[(a['fk_avaliador'] as num?)?.toInt() ??
                        -1]?['foto_perfil_url']
                    ?.toString(),
            midias: [
              if (a['midias'] is List)
                for (final m in a['midias'] as List) m.toString(),
            ],
          ),
      ];
      if (mounted) setState(() => _lista = lista);
    } catch (e) {
      debugPrint('[avaliações] seção: $e');
      if (mounted) setState(() => _lista = const []);
    }
  }

  bool _video(String url) {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.m4v') ||
        u.endsWith('.3gp') ||
        u.endsWith('.webm');
  }

  void _abrirMidia(String url) {
    if (_video(url)) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }

  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _item(_Avaliacao a) {
    final foto = a.foto ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0FB3FF),
                backgroundImage: foto.startsWith('http')
                    ? NetworkImage(foto)
                    : null,
                child: foto.startsWith('http')
                    ? null
                    : Text(
                        obterIniciais(a.autor),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.autor,
                      style: const TextStyle(
                        color: _texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Icon(
                            i < a.nota
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 15,
                            color: const Color(0xFFF59E0B),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _data(a.data),
                          style: const TextStyle(color: _sec, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (a.comentario.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              a.comentario,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (a.midias.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: a.midias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = a.midias[i];
                  return InkWell(
                    onTap: () => _abrirMidia(m),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _video(m)
                            ? Container(
                                color: const Color(0xFF1F2937),
                                child: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: Colors.white,
                                ),
                              )
                            : Image.network(m, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    final media = (lista == null || lista.isEmpty)
        ? null
        : lista.map((a) => a.nota).reduce((x, y) => x + y) / lista.length;
    final visiveis = lista == null
        ? const <_Avaliacao>[]
        : (_verTodas ? lista : lista.take(3).toList());
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Avaliações',
                style: TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              if (media != null) ...[
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
                Text(
                  ' ${media.toStringAsFixed(1)} (${lista!.length})',
                  style: const TextStyle(
                    color: _texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (lista == null)
            const SkeletonBox(height: 110, borderRadius: 16)
          else if (lista.isEmpty)
            const Text(
              'Ainda não há avaliações.',
              style: TextStyle(color: _sec),
            )
          else ...[
            for (final a in visiveis) _item(a),
            if (lista.length > 3)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _verTodas = !_verTodas),
                  child: Text(
                    _verTodas
                        ? 'Mostrar menos'
                        : 'Ver todas as ${lista.length} avaliações',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
