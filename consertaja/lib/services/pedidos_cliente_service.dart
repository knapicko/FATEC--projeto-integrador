import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'solicitacoes_service.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Resumo de uma solicitação do cliente (histórico, avaliações).
class PedidoResumo {
  const PedidoResumo({
    required this.id,
    required this.fkStatus,
    required this.status,
    required this.titulo,
    required this.prestador,
    required this.valor,
    this.imagem,
    this.fotoPrestador,
    this.data,
    this.avaliado = false,
    this.funcao,
    this.corOficio,
  });

  final int id;
  final int? fkStatus;
  final String status;
  final String titulo;
  final String prestador;
  final double valor;
  final String? imagem;
  final String? fotoPrestador;
  final DateTime? data;
  final bool avaliado;
  final String? funcao;
  final String? corOficio;

  bool get concluido => fkStatus == 6;
  bool get precisaAvaliar => concluido && !avaliado;
}

/// Avaliação que o cliente fez de um serviço.
class AvaliacaoFeita {
  const AvaliacaoFeita({
    required this.pedido,
    required this.nota,
    required this.comentario,
    required this.midias,
    required this.data,
  });

  final PedidoResumo pedido;
  final int nota;
  final String comentario;
  final List<String> midias;
  final DateTime? data;
}

class PedidosClienteService {
  PedidosClienteService._();

  static Future<int?> meuIdUsuario() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final u = await _db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id)
        .limit(1)
        .maybeSingle();
    return (u?['id_usuario'] as num?)?.toInt();
  }

  static String? _url(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.startsWith('http') ? s : null;
  }

  /// Todas as solicitações do cliente logado, mais recentes primeiro.
  static Future<List<PedidoResumo>> listar({List<int>? ids}) async {
    // Prazo de entrega vencido → cancela e manda para a devolução (v0_19).
    await SolicitacoesService.verificarPrazosVencidos();
    final idUsuario = await meuIdUsuario();
    if (idUsuario == null) return const [];
    var q = _db
        .from('solicitacoes')
        .select(
          'id_solicitacao, fk_status, valor_final, data_solicitacao, '
          'fk_servico_prof, fk_servico_temp, fk_profissional, '
          'fk_grupo_empresa, imagens_anexadas_cliente',
        )
        .eq('fk_usuario', idUsuario);
    if (ids != null) q = q.inFilter('id_solicitacao', ids);
    final rows = List<Map<String, dynamic>>.from(
      await q.order('data_solicitacao', ascending: false),
    );
    if (rows.isEmpty) return const [];

    Set<int> col(String c) => {
      for (final r in rows)
        if (r[c] != null) (r[c] as num).toInt(),
    };

    Future<Map<int, Map<String, dynamic>>> porId(
      String tabela,
      String chave,
      String campos,
      Set<int> ids,
    ) async {
      if (ids.isEmpty) return {};
      try {
        final r = await _db
            .from(tabela)
            .select('$chave, $campos')
            .inFilter(chave, ids.toList());
        return {for (final x in r) (x[chave] as num).toInt(): x};
      } catch (e) {
        debugPrint('[pedidos cliente] $tabela: $e');
        return {};
      }
    }

    const camposServico =
        'titulo, imagem_url, funcoes(funcao, oficios(cor, cod_cor))';
    final resultados = await Future.wait([
      porId('status', 'id_status', 'status', col('fk_status')),
      porId(
        'servicos_profissional',
        'id_servico_prof',
        camposServico,
        col('fk_servico_prof'),
      ),
      porId(
        'servicos_chat_temporarios',
        'id_servico_temp',
        camposServico,
        col('fk_servico_temp'),
      ),
      porId(
        'grupo_empresa',
        'id_grupo_empresa',
        'nome_empresa, foto_url_empresa',
        col('fk_grupo_empresa'),
      ),
      porId(
        'dados_profissionais',
        'id_profissional',
        'fk_usuario',
        col('fk_profissional'),
      ),
    ]);
    final status = resultados[0];
    final servicos = resultados[1];
    final temps = resultados[2];
    final grupos = resultados[3];
    final profs = resultados[4];
    final usuarios =
        await porId('usuarios', 'id_usuario', 'nome, foto_perfil_url', {
          for (final p in profs.values)
            if (p['fk_usuario'] != null) (p['fk_usuario'] as num).toInt(),
        });

    Set<int> avaliados = {};
    try {
      final av = await _db
          .from('avaliacoes_solicitacao')
          .select('fk_solicitacao')
          .eq('fk_avaliador', idUsuario)
          .inFilter('tipo_avaliacao', ['servico', 'profissional'])
          .inFilter('fk_solicitacao', [
            for (final r in rows) (r['id_solicitacao'] as num).toInt(),
          ]);
      avaliados = {for (final a in av) (a['fk_solicitacao'] as num).toInt()};
    } catch (_) {}

    return [
      for (final r in rows)
        () {
          final id = (r['id_solicitacao'] as num).toInt();
          final st = (r['fk_status'] as num?)?.toInt();
          final s =
              servicos[(r['fk_servico_prof'] as num?)?.toInt() ?? -1] ??
              temps[(r['fk_servico_temp'] as num?)?.toInt() ?? -1];
          final funcoes = s?['funcoes'];
          final oficio = funcoes is Map ? funcoes['oficios'] : null;
          final g = grupos[(r['fk_grupo_empresa'] as num?)?.toInt() ?? -1];
          final p = profs[(r['fk_profissional'] as num?)?.toInt() ?? -1];
          final u = usuarios[(p?['fk_usuario'] as num?)?.toInt() ?? -1];
          final anexos = r['imagens_anexadas_cliente'];
          return PedidoResumo(
            id: id,
            fkStatus: st,
            status: status[st ?? -1]?['status']?.toString() ?? 'Pedido',
            titulo: s?['titulo']?.toString() ?? 'Serviço',
            prestador: g != null
                ? (g['nome_empresa']?.toString() ?? 'Loja')
                : (u?['nome']?.toString() ?? 'Profissional'),
            fotoPrestador: _url(
              g != null ? g['foto_url_empresa'] : u?['foto_perfil_url'],
            ),
            imagem:
                _url(s?['imagem_url']) ??
                (anexos is List && anexos.isNotEmpty
                    ? _url(anexos.first)
                    : null),
            valor: (r['valor_final'] as num?)?.toDouble() ?? 0,
            data: DateTime.tryParse(
              r['data_solicitacao']?.toString() ?? '',
            )?.toLocal(),
            avaliado: avaliados.contains(id),
            funcao: funcoes is Map ? funcoes['funcao']?.toString() : null,
            corOficio: oficio is Map
                ? (oficio['cod_cor'] ?? oficio['cor'])?.toString()
                : null,
          );
        }(),
    ];
  }

  /// Avaliações de serviço feitas pelo cliente logado.
  static Future<List<AvaliacaoFeita>> minhasAvaliacoes() async {
    final idUsuario = await meuIdUsuario();
    if (idUsuario == null) return const [];
    final av = List<Map<String, dynamic>>.from(
      await _db
          .from('avaliacoes_solicitacao')
          .select('fk_solicitacao, nota, comentario, midias, data_criacao')
          .eq('fk_avaliador', idUsuario)
          .eq('tipo_avaliacao', 'servico')
          .order('data_criacao', ascending: false),
    );
    if (av.isEmpty) return const [];
    final pedidos = await listar(
      ids: [for (final a in av) (a['fk_solicitacao'] as num).toInt()],
    );
    final porId = {for (final p in pedidos) p.id: p};
    return [
      for (final a in av)
        if (porId[(a['fk_solicitacao'] as num).toInt()] case final p?)
          AvaliacaoFeita(
            pedido: p,
            nota: (a['nota'] as num?)?.toInt() ?? 5,
            comentario: a['comentario']?.toString().trim() ?? '',
            midias: [
              if (a['midias'] is List)
                for (final m in a['midias'] as List) m.toString(),
            ],
            data: DateTime.tryParse(
              a['data_criacao']?.toString() ?? '',
            )?.toLocal(),
          ),
    ];
  }
}

