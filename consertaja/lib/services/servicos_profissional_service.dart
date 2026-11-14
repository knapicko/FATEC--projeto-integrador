import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_catalogo.dart';
import '../models/servico_profissional.dart';
import '../utils/funcao_servico.dart';

class ServicosProfissionalService {
  static SupabaseClient get _supabase => Supabase.instance.client;
  static const String _bucketServicos = 'Imagens Servicos';

  static Future<
    ({
      int idProfissional,
      int? idGrupoEmpresa,
      bool ehLoja,
      bool ehMembroEmpresa,
      bool ehDonoEmpresa,
    })?
  >
  buscarContextoAssociacao() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return null;
      final dados = await _supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa, fk_perfil')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();
      final idProfissional = (dados?['id_profissional'] as num?)?.toInt();
      if (idProfissional == null) return null;
      final idPerfil = (dados?['fk_perfil'] as num?)?.toInt();
      final perfil = idPerfil == null
          ? null
          : await _supabase
                .from('perfil')
                .select('tipo_perfil')
                .eq('id_perfil', idPerfil)
                .maybeSingle();
      final idGrupoEmpresa = (dados?['fk_grupo_empresa'] as num?)?.toInt();
      int? idPerfilDono;
      if (idGrupoEmpresa != null) {
        final grupo = await _supabase
            .from('grupo_empresa')
            .select('fk_perfil')
            .eq('id_grupo_empresa', idGrupoEmpresa)
            .maybeSingle();
        idPerfilDono = (grupo?['fk_perfil'] as num?)?.toInt();
      }
      final ehDonoEmpresa =
          idGrupoEmpresa != null &&
          idPerfil != null &&
          idPerfilDono == idPerfil;
      return (
        idProfissional: idProfissional,
        idGrupoEmpresa: idGrupoEmpresa,
        ehLoja:
            perfil?['tipo_perfil']?.toString().trim().toLowerCase() == 'loja',
        ehMembroEmpresa: idGrupoEmpresa != null && !ehDonoEmpresa,
        ehDonoEmpresa: ehDonoEmpresa,
      );
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarContextoAssociacao ERROR: $e');
      return null;
    }
  }

  static Future<bool> profissionalEhMembroEmpresa(int idProfissional) async {
    try {
      final dados = await _supabase
          .from('dados_profissionais')
          .select('fk_grupo_empresa, fk_perfil')
          .eq('id_profissional', idProfissional)
          .maybeSingle();
      final idGrupo = (dados?['fk_grupo_empresa'] as num?)?.toInt();
      final idPerfil = (dados?['fk_perfil'] as num?)?.toInt();
      if (idGrupo == null || idPerfil == null) return false;
      final grupo = await _supabase
          .from('grupo_empresa')
          .select('fk_perfil')
          .eq('id_grupo_empresa', idGrupo)
          .maybeSingle();
      final idPerfilDono = (grupo?['fk_perfil'] as num?)?.toInt();
      return idPerfilDono != null && idPerfilDono != idPerfil;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] profissionalEhMembroEmpresa ERROR: $e');
      return false;
    }
  }

  // ── Identidade ─────────────────────────────────────────────────────────────

  static Future<int?> buscarIdProfissional() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ [ServicosSvc] Usuário não autenticado.');
        return null;
      }

      final usuarioRow = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioRow == null) {
        debugPrint('❌ [ServicosSvc] Usuário não encontrado.');
        return null;
      }

      final idUsuario = (usuarioRow['id_usuario'] as num).toInt();

      final dadosProfRow = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();

      if (dadosProfRow == null) {
        debugPrint('❌ [ServicosSvc] dados_profissionais não encontrado.');
        return null;
      }

      final idProfissional = (dadosProfRow['id_profissional'] as num).toInt();
      debugPrint('✅ [ServicosSvc] id_profissional: $idProfissional');
      return idProfissional;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarIdProfissional ERROR: $e');
      return null;
    }
  }

  // ── Upload de imagem ────────────────────────────────────────────────────────

  /// Faz upload de uma imagem para o bucket 'Imagens Servicos' e retorna a URL pública.
  static Future<String?> uploadImagemServico(XFile imagem) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      debugPrint('📤 [ServicosSvc] Upload imagem: $fileName');

      if (kIsWeb) {
        final bytes = await imagem.readAsBytes();
        await _supabase.storage
            .from(_bucketServicos)
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      } else {
        await _supabase.storage
            .from(_bucketServicos)
            .upload(
              fileName,
              File(imagem.path),
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      }

      final url = _supabase.storage
          .from(_bucketServicos)
          .getPublicUrl(fileName);
      debugPrint('✅ [ServicosSvc] URL da imagem: $url');
      return url;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] uploadImagemServico ERROR: $e');
      return null;
    }
  }

  // ── CRUD dos serviços do profissional ──────────────────────────────────────

  /// Lista todos os serviços ativos do profissional.
  /// Se `idProfissional` for informado, busca por ele. Caso contrário, busca do profissional logado.
  /// Faz join (left join) com `oficios` para obter funcao e cod_cor.
  static Future<List<ServicoProfissional>> buscarServicos({
    int? idProfissional,
  }) async {
    try {
      final idProf = idProfissional ?? await buscarIdProfissional();
      if (idProf == null) return [];

      final rows = await _supabase
          .from('servicos_profissional')
          .select('*, $kSelectFuncao')
          .eq('fk_profissional', idProf)
          .eq('ativo', true)
          .order('data_criacao', ascending: false);

      return rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarServicos ERROR: $e');
      return [];
    }
  }

  /// Cria um novo serviço. Opcionalmente faz upload da imagem antes.
  static Future<({bool sucesso, int? id, String? erro})> criarServico({
    required String titulo,
    required String descricao,
    required double valor,
    required int fkFuncao,
    String? imagemUrl,
    XFile? imagemLocal,
    int? fkGrupoEmpresa,
    String tipoExecucao = 'Execução',
    String cargaServico = 'Médio',
  }) async {
    try {
      final contexto = await buscarContextoAssociacao();
      if (contexto?.ehMembroEmpresa == true) {
        return (
          sucesso: false,
          id: null,
          erro: 'Membros de uma empresa não podem criar serviços próprios.',
        );
      }
      final idProf = await buscarIdProfissional();
      if (idProf == null) {
        return (
          sucesso: false,
          id: null,
          erro: 'Profissional não encontrado. Verifique o cadastro.',
        );
      }

      // Faz upload da imagem se foi escolhida localmente
      String? urlFinal = imagemUrl;
      if (imagemLocal != null) {
        urlFinal = await uploadImagemServico(imagemLocal);
      }

      final fkOficio = await buscarOficioDaFuncao(fkFuncao);
      final response = await _supabase
          .from('servicos_profissional')
          .insert({
            'titulo': titulo.trim(),
            'descricao': descricao.trim(),
            'valor': valor,
            'fk_oficios': fkOficio,
            'fk_funcao': fkFuncao,
            'imagem_url': urlFinal,
            'ativo': true,
            'fk_profissional': idProf,
            'fk_grupo_empresa': fkGrupoEmpresa,
            'tipo_execucao': tipoExecucao,
            'carga_servico': cargaServico,
          })
          .select('id_servico_prof')
          .single();

      final id = (response['id_servico_prof'] as num).toInt();
      debugPrint('✅ [ServicosSvc] Serviço criado! id=$id');
      return (sucesso: true, id: id, erro: null);
    } catch (e) {
      debugPrint('❌ [ServicosSvc] criarServico ERROR: $e');
      return (sucesso: false, id: null, erro: 'Erro ao salvar serviço: $e');
    }
  }

  /// Atualiza um serviço existente. Opcionalmente faz upload de nova imagem.
  static Future<({bool sucesso, String? erro})> atualizarServico({
    required int id,
    required String titulo,
    required String descricao,
    required double valor,
    required int fkFuncao,
    String? imagemUrl,
    XFile? imagemLocal,
    int? fkGrupoEmpresa,
    String tipoExecucao = 'Execução',
    String cargaServico = 'Médio',
  }) async {
    try {
      final contexto = await buscarContextoAssociacao();
      if (contexto?.ehMembroEmpresa == true) {
        return (
          sucesso: false,
          erro: 'Membros de uma empresa não podem editar serviços próprios.',
        );
      }
      // Faz upload da nova imagem se foi escolhida
      String? urlFinal = imagemUrl;
      if (imagemLocal != null) {
        urlFinal = await uploadImagemServico(imagemLocal);
      }

      final fkOficio = await buscarOficioDaFuncao(fkFuncao);
      await _supabase
          .from('servicos_profissional')
          .update({
            'titulo': titulo.trim(),
            'descricao': descricao.trim(),
            'valor': valor,
            'fk_oficios': fkOficio,
            'fk_funcao': fkFuncao,
            'imagem_url': urlFinal,
            'fk_grupo_empresa': fkGrupoEmpresa,
            'tipo_execucao': tipoExecucao,
            'carga_servico': cargaServico,
            'data_alteracao': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id_servico_prof', id);

      debugPrint('✅ [ServicosSvc] Serviço atualizado! id=$id');
      return (sucesso: true, erro: null);
    } catch (e) {
      debugPrint('❌ [ServicosSvc] atualizarServico ERROR: $e');
      return (sucesso: false, erro: 'Erro ao atualizar serviço: $e');
    }
  }

  static Future<List<ServicoProfissional>> buscarServicosEmpresa(
    int idGrupoEmpresa,
  ) async {
    try {
      final rows = await _supabase
          .from('servicos_profissional')
          .select('*, $kSelectFuncao')
          .eq('fk_grupo_empresa', idGrupoEmpresa)
          .eq('ativo', true)
          .order('data_criacao', ascending: false);
      final List<ServicoProfissional> servicos = rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();

      final Set<int> idsExistentes = servicos.map((s) => s.id).toSet();

      // Busca profissionais vinculados à empresa (membros e proprietário)
      final List<int> profIds = [];

      final membros = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_grupo_empresa', idGrupoEmpresa);
      for (final m in membros) {
        final id = (m['id_profissional'] as num?)?.toInt();
        if (id != null) profIds.add(id);
      }

      final grupoRow = await _supabase
          .from('grupo_empresa')
          .select('fk_perfil')
          .eq('id_grupo_empresa', idGrupoEmpresa)
          .maybeSingle();

      if (grupoRow != null && grupoRow['fk_perfil'] != null) {
        final fkPerfilDono = (grupoRow['fk_perfil'] as num).toInt();
        final dono = await _supabase
            .from('dados_profissionais')
            .select('id_profissional')
            .eq('fk_perfil', fkPerfilDono)
            .maybeSingle();
        if (dono != null) {
          final id = (dono['id_profissional'] as num?)?.toInt();
          if (id != null && !profIds.contains(id)) profIds.add(id);
        }
      }

      if (profIds.isNotEmpty) {
        final rowsProf = await _supabase
            .from('servicos_profissional')
            .select('*, $kSelectFuncao')
            .filter('fk_profissional', 'in', profIds)
            .eq('ativo', true)
            .order('data_criacao', ascending: false);

        for (final r in rowsProf) {
          final s = ServicoProfissional.fromMap(r);
          if (!idsExistentes.contains(s.id)) {
            servicos.add(s);
            idsExistentes.add(s.id);
          }
        }
      }

      return servicos;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarServicosEmpresa ERROR: $e');
      return [];
    }
  }

  static Future<DetalheServicoPublico?> buscarDetalhePublico(
    int idServico,
  ) async {
    try {
      final row = await _supabase
          .from('servicos_profissional')
          .select('*, $kSelectFuncao')
          .eq('id_servico_prof', idServico)
          .eq('ativo', true)
          .maybeSingle();
      if (row == null) return null;

      final servico = ServicoProfissional.fromMap(row);
      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_usuario, fk_grupo_empresa, fk_perfil')
          .eq('id_profissional', servico.fkProfissional)
          .maybeSingle();
      if (dadosProf == null) return null;

      final idPerfilProf = (dadosProf['fk_perfil'] as num?)?.toInt();
      final idUsuarioProf = (dadosProf['fk_usuario'] as num?)?.toInt();
      // A identidade exibida é determinada pelo próprio serviço. Um vínculo
      // do profissional com uma empresa não transforma automaticamente um
      // serviço independente em serviço da empresa.
      final idGrupo = servico.fkGrupoEmpresa;

      Map<String, dynamic>? grupo;
      if (idGrupo != null) {
        grupo = await _supabase
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, fk_perfil',
            )
            .eq('id_grupo_empresa', idGrupo)
            .maybeSingle();
      }

      String tipoPerfil = '';
      if (idPerfilProf != null) {
        final perfil = await _supabase
            .from('perfil')
            .select('tipo_perfil')
            .eq('id_perfil', idPerfilProf)
            .maybeSingle();
        tipoPerfil =
            perfil?['tipo_perfil']?.toString().trim().toLowerCase() ?? '';
      }

      final ehLoja = idGrupo != null && grupo != null;

      String tipoPrestador = 'cpf';
      if (ehLoja) {
        tipoPrestador = 'empresa';
      } else if (tipoPerfil == 'independente') {
        tipoPrestador = 'independente';
      } else if (idUsuarioProf != null) {
        try {
          final uTipo = await _supabase
              .from('usuarios')
              .select('fk_tipo_pessoa')
              .eq('id_usuario', idUsuarioProf)
              .maybeSingle();
          final fkT = uTipo?['fk_tipo_pessoa'];
          if (fkT != null) {
            final assT = await _supabase
                .from('ass_tipo_pessoa')
                .select('fk_pessoa_juridica, fk_pessoa_fisica')
                .eq('id_tipo_pessoa', fkT)
                .maybeSingle();
            if (assT?['fk_pessoa_juridica'] != null) {
              tipoPrestador = 'independente';
            } else {
              tipoPrestador = 'cpf';
            }
          }
        } catch (_) {}
      }

      String nomePrestador = 'Profissional';
      String? fotoPrestador;
      int? idPerfilPrestador = idPerfilProf;
      int? idUsuarioEndereco = idUsuarioProf;

      if (ehLoja && grupo != null) {
        nomePrestador =
            grupo['nome_empresa']?.toString().trim().isNotEmpty == true
            ? grupo['nome_empresa'].toString().trim()
            : 'Loja';
        fotoPrestador = grupo['foto_url_empresa']?.toString();
        idPerfilPrestador =
            (grupo['fk_perfil'] as num?)?.toInt() ?? idPerfilProf;
        if (idPerfilPrestador != null) {
          final dono = await _supabase
              .from('dados_profissionais')
              .select('fk_usuario')
              .eq('fk_perfil', idPerfilPrestador)
              .maybeSingle();
          idUsuarioEndereco =
              (dono?['fk_usuario'] as num?)?.toInt() ?? idUsuarioProf;
        }
      } else if (idUsuarioProf != null) {
        final usuario = await _supabase
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', idUsuarioProf)
            .maybeSingle();
        nomePrestador = usuario?['nome']?.toString().trim() ?? nomePrestador;
        fotoPrestador = usuario?['foto_perfil_url']?.toString();
      }

      int seguidores = 0;
      if (idPerfilPrestador != null) {
        final lista = await _supabase
            .from('seguidores_profissional')
            .select('id_seguidor_profissional')
            .eq('fk_perfil', idPerfilPrestador);
        seguidores = lista.length;
      }

      final endereco = await _buscarEnderecoPrestador(
        ehLoja: ehLoja,
        tipoPrestador: tipoPrestador,
        idGrupo: idGrupo,
        idProfissional: servico.fkProfissional,
        idUsuarioFallback: idUsuarioEndereco,
      );

      String? tagEmpresa = grupo?['tag_empresa']?.toString().trim();
      if (tagEmpresa != null &&
          tagEmpresa.isNotEmpty &&
          !tagEmpresa.startsWith('#')) {
        tagEmpresa = '#$tagEmpresa';
      }

      return DetalheServicoPublico(
        servico: servico,
        nomePrestador: nomePrestador,
        fotoPrestador: fotoPrestador,
        ehLoja: ehLoja,
        tipoPrestador: tipoPrestador,
        tagEmpresa: (tagEmpresa == null || tagEmpresa.isEmpty)
            ? null
            : tagEmpresa,
        corTagEmpresa: grupo?['cor_tag_empresa']?.toString(),
        idGrupoEmpresa: idGrupo,
        idProfissional: servico.fkProfissional,
        idPerfilPrestador: idPerfilPrestador,
        fotoBannerEmpresa: grupo?['foto_url_empresa']?.toString(),
        seguidores: seguidores,
        enderecoFormatado: endereco?.texto ?? 'Endereço não cadastrado',
        latitude: endereco?.lat ?? -23.5505,
        longitude: endereco?.lng ?? -46.6333,
        temCoordenadas: endereco?.temCoords ?? false,
      );
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarDetalhePublico ERROR: $e');
      return null;
    }
  }

  static Future<List<ServicoBuscaPublico>> buscarServicosPublicos(
    String termo,
  ) async {
    try {
      final rows = await _supabase
          .from('servicos_profissional')
          .select('*, $kSelectFuncao')
          .eq('ativo', true)
          .order('data_criacao', ascending: false);

      final servicos = rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();
      if (servicos.isEmpty) return [];

      final idsProf = servicos.map((s) => s.fkProfissional).toSet().toList();
      final dadosRows = await _supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_usuario, fk_grupo_empresa, fk_perfil')
          .inFilter('id_profissional', idsProf);

      final dadosPorProf = <int, Map<String, dynamic>>{};
      final idsPerfil = <int>{};
      final idsUsuario = <int>{};
      final idsGrupo = <int>{};
      for (final row in dadosRows) {
        final idProf = (row['id_profissional'] as num?)?.toInt();
        if (idProf == null) continue;
        dadosPorProf[idProf] = Map<String, dynamic>.from(row);
        final idPerfil = (row['fk_perfil'] as num?)?.toInt();
        final idUsuario = (row['fk_usuario'] as num?)?.toInt();
        final idGrupo = (row['fk_grupo_empresa'] as num?)?.toInt();
        if (idPerfil != null) idsPerfil.add(idPerfil);
        if (idUsuario != null) idsUsuario.add(idUsuario);
        if (idGrupo != null) idsGrupo.add(idGrupo);
      }
      for (final servico in servicos) {
        if (servico.fkGrupoEmpresa != null)
          idsGrupo.add(servico.fkGrupoEmpresa!);
      }

      final tipoPorPerfil = <int, String>{};
      if (idsPerfil.isNotEmpty) {
        final perfis = await _supabase
            .from('perfil')
            .select('id_perfil, tipo_perfil')
            .inFilter('id_perfil', idsPerfil.toList());
        for (final perfil in perfis) {
          final id = (perfil['id_perfil'] as num?)?.toInt();
          if (id != null) {
            tipoPorPerfil[id] =
                perfil['tipo_perfil']?.toString().trim().toLowerCase() ?? '';
          }
        }
      }

      final gruposPorId = <int, Map<String, dynamic>>{};
      if (idsGrupo.isNotEmpty) {
        final grupos = await _supabase
            .from('grupo_empresa')
            .select('id_grupo_empresa, nome_empresa, tag_empresa, fk_perfil')
            .inFilter('id_grupo_empresa', idsGrupo.toList());
        for (final grupo in grupos) {
          final id = (grupo['id_grupo_empresa'] as num?)?.toInt();
          if (id != null) gruposPorId[id] = Map<String, dynamic>.from(grupo);
        }
      }

      Map<String, dynamic>? dadosPorPerfil(int? idPerfil) {
        if (idPerfil == null) return null;
        for (final dados in dadosPorProf.values) {
          if ((dados['fk_perfil'] as num?)?.toInt() == idPerfil) return dados;
        }
        return null;
      }

      final idsUsuarioEndereco = <int>{...idsUsuario};
      for (final grupo in gruposPorId.values) {
        final dono = dadosPorPerfil((grupo['fk_perfil'] as num?)?.toInt());
        final idUsuarioDono = (dono?['fk_usuario'] as num?)?.toInt();
        if (idUsuarioDono != null) idsUsuarioEndereco.add(idUsuarioDono);
      }

      final enderecoPorUsuario = <int, String>{};
      for (final idUsuario in idsUsuarioEndereco) {
        final endereco = await _buscarEnderecoPrincipalUsuario(idUsuario);
        if (endereco != null) {
          enderecoPorUsuario[idUsuario] = endereco.resumo;
        }
      }

      String normalizar(String texto) {
        return texto
            .toLowerCase()
            .replaceAll('á', 'a')
            .replaceAll('à', 'a')
            .replaceAll('ã', 'a')
            .replaceAll('â', 'a')
            .replaceAll('é', 'e')
            .replaceAll('ê', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ô', 'o')
            .replaceAll('õ', 'o')
            .replaceAll('ú', 'u')
            .replaceAll('ç', 'c');
      }

      final termoNorm = normalizar(termo);
      final palavras = termoNorm
          .split(RegExp(r'\s+'))
          .where((p) => p.length > 1)
          .toList();

      bool corresponde(List<String> termos) {
        bool combina(String item) {
          final itemNorm = normalizar(item);
          return itemNorm.contains(termoNorm) || termoNorm.contains(itemNorm);
        }

        if (palavras.isEmpty) return termos.any(combina);
        return palavras.any(
          (palavra) => termos.any((t) {
            final tNorm = normalizar(t);
            return tNorm.contains(palavra) || palavra.contains(tNorm);
          }),
        );
      }

      final resultado = <ServicoBuscaPublico>[];
      for (final servico in servicos) {
        final dados = dadosPorProf[servico.fkProfissional];
        final idPerfil = (dados?['fk_perfil'] as num?)?.toInt();
        final idGrupoProf = (dados?['fk_grupo_empresa'] as num?)?.toInt();
        final tipo = idPerfil == null ? '' : (tipoPorPerfil[idPerfil] ?? '');
        final ehLoja = tipo == 'loja' || servico.fkGrupoEmpresa != null;
        final ehIndependente =
            tipo.contains('independente') || (!ehLoja && tipo.isEmpty);

        // Se o profissional faz parte de alguma empresa/loja, seus serviços não devem aparecer individualmente
        if (!ehLoja && idGrupoProf != null) {
          continue;
        }

        // Permite apenas serviços de profissionais independentes (sem empresa) ou de lojas
        if (!ehLoja && !ehIndependente) {
          continue;
        }

        final idGrupoServico =
            servico.fkGrupoEmpresa ?? (ehLoja ? idGrupoProf : null);
        final grupo = idGrupoServico != null
            ? gruposPorId[idGrupoServico]
            : null;
        var tag = grupo?['tag_empresa']?.toString().trim();
        if (tag != null && tag.isNotEmpty && !tag.startsWith('#')) {
          tag = '#$tag';
        }
        final nomeEmpresa = grupo?['nome_empresa']?.toString() ?? '';
        final categoria = servico.funcao?.trim().isNotEmpty == true
            ? servico.funcao!.trim()
            : 'Serviço';

        final termos = <String>[
          servico.titulo,
          categoria,
          tag ?? '',
          nomeEmpresa,
        ];
        if (!corresponde(termos)) continue;

        int? idUsuarioEndereco = (dados?['fk_usuario'] as num?)?.toInt();
        if (grupo != null) {
          final dono = dadosPorPerfil((grupo['fk_perfil'] as num?)?.toInt());
          idUsuarioEndereco =
              (dono?['fk_usuario'] as num?)?.toInt() ?? idUsuarioEndereco;
        }

        resultado.add(
          ServicoBuscaPublico(
            id: servico.id,
            titulo: servico.titulo,
            preco: servico.valor,
            categoria: categoria,
            servico: servico,
            tipoExecucao: servico.tipoExecucao,
            tagEmpresa: (tag == null || tag.isEmpty) ? null : tag,
            imagemUrl: servico.imagemUrl,
            localizacao: idUsuarioEndereco == null
                ? 'Localização não informada'
                : (enderecoPorUsuario[idUsuarioEndereco] ??
                      'Localização não informada'),
          ),
        );
      }
      return resultado;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarServicosPublicos ERROR: $e');
      rethrow;
    }
  }

  /// Endereco do PRESTADOR distinguindo o tipo de conta (igual ao
  /// meus_enderecos.dart):
  /// - Loja (grupo_empresa) -> ass_grupo_empresa_endereco (ativo primeiro).
  /// - Independente (CNPJ)   -> ass_profissional_endereco (ativo primeiro).
  /// - Fallback legado       -> ass_usuario_endereco (Loja/Oficina/Outro).
  static Future<
    ({String texto, String resumo, double lat, double lng, bool temCoords})?
  >
  _buscarEnderecoPrestador({
    required bool ehLoja,
    String? tipoPrestador,
    int? idGrupo,
    int? idProfissional,
    int? idUsuarioFallback,
  }) async {
    try {
      // 1. Loja: vínculo da empresa.
      if (ehLoja && idGrupo != null) {
        try {
          final vinculos = await _supabase
              .from('ass_grupo_empresa_endereco')
              .select('fk_endereco, endereco_ativo')
              .eq('fk_grupo_empresa', idGrupo);
          final fk = _escolherFkEnderecoAtivo(vinculos);
          if (fk != null) {
            final endereco = await _lerEnderecoFisico(fk);
            if (endereco != null) return endereco;
          }
        } catch (_) {
          final vinculos = await _supabase
              .from('ass_grupo_empresa_endereco')
              .select('fk_endereco')
              .eq('fk_grupo_empresa', idGrupo);
          final fk = _escolherFkEnderecoAtivo(vinculos);
          if (fk != null) {
            final endereco = await _lerEnderecoFisico(fk);
            if (endereco != null) return endereco;
          }
        }
      }
      // 2. Independente (CNPJ): vínculo comercial do profissional.
      if (!ehLoja && idProfissional != null) {
        try {
          final vinculos = await _supabase
              .from('ass_profissional_endereco')
              .select('fk_endereco, endereco_ativo')
              .eq('fk_profissional', idProfissional);
          final fk = _escolherFkEnderecoAtivo(vinculos);
          if (fk != null) {
            final endereco = await _lerEnderecoFisico(fk);
            if (endereco != null) return endereco;
          }
        } catch (_) {
          try {
            final vinculos = await _supabase
                .from('ass_profissional_endereco')
                .select('fk_endereco')
                .eq('fk_profissional', idProfissional);
            final fk = _escolherFkEnderecoAtivo(vinculos);
            if (fk != null) {
              final endereco = await _lerEnderecoFisico(fk);
              if (endereco != null) return endereco;
            }
          } catch (_) {}
        }
      }
      // 3. Fallback legado: endereço comercial do dono em
      // ass_usuario_endereco (Loja/Oficina/Outro) — mesma regra do
      // meus_enderecos.dart antes da migration nova.
      if (idUsuarioFallback != null) {
        try {
          final vinculos = await _supabase
              .from('ass_usuario_endereco')
              .select('fk_endereco, apelido_endereco, endereco_ativo')
              .eq('fk_usuario', idUsuarioFallback)
              .inFilter('tipo_endereco', ['Loja', 'Oficina', 'Outro'])
              .limit(5);
          final fk = _escolherFkEnderecoAtivo(vinculos);
          if (fk != null) {
            final endereco = await _lerEnderecoFisico(fk);
            if (endereco != null) return endereco;
          }
        } catch (_) {}
      }
      return null;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] _buscarEnderecoPrestador ERROR: $e');
      return null;
    }
  }

  /// Prioriza o vínculo com endereco_ativo = true; senão, o primeiro.
  static int? _escolherFkEnderecoAtivo(List vinculos) {
    if (vinculos.isEmpty) return null;
    Map? ativo;
    for (final v in vinculos) {
      if ((v as Map)['endereco_ativo'] == true) {
        ativo = v;
        break;
      }
    }
    ativo ??= vinculos.first as Map;
    final fk = ativo['fk_endereco'];
    return fk is int ? fk : int.tryParse(fk?.toString() ?? '');
  }

  /// Lê enderecos + cidades + estados e monta texto/resumo/coords.
  static Future<
    ({String texto, String resumo, double lat, double lng, bool temCoords})?
  >
  _lerEnderecoFisico(int idEndereco) async {
    try {
      final endereco = await _supabase
          .from('enderecos')
          .select(
            'cep, logradouro, numero, bairro, complemento, fk_cidade, latitude, longitude',
          )
          .eq('id_endereco', idEndereco)
          .maybeSingle();
      if (endereco == null) return null;

      String cidade = '';
      String estado = '';
      final idCidade = (endereco['fk_cidade'] as num?)?.toInt();
      if (idCidade != null) {
        final cidadeRow = await _supabase
            .from('cidades')
            .select('nome_cidade, fk_estado')
            .eq('id_cidade', idCidade)
            .maybeSingle();
        cidade = cidadeRow?['nome_cidade']?.toString() ?? '';
        final idEstado = (cidadeRow?['fk_estado'] as num?)?.toInt();
        if (idEstado != null) {
          final estadoRow = await _supabase
              .from('estados')
              .select('sigla_estado')
              .eq('id_estado', idEstado)
              .maybeSingle();
          estado = estadoRow?['sigla_estado']?.toString() ?? '';
        }
      }

      final logradouro = endereco['logradouro']?.toString() ?? '';
      final numero = endereco['numero']?.toString() ?? '';
      final bairro = endereco['bairro']?.toString() ?? '';
      final cep = endereco['cep']?.toString() ?? '';
      final partes = <String>[];
      if (logradouro.isNotEmpty) {
        partes.add(numero.isNotEmpty ? '$logradouro, $numero' : logradouro);
      }
      if (bairro.isNotEmpty) partes.add(bairro);
      if (cidade.isNotEmpty) {
        partes.add(estado.isNotEmpty ? '$cidade, $estado' : cidade);
      }
      if (cep.isNotEmpty) partes.add(cep);

      final lat = double.tryParse(endereco['latitude']?.toString() ?? '');
      final lng = double.tryParse(endereco['longitude']?.toString() ?? '');
      return (
        texto: partes.join(', '),
        resumo: bairro.isNotEmpty
            ? bairro
            : (cidade.isNotEmpty
                  ? cidade
                  : (logradouro.isNotEmpty
                        ? logradouro
                        : 'Localização não informada')),
        lat: lat ?? -23.5505,
        lng: lng ?? -46.6333,
        temCoords: lat != null && lng != null,
      );
    } catch (e) {
      debugPrint('❌ [ServicosSvc] _lerEnderecoFisico ERROR: $e');
      return null;
    }
  }

  static Future<
    ({String texto, String resumo, double lat, double lng, bool temCoords})?
  >
  _buscarEnderecoPrincipalUsuario(int idUsuario) async {
    try {
      final assList = await _supabase
          .from('ass_usuario_endereco')
          .select(
            'fk_endereco, apelido_endereco, tipo_endereco, endereco_ativo',
          )
          .eq('fk_usuario', idUsuario)
          .eq('endereco_ativo', true)
          .limit(1);
      if (assList.isEmpty) return null;
      final fkEndereco = assList.first['fk_endereco'];
      final idEndereco = fkEndereco is int
          ? fkEndereco
          : int.tryParse(fkEndereco?.toString() ?? '');
      if (idEndereco == null) return null;

      final endereco = await _supabase
          .from('enderecos')
          .select(
            'cep, logradouro, numero, bairro, complemento, fk_cidade, latitude, longitude',
          )
          .eq('id_endereco', idEndereco)
          .maybeSingle();
      if (endereco == null) return null;

      String cidade = '';
      String estado = '';
      final idCidade = (endereco['fk_cidade'] as num?)?.toInt();
      if (idCidade != null) {
        final cidadeRow = await _supabase
            .from('cidades')
            .select('nome_cidade, fk_estado')
            .eq('id_cidade', idCidade)
            .maybeSingle();
        cidade = cidadeRow?['nome_cidade']?.toString() ?? '';
        final idEstado = (cidadeRow?['fk_estado'] as num?)?.toInt();
        if (idEstado != null) {
          final estadoRow = await _supabase
              .from('estados')
              .select('sigla_estado')
              .eq('id_estado', idEstado)
              .maybeSingle();
          estado = estadoRow?['sigla_estado']?.toString() ?? '';
        }
      }

      final logradouro = endereco['logradouro']?.toString() ?? '';
      final numero = endereco['numero']?.toString() ?? '';
      final bairro = endereco['bairro']?.toString() ?? '';
      final cep = endereco['cep']?.toString() ?? '';
      final partes = <String>[];
      if (logradouro.isNotEmpty) {
        partes.add(numero.isNotEmpty ? '$logradouro, $numero' : logradouro);
      }
      if (bairro.isNotEmpty) partes.add(bairro);
      if (cidade.isNotEmpty) {
        partes.add(estado.isNotEmpty ? '$cidade, $estado' : cidade);
      }
      if (cep.isNotEmpty) partes.add(cep);

      final lat = double.tryParse(endereco['latitude']?.toString() ?? '');
      final lng = double.tryParse(endereco['longitude']?.toString() ?? '');
      return (
        texto: partes.join(', '),
        resumo: bairro.isNotEmpty
            ? bairro
            : (cidade.isNotEmpty
                  ? cidade
                  : (logradouro.isNotEmpty
                        ? logradouro
                        : 'Localização não informada')),
        lat: lat ?? -23.5505,
        lng: lng ?? -46.6333,
        temCoords: lat != null && lng != null,
      );
    } catch (e) {
      debugPrint('❌ [ServicosSvc] _buscarEnderecoPrincipalUsuario ERROR: $e');
      return null;
    }
  }

  /// Remove (soft delete) um serviço.
  static Future<bool> desativarServico(int id) async {
    try {
      await _supabase
          .from('servicos_profissional')
          .update({
            'ativo': false,
            'data_alteracao': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id_servico_prof', id);
      debugPrint('✅ [ServicosSvc] Serviço desativado id=$id');
      return true;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] desativarServico ERROR: $e');
      return false;
    }
  }

  /// Remove permanentemente um serviço.
  static Future<bool> deletarServico(int id) async {
    try {
      await _supabase
          .from('servicos_profissional')
          .delete()
          .eq('id_servico_prof', id);
      debugPrint('✅ [ServicosSvc] Serviço deletado id=$id');
      return true;
    } catch (e) {
      debugPrint('❌ [ServicosSvc] deletarServico ERROR: $e');
      return false;
    }
  }

  // ── Funções (tabela `funcoes`) ────────────────────────────────────────────

  /// Funções que o profissional logado pode escolher ao criar um serviço:
  /// somente as funções marcadas na conta dele (`ass_oficio_profissional.fk_funcao`,
  /// Área de Atuação). `id` é o `id_funcao`.
  static Future<List<({int id, String funcao, String cor})>>
  buscarFuncoesDoProfissional() async {
    try {
      final idProfissional = await buscarIdProfissional();
      if (idProfissional == null) return [];

      final vinculos = await _supabase
          .from('ass_oficio_profissional')
          .select('fk_funcao')
          .eq('fk_profissional', idProfissional);
      final ids = vinculos
          .map((row) => (row['fk_funcao'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      return _funcoesPorIds(ids);
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarFuncoesDoProfissional ERROR: $e');
      return [];
    }
  }

  /// Busca em `funcoes` as funções informadas (ids das associações).
  static Future<List<({int id, String funcao, String cor})>> _funcoesPorIds(
    List<int> idsOficios,
  ) async {
    if (idsOficios.isEmpty) return [];
    final rows = await _supabase
        .from('funcoes')
        .select('id_funcao, funcao, fk_oficio, ...oficios(cor, cod_cor)')
        .inFilter('id_funcao', idsOficios)
        .order('funcao', ascending: true);
    return rows
        .map((row) {
          final id = (row['id_funcao'] as num?)?.toInt() ?? 0;
          final funcao = row['funcao']?.toString().trim() ?? '';
          final cor =
              (row['cor'] ?? row['cod_cor'])?.toString().trim() ?? '#1D2430';
          return (id: id, funcao: funcao, cor: cor);
        })
        .where((item) => item.id != 0 && item.funcao.isNotEmpty)
        .toList();
  }

  /// Ofício (`fk_oficio`) da função — gravado junto em `fk_oficios` para
  /// manter categoria/cor e as telas que ainda filtram por ofício.
  static Future<int?> buscarOficioDaFuncao(int idFuncao) async {
    final row = await _supabase
        .from('funcoes')
        .select('fk_oficio')
        .eq('id_funcao', idFuncao)
        .maybeSingle();
    return (row?['fk_oficio'] as num?)?.toInt();
  }

  // ── Catálogo de serviços padrão ────────────────────────────────────────────

  /// Busca todos os serviços do catálogo (sugestões disponíveis para o profissional).
  /// Faz join com a tabela `oficios` para obter a função (categoria) e cor.
  static Future<List<ServicoCatalogo>> buscarCatalogo() async {
    try {
      final rows = await _supabase
          .from('servicos_catalogo')
          .select('*, $kSelectFuncao') // join para pegar funcao/cor
          .eq('ativo', true)
          .order('titulo', ascending: true);

      return rows.map<ServicoCatalogo>(ServicoCatalogo.fromMap).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarCatalogo ERROR: $e');
      return [];
    }
  }

  /// Funções que a empresa pode escolher: as marcadas na conta
  /// da empresa (`ass_oficio_grupo_empresa.fk_funcao`). `id` é o `id_funcao`.
  static Future<List<({int id, String funcao, String cor})>>
  buscarFuncoesDaEmpresa(int idGrupoEmpresa) async {
    try {
      final vinculos = await _supabase
          .from('ass_oficio_grupo_empresa')
          .select('fk_funcao')
          .eq('fk_grupo_empresa', idGrupoEmpresa);
      final ids = vinculos
          .map((row) => (row['fk_funcao'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      return _funcoesPorIds(ids);
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarFuncoesDaEmpresa ERROR: $e');
      return [];
    }
  }

  static Future<List<({int id, String funcao, String cor})>>
  buscarFuncoesParaServico({
    required bool associacaoEmpresa,
    int? idGrupoEmpresa,
  }) async {
    if (associacaoEmpresa && idGrupoEmpresa != null) {
      return buscarFuncoesDaEmpresa(idGrupoEmpresa);
    }
    return buscarFuncoesDoProfissional();
  }
}
