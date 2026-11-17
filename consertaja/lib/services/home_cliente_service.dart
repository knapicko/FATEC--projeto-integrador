import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_profissional.dart';
import '../utils/cor_oficio.dart';
import '../utils/fluxo_solicitacao.dart';
import '../utils/funcao_servico.dart';
import 'solicitacao_geografica_service.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Pedido do cliente em andamento (card "PEDIDO EM ANDAMENTO" da home).
class PedidoAndamento {
  const PedidoAndamento({
    required this.id,
    required this.titulo,
    required this.nomePrestador,
    required this.status,
    required this.fluxo,
    this.foto,
    this.funcao,
    this.rua,
  });

  final int id;
  final String titulo;
  final String nomePrestador;
  final String? foto;
  final String? funcao;
  final String status;
  final String? rua;
  final FluxoSolicitacao fluxo;
}

/// Categoria (ofício) para a grade "Categorias Populares".
class CategoriaHome {
  const CategoriaHome({required this.nome, this.cor, this.total = 0});

  final String nome;
  final String? cor;
  final int total;
}

/// Profissional (ou loja) perto do cliente.
class ProfissionalRegiao {
  const ProfissionalRegiao({
    required this.perfil,
    this.funcoes = const [],
    this.disponivelHoje = false,
    this.totalAvaliacoes = 0,
  });

  final PerfilProximo perfil;
  final List<OficioInfo> funcoes;
  final bool disponivelHoje;
  final int totalAvaliacoes;
}

/// Serviço com a média de avaliação dos atendimentos feitos com ele.
class ServicoAvaliado {
  const ServicoAvaliado({
    required this.servico,
    this.nota,
    this.totalAvaliacoes = 0,
    this.nomePrestador,
  });

  final ServicoProfissional servico;
  final double? nota;
  final int totalAvaliacoes;
  final String? nomePrestador;
}

class HomeClienteService {
  HomeClienteService._();

  static Future<int?> _meuIdUsuario() async {
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

  /// Nome e foto do usuário logado.
  static Future<({String nome, String? foto})?> meusDados() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    try {
      final u = await _db
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();
      if (u == null) return null;
      final foto = u['foto_perfil_url']?.toString().trim() ?? '';
      return (
        nome: u['nome']?.toString() ?? '',
        foto: foto.isEmpty || foto == 'null' ? null : foto,
      );
    } catch (_) {
      return null;
    }
  }