/// Serviços favoritados (tabela servicos_favoritos, docs/sql/v0_6_ajustes.sql).
class FavoritosService {
  FavoritosService._();

  static Future<bool> ehFavorito(int idServico) async {
    try {
      final id = await PedidosClienteService.meuIdUsuario();
      if (id == null) return false;
      final r = await _db
          .from('servicos_favoritos')
          .select('id_favorito')
          .eq('fk_usuario', id)
          .eq('fk_servico_prof', idServico)
          .maybeSingle();
      return r != null;
    } catch (_) {
      return false;
    }
  }

  /// Liga/desliga. Devolve o novo estado.
  static Future<bool> alternar(int idServico, {required bool favoritar}) async {
    final id = await PedidosClienteService.meuIdUsuario();
    if (id == null) throw Exception('Entre na sua conta para favoritar.');
    if (favoritar) {
      await _db.from('servicos_favoritos').upsert({
        'fk_usuario': id,
        'fk_servico_prof': idServico,
      }, onConflict: 'fk_usuario,fk_servico_prof');
    } else {
      await _db
          .from('servicos_favoritos')
          .delete()
          .eq('fk_usuario', id)
          .eq('fk_servico_prof', idServico);
    }
    return favoritar;
  }

  /// Ids dos serviços favoritados, mais recentes primeiro.
  static Future<List<int>> meusIds() async {
    final id = await PedidosClienteService.meuIdUsuario();
    if (id == null) return const [];
    final r = await _db
        .from('servicos_favoritos')
        .select('fk_servico_prof')
        .eq('fk_usuario', id)
        .order('data_criacao', ascending: false);
    return [for (final x in r) (x['fk_servico_prof'] as num).toInt()];
  }
}
