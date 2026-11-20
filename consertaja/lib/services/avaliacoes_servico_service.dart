import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Avaliação que um cliente deixou para um serviço.
class AvaliacaoCliente {
  const AvaliacaoCliente({
    required this.idSolicitacao,
    required this.nota,
    required this.comentario,
    required this.data,
    required this.autor,
    this.foto,
    this.midias = const [],
  });

  final int idSolicitacao;
  final int nota;
  final String comentario;
  final DateTime? data;
  final String autor;
  final String? foto;
  final List<String> midias;
}

/// Nota média e quantidade de avaliações de um serviço.
class ResumoAvaliacoes {
  const ResumoAvaliacoes({required this.media, required this.total});

  final double media;
  final int total;

  static const vazio = ResumoAvaliacoes(media: 0, total: 0);
}

/// Avaliações (tipo "servico") dos serviços do profissional/loja.
class AvaliacoesServicoService {
  AvaliacoesServicoService._();

  /// Solicitações de cada serviço: id_solicitacao -> id do serviço.
  static Future<Map<int, int>> _solicitacoesDosServicos(List<int> ids) async {
    if (ids.isEmpty) return {};
    final sols = await _db
        .from('solicitacoes')
        .select('id_solicitacao, fk_servico_prof')
        .inFilter('fk_servico_prof', ids);
    return {
      for (final s in sols)
        if (s['fk_servico_prof'] != null)
          (s['id_solicitacao'] as num).toInt(): (s['fk_servico_prof'] as num)
              .toInt(),
    };
  }

  /// Nota média e total de avaliações de cada serviço.
  static Future<Map<int, ResumoAvaliacoes>> resumoPorServico(
    List<int> idsServicos,
  ) async {
    try {
      final servicoDaSol = await _solicitacoesDosServicos(idsServicos);
      if (servicoDaSol.isEmpty) return {};
      final avs = await _db
          .from('avaliacoes_solicitacao')
          .select('fk_solicitacao, nota')
          .eq('tipo_avaliacao', 'servico')
          .inFilter('fk_solicitacao', servicoDaSol.keys.toList());
      final notas = <int, List<int>>{};
      for (final a in avs) {
        final serv = servicoDaSol[(a['fk_solicitacao'] as num?)?.toInt()];
        final nota = (a['nota'] as num?)?.toInt();
        if (serv == null || nota == null) continue;
        notas.putIfAbsent(serv, () => []).add(nota);
      }
      return {
        for (final e in notas.entries)
          e.key: ResumoAvaliacoes(
            media: e.value.reduce((x, y) => x + y) / e.value.length,
            total: e.value.length,
          ),
      };
    } catch (e) {
      debugPrint('[avaliações serviço] resumo: $e');
      return {};
    }
  }

  /// Todas as avaliações de um serviço, mais recentes primeiro.
  static Future<List<AvaliacaoCliente>> doServico(int idServico) async {
    final servicoDaSol = await _solicitacoesDosServicos([idServico]);
    if (servicoDaSol.isEmpty) return const [];
    final avs = await _db
        .from('avaliacoes_solicitacao')
        .select(
          'fk_solicitacao, fk_avaliador, nota, comentario, midias, '
          'data_criacao',
        )
        .eq('tipo_avaliacao', 'servico')
        .inFilter('fk_solicitacao', servicoDaSol.keys.toList())
        .order('data_criacao', ascending: false);
    final idsAutor = {
      for (final a in avs)
        if (a['fk_avaliador'] != null) (a['fk_avaliador'] as num).toInt(),
    };
    final autores = <int, Map<String, dynamic>>{};
    if (idsAutor.isNotEmpty) {
      try {
        final us = await _db
            .from('usuarios')
            .select('id_usuario, nome, foto_perfil_url')
            .inFilter('id_usuario', idsAutor.toList());
        for (final u in us) {
          autores[(u['id_usuario'] as num).toInt()] = u;
        }
      } catch (_) {}
    }
    return [
      for (final a in avs)
        () {
          final autor = autores[(a['fk_avaliador'] as num?)?.toInt() ?? -1];
          final foto = autor?['foto_perfil_url']?.toString().trim() ?? '';
          return AvaliacaoCliente(
            idSolicitacao: (a['fk_solicitacao'] as num).toInt(),
            nota: ((a['nota'] as num?)?.toInt() ?? 5).clamp(1, 5),
            comentario: a['comentario']?.toString().trim() ?? '',
            data: DateTime.tryParse(
              a['data_criacao']?.toString() ?? '',
            )?.toLocal(),
            autor: autor?['nome']?.toString() ?? 'Cliente',
            foto: foto.startsWith('http') ? foto : null,
            midias: [
              if (a['midias'] is List)
                for (final m in a['midias'] as List)
                  if (m.toString().startsWith('http')) m.toString(),
            ],
          );
        }(),
    ];
  }
}