  /// Pedidos aceitos e ainda não concluídos/cancelados.
  static Future<List<PedidoAndamento>> pedidosEmAndamento() async {
    try {
      final idUsuario = await _meuIdUsuario();
      if (idUsuario == null) return const [];
      final rows = await _db
          .from('solicitacoes')
          .select(
            'id_solicitacao, fk_status, etapa_solicitacao, tipo_execucao, '
            'fk_profissional, fk_grupo_empresa, fk_servico_prof, '
            'fk_servico_temp, fk_endereco, '
            'status!solicitacoes_fk_status_fkey(status)',
          )
          .eq('fk_usuario', idUsuario)
          .order('data_solicitacao', ascending: false)
          .limit(30);
      final pedidos = <PedidoAndamento>[];
      for (final r in rows) {
        final rel = r['status'];
        final statusTexto =
            (rel is Map
                    ? rel['status']
                    : (rel is List && rel.isNotEmpty
                          ? (rel.first as Map)['status']
                          : null))
                ?.toString() ??
            '';
        final fluxo = FluxoSolicitacao(
          tipoExecucao: r['tipo_execucao']?.toString(),
          fkStatus: (r['fk_status'] as num?)?.toInt(),
          etapa: (r['etapa_solicitacao'] as num?)?.toInt() ?? 0,
          statusTexto: statusTexto,
        );
        final st = statusTexto.toLowerCase();
        if (fluxo.estaAberto ||
            fluxo.estaConcluido ||
            st.contains('cancel') ||
            st.contains('recus')) {
          continue;
        }

        String titulo = 'Serviço';
        String? foto;
        String? funcao;
        final idServ = (r['fk_servico_prof'] as num?)?.toInt();
        final idTemp = (r['fk_servico_temp'] as num?)?.toInt();
        try {
          final s = idServ != null
              ? await _db
                    .from('servicos_profissional')
                    .select('titulo, $kSelectFuncao')
                    .eq('id_servico_prof', idServ)
                    .maybeSingle()
              : idTemp != null
              ? await _db
                    .from('servicos_chat_temporarios')
                    .select('titulo, $kSelectFuncao')
                    .eq('id_servico_temp', idTemp)
                    .maybeSingle()
              : null;
          titulo = s?['titulo']?.toString() ?? titulo;
          funcao = nomeFuncao(s);
        } catch (_) {}

        String nome = 'Profissional';
        final idGrupo = (r['fk_grupo_empresa'] as num?)?.toInt();
        final idProf = (r['fk_profissional'] as num?)?.toInt();
        try {
          if (idGrupo != null) {
            final g = await _db
                .from('grupo_empresa')
                .select('nome_empresa, foto_url_empresa')
                .eq('id_grupo_empresa', idGrupo)
                .maybeSingle();
            nome = g?['nome_empresa']?.toString() ?? nome;
            foto = g?['foto_url_empresa']?.toString();
          } else if (idProf != null) {
            final d = await _db
                .from('dados_profissionais')
                .select('fk_usuario')
                .eq('id_profissional', idProf)
                .maybeSingle();
            final idU = (d?['fk_usuario'] as num?)?.toInt();
            if (idU != null) {
              final u = await _db
                  .from('usuarios')
                  .select('nome, foto_perfil_url')
                  .eq('id_usuario', idU)
                  .maybeSingle();
              nome = u?['nome']?.toString() ?? nome;
              foto = u?['foto_perfil_url']?.toString();
            }
          }
        } catch (_) {}

        String? rua;
        final idEnd = (r['fk_endereco'] as num?)?.toInt();
        if (idEnd != null) {
          try {
            final e = await _db
                .from('enderecos')
                .select('logradouro')
                .eq('id_endereco', idEnd)
                .maybeSingle();
            rua = e?['logradouro']?.toString();
          } catch (_) {}
        }

        pedidos.add(
          PedidoAndamento(
            id: (r['id_solicitacao'] as num).toInt(),
            titulo: titulo,
            nomePrestador: nome,
            foto: (foto ?? '').startsWith('http') ? foto : null,
            funcao: funcao,
            status: fluxo.rotuloPorModalidade ?? statusTexto,
            rua: rua,
            fluxo: fluxo,
          ),
        );
      }
      return pedidos;
    } catch (e) {
      debugPrint('[home] pedidos: $e');
      return const [];
    }
  }

