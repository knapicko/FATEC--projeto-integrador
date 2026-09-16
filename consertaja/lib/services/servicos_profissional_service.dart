import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_catalogo.dart';
import '../models/servico_profissional.dart';

class ServicosProfissionalService {
  static SupabaseClient get _supabase => Supabase.instance.client;
  static const String _bucketServicos = 'Imagens Servicos';

  static Future<({
    int idProfissional,
    int? idGrupoEmpresa,
    bool ehLoja,
    bool ehMembroEmpresa,
    bool ehDonoEmpresa,
  })?>
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
      final ehDonoEmpresa = idGrupoEmpresa != null &&
          idPerfil != null &&
          idPerfilDono == idPerfil;
      return (
        idProfissional: idProfissional,
        idGrupoEmpresa: idGrupoEmpresa,
        ehLoja: perfil?['tipo_perfil']?.toString().trim().toLowerCase() == 'loja',
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
          .select('*, oficios(funcao, cod_cor)')
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
    required int fkOficio,
    String? imagemUrl,
    XFile? imagemLocal,
    int? fkGrupoEmpresa,
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

      final response = await _supabase
          .from('servicos_profissional')
          .insert({
            'titulo': titulo.trim(),
            'descricao': descricao.trim(),
            'valor': valor,
            'fk_oficios': fkOficio,
            'imagem_url': urlFinal,
            'ativo': true,
            'fk_profissional': idProf,
            'fk_grupo_empresa': fkGrupoEmpresa,
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
    required int fkOficio,
    String? imagemUrl,
    XFile? imagemLocal,
    int? fkGrupoEmpresa,
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

      await _supabase
          .from('servicos_profissional')
          .update({
            'titulo': titulo.trim(),
            'descricao': descricao.trim(),
            'valor': valor,
            'fk_oficios': fkOficio,
            'imagem_url': urlFinal,
            'fk_grupo_empresa': fkGrupoEmpresa,
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
          .select('*, oficios(funcao, cod_cor)')
          .eq('fk_grupo_empresa', idGrupoEmpresa)
          .eq('ativo', true)
          .order('data_criacao', ascending: false);
      return rows
          .map<ServicoProfissional>(ServicoProfissional.fromMap)
          .toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarServicosEmpresa ERROR: $e');
      return [];
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

  // ── Ofícios (categorias) ──────────────────────────────────────────────────

  /// Busca todos os ofícios (categorias/funções) disponíveis, incluindo id_oficio.
  static Future<List<({int id, String funcao, String cor})>>
  buscarFuncoesDoProfissional() async {
    try {
      final idProfissional = await buscarIdProfissional();
      if (idProfissional == null) return [];

      final vinculos = await _supabase
        .from('ass_oficio_profissional')
        .select('fk_oficio')
        .eq('fk_profissional', idProfissional);
      final ids = vinculos
        .map((row) => (row['fk_oficio'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList();
      if (ids.isEmpty) return [];

        // O profissional pode estar associado a um ofício específico, mas o
        // seletor deve mostrar todas as funções da mesma categoria desse ofício.
        final oficiosAssociados = await _supabase
          .from('oficios')
          .select('id_oficio, funcao, categoria, cod_cor')
          .inFilter('id_oficio', ids);
        final categorias = oficiosAssociados
          .map((row) => row['categoria']?.toString().trim().toLowerCase())
          .whereType<String>()
          .where((categoria) => categoria.isNotEmpty)
          .toSet();
        if (categorias.isEmpty) return [];

        final todosOficios = await _supabase
          .from('oficios')
          .select('id_oficio, funcao, categoria, cod_cor')
          .order('funcao', ascending: true);

        return todosOficios.where((row) {
        final categoria = row['categoria']?.toString().trim().toLowerCase();
        return categoria != null && categorias.contains(categoria);
        }).map((row) {
        final id = (row['id_oficio'] as num?)?.toInt() ?? 0;
        final categoria = row['categoria']?.toString().trim();
        final funcao = row['funcao']?.toString().trim() ?? 'GERAL';
        final cor = row['cod_cor']?.toString().trim() ?? '#1D2430';
        debugPrint(
          '✅ [ServicosSvc] Ofício associado: fk_oficio=$id, categoria=$categoria, funcao=$funcao',
        );
        return (id: id, funcao: funcao, cor: cor);
      }).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarFuncoesDoProfissional ERROR: $e');
      return [];
    }
  }

  // ── Catálogo de serviços padrão ────────────────────────────────────────────

  /// Busca todos os serviços do catálogo (sugestões disponíveis para o profissional).
  /// Faz join com a tabela `oficios` para obter a função (categoria) e cor.
  static Future<List<ServicoCatalogo>> buscarCatalogo() async {
    try {
      final rows = await _supabase
          .from('servicos_catalogo')
          .select('*, oficios(funcao, cod_cor)') // join para pegar funcao/cor
          .eq('ativo', true)
          .order('titulo', ascending: true);

      return rows.map<ServicoCatalogo>(ServicoCatalogo.fromMap).toList();
    } catch (e) {
      debugPrint('❌ [ServicosSvc] buscarCatalogo ERROR: $e');
      return [];
    }
  }

  static Future<List<({int id, String funcao, String cor})>>
  buscarFuncoesDaEmpresa(int idGrupoEmpresa) async {
    try {
      final vinculos = await _supabase
          .from('ass_oficio_grupo_empresa')
          .select('fk_oficio')
          .eq('fk_grupo_empresa', idGrupoEmpresa);
      final ids = vinculos
          .map((row) => (row['fk_oficio'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      if (ids.isEmpty) return [];
      final rows = await _supabase
          .from('oficios')
          .select('id_oficio, funcao, cod_cor')
          .inFilter('id_oficio', ids)
          .order('funcao', ascending: true);
      return rows
          .map((row) => (
                id: (row['id_oficio'] as num?)?.toInt() ?? 0,
                funcao: row['funcao']?.toString().trim() ?? '',
                cor: row['cod_cor']?.toString().trim() ?? '#1D2430',
              ))
          .where((item) => item.funcao.isNotEmpty)
          .toList();
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
