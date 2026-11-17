import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_profissional.dart';
import '../utils/cor_oficio.dart';
import '../utils/fluxo_solicitacao.dart';
import '../utils/funcao_servico.dart';
import '../widgets/card_profissional_vitrine.dart';
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

  /// Profissionais (independentes) e lojas com funções, se atendem hoje
  /// (agenda), data de criação da conta, tag da loja e nota.
  static Future<List<ProfissionalVitrine>> _montarVitrine({
    required List<int> idsProf,
    required List<int> idsGrupo,
    Map<String, PerfilProximo> proximos = const {},
  }) async {
    // Dados dos profissionais
    final dadosProf = <int, Map<String, dynamic>>{};
    if (idsProf.isNotEmpty) {
      final rows = await _db
          .from('dados_profissionais')
          .select('id_profissional, fk_usuario, fk_grupo_empresa, fk_perfil')
          .inFilter('id_profissional', idsProf);
      for (final r in rows) {
        dadosProf[(r['id_profissional'] as num).toInt()] = r;
      }
    }
    final idsUsuario = {
      for (final d in dadosProf.values)
        if (d['fk_usuario'] != null) (d['fk_usuario'] as num).toInt(),
    };

    // Lojas: as pedidas + as dos funcionários + as que os donos têm.
    final grupos = <int, Map<String, dynamic>>{};
    final idsPerfil = {
      for (final d in dadosProf.values)
        if (d['fk_perfil'] != null) (d['fk_perfil'] as num).toInt(),
    };
    final idsGrupoBusca = {
      ...idsGrupo,
      for (final d in dadosProf.values)
        if (d['fk_grupo_empresa'] != null)
          (d['fk_grupo_empresa'] as num).toInt(),
    };
    try {
      if (idsGrupoBusca.isNotEmpty) {
        final rows = await _db
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, foto_url_empresa, tag_empresa, '
              'cor_tag_empresa, fk_perfil',
            )
            .inFilter('id_grupo_empresa', idsGrupoBusca.toList());
        for (final r in rows) {
          grupos[(r['id_grupo_empresa'] as num).toInt()] = r;
        }
      }
      if (idsPerfil.isNotEmpty) {
        final rows = await _db
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, foto_url_empresa, tag_empresa, '
              'cor_tag_empresa, fk_perfil',
            )
            .inFilter('fk_perfil', idsPerfil.toList());
        for (final r in rows) {
          grupos[(r['id_grupo_empresa'] as num).toInt()] = r;
        }
      }
    } catch (_) {}
    final grupoPorPerfil = <int, Map<String, dynamic>>{
      for (final g in grupos.values)
        if (g['fk_perfil'] != null) (g['fk_perfil'] as num).toInt(): g,
    };

    // Dono de cada loja (para a data de criação da conta).
    final donoPorGrupo = <int, int>{};
    final perfisDono = {
      for (final g in grupos.values)
        if (g['fk_perfil'] != null) (g['fk_perfil'] as num).toInt(),
    };
    if (perfisDono.isNotEmpty) {
      try {
        final rows = await _db
            .from('dados_profissionais')
            .select('fk_usuario, fk_perfil')
            .inFilter('fk_perfil', perfisDono.toList());
        for (final r in rows) {
          final perfil = (r['fk_perfil'] as num?)?.toInt();
          final usuario = (r['fk_usuario'] as num?)?.toInt();
          final g = perfil == null ? null : grupoPorPerfil[perfil];
          if (g != null && usuario != null) {
            donoPorGrupo[(g['id_grupo_empresa'] as num).toInt()] = usuario;
            idsUsuario.add(usuario);
          }
        }
      } catch (_) {}
    }

    // Usuários (nome, foto, criação)
    final usuarios = <int, Map<String, dynamic>>{};
    if (idsUsuario.isNotEmpty) {
      try {
        final rows = await _db
            .from('usuarios')
            .select('id_usuario, nome, foto_perfil_url, data_criacao')
            .inFilter('id_usuario', idsUsuario.toList());
        for (final r in rows) {
          usuarios[(r['id_usuario'] as num).toInt()] = r;
        }
      } catch (_) {}
    }

    // Funções
    final funcoesProf = <int, List<OficioInfo>>{};
    final funcoesGrupo = <int, List<OficioInfo>>{};
    try {
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
      }
    } catch (_) {}

    // Disponível hoje (agenda recorrente: "segunda-feira,terça-feira…")
    final hoje = _diasSemana[DateTime.now().weekday % 7];
    final hojeProf = <int>{};
    final hojeGrupo = <int>{};
    try {
      final agendas = await _db
          .from('agenda_profissional')
          .select('fk_profissional, fk_grupo_empresa, dias_semana')
          .eq('fk_solicitacao', 0);
      for (final a in agendas) {
        final dias = (a['dias_semana']?.toString().toLowerCase() ?? '')
            .split(',')
            .map((d) => d.trim());
        if (!dias.any((d) => d.startsWith(hoje))) continue;
        final p = (a['fk_profissional'] as num?)?.toInt();
        final g = (a['fk_grupo_empresa'] as num?)?.toInt();
        if (g != null) {
          hojeGrupo.add(g);
        } else if (p != null) {
          hojeProf.add(p);
        }
      }
    } catch (_) {}

    // Notas (quando não vieram do Radar)
    final notasProf = <int, List<int>>{};
    final notasGrupo = <int, List<int>>{};
    try {
      final avs = await _db
          .from('avaliacoes_solicitacao')
          .select('fk_solicitacao, nota')
          .eq('tipo_avaliacao', 'profissional');
      final idsSol = {
        for (final a in avs)
          if (a['fk_solicitacao'] != null) (a['fk_solicitacao'] as num).toInt(),
      };
      if (idsSol.isNotEmpty) {
        final sols = await _db
            .from('solicitacoes')
            .select('id_solicitacao, fk_profissional, fk_grupo_empresa')
            .inFilter('id_solicitacao', idsSol.toList());
        final solPorId = {
          for (final s in sols) (s['id_solicitacao'] as num).toInt(): s,
        };
        for (final a in avs) {
          final s = solPorId[(a['fk_solicitacao'] as num?)?.toInt() ?? -1];
          final nota = (a['nota'] as num?)?.toInt();
          if (s == null || nota == null) continue;
          final g = (s['fk_grupo_empresa'] as num?)?.toInt();
          final p = (s['fk_profissional'] as num?)?.toInt();
          if (g != null) {
            notasGrupo.putIfAbsent(g, () => []).add(nota);
          } else if (p != null) {
            notasProf.putIfAbsent(p, () => []).add(nota);
          }
        }
      }
    } catch (_) {}
    double? media(List<int>? l) =>
        l == null || l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
    DateTime? criacao(Map<String, dynamic>? u) =>
        DateTime.tryParse(u?['data_criacao']?.toString() ?? '')?.toLocal();

    final lista = <ProfissionalVitrine>[];
    for (final id in idsProf) {
      final d = dadosProf[id];
      if (d == null) continue;
      final u = usuarios[(d['fk_usuario'] as num?)?.toInt() ?? -1];
      final perto = proximos['p$id'];
      // Loja associada: funcionário (fk_grupo_empresa) ou dono (fk_perfil).
      final grupo =
          grupos[(d['fk_grupo_empresa'] as num?)?.toInt() ?? -1] ??
          grupoPorPerfil[(d['fk_perfil'] as num?)?.toInt() ?? -1];
      lista.add(
        ProfissionalVitrine(
          ehEmpresa: false,
          idProfissional: id,
          nome: perto?.nome ?? u?['nome']?.toString() ?? 'Profissional',
          foto: perto?.fotoUrl ?? u?['foto_perfil_url']?.toString(),
          nota: perto?.nota ?? media(notasProf[id]),
          totalAvaliacoes: notasProf[id]?.length ?? 0,
          funcoes: funcoesProf[id] ?? const [],
          disponivelHoje: hojeProf.contains(id),
          criadoEm: criacao(u),
          tagEmpresa: grupo?['tag_empresa']?.toString() ?? perto?.tagEmpresa,
          corTagEmpresa:
              grupo?['cor_tag_empresa']?.toString() ?? perto?.corTagEmpresa,
          distanciaKm: perto?.distanciaKm,
        ),
      );
    }
    for (final id in idsGrupo) {
      final g = grupos[id];
      final perto = proximos['e$id'];
      if (g == null && perto == null) continue;
      lista.add(
        ProfissionalVitrine(
          ehEmpresa: true,
          idGrupoEmpresa: id,
          nome: perto?.nome ?? g?['nome_empresa']?.toString() ?? 'Loja',
          foto: perto?.fotoUrl ?? g?['foto_url_empresa']?.toString(),
          nota: perto?.nota ?? media(notasGrupo[id]),
          totalAvaliacoes: notasGrupo[id]?.length ?? 0,
          funcoes: funcoesGrupo[id] ?? const [],
          disponivelHoje: hojeGrupo.contains(id),
          criadoEm: criacao(usuarios[donoPorGrupo[id] ?? -1]),
          tagEmpresa: g?['tag_empresa']?.toString() ?? perto?.tagEmpresa,
          corTagEmpresa:
              g?['cor_tag_empresa']?.toString() ?? perto?.corTagEmpresa,
          distanciaKm: perto?.distanciaKm,
        ),
      );
    }
    return lista;
  }

  /// Profissionais e lojas a até 5 km (mesmo raio do Radar).
  static Future<List<ProfissionalVitrine>> profissionaisNaRegiao(
    LatLng centro,
  ) async {
    try {
      final proximos = await SolicitacaoGeograficaService.buscarProximos(
        centro,
      );
      final porChave = <String, PerfilProximo>{};
      for (final p in proximos) {
        porChave.putIfAbsent(p.chave, () => p);
      }
      final lista = await _montarVitrine(
        idsProf: [
          for (final p in porChave.values)
            if (!p.ehEmpresa && p.idProfissional != null) p.idProfissional!,
        ],
        idsGrupo: [
          for (final p in porChave.values)
            if (p.ehEmpresa && p.idGrupoEmpresa != null) p.idGrupoEmpresa!,
        ],
        proximos: porChave,
      );
      lista.sort(
        (a, b) => (a.distanciaKm ?? 99).compareTo(b.distanciaKm ?? 99),
      );
      return lista;
    } catch (e) {
      debugPrint('[home] região: $e');
      return const [];
    }
  }

  /// Todos os profissionais independentes e lojas cadastrados.
  static Future<List<ProfissionalVitrine>> todosProfissionais() async {
    try {
      final dados = await _db
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa');
      final grupos = await _db.from('grupo_empresa').select('id_grupo_empresa');
      return await _montarVitrine(
        // Funcionários de loja aparecem pela loja; independentes sozinhos.
        idsProf: [
          for (final d in dados)
            if (d['fk_grupo_empresa'] == null)
              (d['id_profissional'] as num).toInt(),
        ],
        idsGrupo: [
          for (final g in grupos) (g['id_grupo_empresa'] as num).toInt(),
        ],
      );
    } catch (e) {
      debugPrint('[home] todos profissionais: $e');
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