  /// Categorias (ofícios) com mais funções cadastradas.
  static Future<List<CategoriaHome>> categorias() async {
    try {
      final rows = await _db.from('oficios').select('categoria, cor');
      final contagem = <String, int>{};
      final cores = <String, String?>{};
      for (final r in rows) {
        final c = r['categoria']?.toString().trim() ?? '';
        if (c.isEmpty) continue;
        contagem[c] = (contagem[c] ?? 0) + 1;
        cores[c] ??= r['cor']?.toString();
      }
      final lista = contagem.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (final e in lista)
          CategoriaHome(nome: e.key, cor: cores[e.key], total: e.value),
      ];
    } catch (e) {
      debugPrint('[home] categorias: $e');
      return const [];
    }
  }

  static const _diasSemana = [
    'domingo',
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
  ];

  /// Profissionais e lojas a até 5 km (mesmo raio do Radar), com funções e
  /// se atendem hoje.
  static Future<List<ProfissionalRegiao>> profissionaisNaRegiao(
    LatLng centro,
  ) async {
    try {
      final proximos = await SolicitacaoGeograficaService.buscarProximos(
        centro,
      );
      final unicos = <String, PerfilProximo>{};
      for (final p in proximos) {
        unicos.putIfAbsent(p.chave, () => p);
      }
      final perfis = unicos.values.toList()
        ..sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
      final idsProf = [
        for (final p in perfis)
          if (!p.ehEmpresa && p.idProfissional != null) p.idProfissional!,
      ];
      final idsGrupo = [
        for (final p in perfis)
          if (p.ehEmpresa && p.idGrupoEmpresa != null) p.idGrupoEmpresa!,
      ];

      final funcoesProf = <int, List<OficioInfo>>{};
      final funcoesGrupo = <int, List<OficioInfo>>{};
      if (idsProf.isNotEmpty) {
        final ass = await _db
            .from('ass_oficio_profissional')
            .select('fk_profissional, $kSelectFuncao')
            .inFilter('fk_profissional', idsProf);
        for (final a in ass) {
          final f = extrairFuncao(a);
          if (f == null) continue;
          funcoesProf
              .putIfAbsent((a['fk_profissional'] as num).toInt(), () => [])
              .add(OficioInfo.fromMap(f));
        }
      }
      if (idsGrupo.isNotEmpty) {
        try {
          final ass = await _db
              .from('ass_oficio_grupo_empresa')
              .select('fk_grupo_empresa, $kSelectFuncao')
              .inFilter('fk_grupo_empresa', idsGrupo);
          for (final a in ass) {
            final f = extrairFuncao(a);
            if (f == null) continue;
            funcoesGrupo
                .putIfAbsent((a['fk_grupo_empresa'] as num).toInt(), () => [])
                .add(OficioInfo.fromMap(f));
          }
        } catch (_) {}
      }

      // Atende hoje? (disponibilidade recorrente)
      final hoje = _diasSemana[DateTime.now().weekday % 7];
      final atendeHojeProf = <int>{};
      final atendeHojeGrupo = <int>{};
      try {
        final agendas = await _db
            .from('agenda_profissional')
            .select('fk_profissional, fk_grupo_empresa, dias_semana')
            .eq('fk_solicitacao', 0);
        for (final a in agendas) {
          final dias = a['dias_semana']?.toString().toLowerCase() ?? '';
          if (!dias.contains(hoje)) continue;
          final p = (a['fk_profissional'] as num?)?.toInt();
          final g = (a['fk_grupo_empresa'] as num?)?.toInt();
          if (p != null) atendeHojeProf.add(p);
          if (g != null) atendeHojeGrupo.add(g);
        }
      } catch (_) {}

      return [
        for (final p in perfis)
          ProfissionalRegiao(
            perfil: p,
            funcoes: p.ehEmpresa
                ? (funcoesGrupo[p.idGrupoEmpresa] ?? const [])
                : (funcoesProf[p.idProfissional] ?? const []),
            disponivelHoje: p.ehEmpresa
                ? atendeHojeGrupo.contains(p.idGrupoEmpresa)
                : atendeHojeProf.contains(p.idProfissional),
          ),
      ];
    } catch (e) {
      debugPrint('[home] região: $e');
      return const [];
    }
  }

  /// Todos os serviços ativos com a nota média (das avaliações dos pedidos
  /// feitos com cada serviço), do mais bem avaliado para o menos.
  static Future<List<ServicoAvaliado>> servicosPorAvaliacao() async {
    try {
      final rows = await _db
          .from('servicos_profissional')
          .select('*, $kSelectFuncao')
          .eq('ativo', true);
      final servicos = rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();
      if (servicos.isEmpty) return const [];

      final notas = <int, List<int>>{};
      try {
        final sols = await _db
            .from('solicitacoes')
            .select('id_solicitacao, fk_servico_prof')
            .inFilter('fk_servico_prof', servicos.map((s) => s.id).toList());
        final servicoDaSol = <int, int>{
          for (final s in sols)
            if (s['fk_servico_prof'] != null)
              (s['id_solicitacao'] as num).toInt():
                  (s['fk_servico_prof'] as num).toInt(),
        };
        if (servicoDaSol.isNotEmpty) {
          final avs = await _db
              .from('avaliacoes_solicitacao')
              .select('fk_solicitacao, nota')
              .eq('tipo_avaliacao', 'profissional')
              .inFilter('fk_solicitacao', servicoDaSol.keys.toList());
          for (final a in avs) {
            final idServ =
                servicoDaSol[(a['fk_solicitacao'] as num?)?.toInt() ?? -1];
            final nota = (a['nota'] as num?)?.toInt();
            if (idServ != null && nota != null) {
              notas.putIfAbsent(idServ, () => []).add(nota);
            }
          }
        }
      } catch (_) {}

      final lista = [
        for (final s in servicos)
          ServicoAvaliado(
            servico: s,
            nota: notas[s.id] == null
                ? null
                : notas[s.id]!.reduce((a, b) => a + b) / notas[s.id]!.length,
            totalAvaliacoes: notas[s.id]?.length ?? 0,
          ),
      ];
      lista.sort((a, b) {
        final c = (b.nota ?? -1).compareTo(a.nota ?? -1);
        if (c != 0) return c;
        return b.totalAvaliacoes.compareTo(a.totalAvaliacoes);
      });
      return lista;
    } catch (e) {
      debugPrint('[home] serviços: $e');
      return const [];
    }
  }
}
