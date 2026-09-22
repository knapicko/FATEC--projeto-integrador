import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/postagem_resumo.dart';

typedef ResultadoCriarPostagem = ({
  bool sucesso,
  int? idPostagem,
  String? erro,
});

class PostagensProfissionalService {
  static const String bucketPostagens = 'Postagens';

  static const List<String> mesesAbreviados = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  static String formatarDataPostagem(DateTime data) {
    final mes = mesesAbreviados[data.month - 1];
    return '${data.day} $mes ${data.year}';
  }

  static Future<ResultadoCriarPostagem> criarPostagem({
    required String conteudo,
    required List<XFile> imagens,
    int? idPerfilOverride,
    String tipoAutor = 'profissional',
    int? idGrupoEmpresa,
  }) async {
    try {
      debugPrint('📝 [criarPostagem] Iniciando...');
      final idPerfil = idPerfilOverride ?? await buscarIdPerfil();
      debugPrint('📝 [criarPostagem] idPerfil: $idPerfil');
      if (idPerfil == null) {
        debugPrint('❌ [criarPostagem] idPerfil é null!');
        return (sucesso: false, idPostagem: null, erro: 'Perfil não encontrado. Verifique seus dados profissionais.');
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      debugPrint('📝 [criarPostagem] user: ${user?.id}');
      if (user == null) {
        debugPrint('❌ [criarPostagem] user é null!');
        return (sucesso: false, idPostagem: null, erro: 'Usuário não autenticado.');
      }

      // 1. Faz upload das imagens para o bucket 'Postagens'
      final urlsImagens = <String>[];
      debugPrint('📝 [criarPostagem] Quantidade de imagens: ${imagens.length}');
      for (final imagem in imagens) {
        final fileName =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}_${urlsImagens.length}.jpg';
        debugPrint('📤 [criarPostagem] Upload: $fileName (bucket: $bucketPostagens)');

        if (kIsWeb) {
          final bytes = await imagem.readAsBytes();
          await supabase.storage.from(bucketPostagens).uploadBinary(
                fileName,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
        } else {
          await supabase.storage.from(bucketPostagens).upload(
                fileName,
                File(imagem.path),
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
        }
        debugPrint('✅ [criarPostagem] Upload OK: $fileName');

        urlsImagens.add(
          supabase.storage.from(bucketPostagens).getPublicUrl(fileName),
        );
      }

      // 2. Monta o conteúdo (texto + URLs das imagens)
      final texto = conteudo.trim();
      final linhas = <String>[
        if (texto.isNotEmpty) texto,
        ...urlsImagens,
      ];
      final conteudoFinal = linhas.join('\n');
      debugPrint('📝 [criarPostagem] conteudoFinal: $conteudoFinal');
      if (conteudoFinal.isEmpty) {
        debugPrint('❌ [criarPostagem] conteúdo final vazio!');
        return (sucesso: false, idPostagem: null, erro: 'Conteúdo vazio.');
      }

      // 3. Insere a postagem no banco
      // tipo_autor: 'profissional' (CNPJ individual) ou 'empresa' (grupo_empresa).
      // fk_grupo_empresa: preenchido só quando a postagem é da empresa.
      debugPrint('📝 [criarPostagem] Inserindo no banco...');
      final tipoAutorNormalizado =
          tipoAutor == 'empresa' ? 'empresa' : 'profissional';
      Map<String, dynamic>? response;
      Object? ultimoErroInsert;

      // Tentativa 1: com as colunas novas (rode migration_postagens_empresa.sql).
      try {
        response = await supabase
            .from('postagens')
            .insert({
              'conteudo': conteudoFinal,
              'data_postagem': DateTime.now().toUtc().toIso8601String(),
              'arquivado': false,
              'fk_perfil': idPerfil,
              'tipo_autor': tipoAutorNormalizado,
              if (idGrupoEmpresa != null)
                'fk_grupo_empresa': idGrupoEmpresa,
            })
            .select('id_postagem')
            .single();
      } catch (e) {
        ultimoErroInsert = e;
        debugPrint('ℹ️ [criarPostagem] Insert com tipo_autor falhou ($e). Tentando sem as colunas novas...');
        response = null;
      }

      // Tentativa 2 (fallback p/ banco ainda sem migration): insert legado.
      // Nesse caso a separação por conta só funciona 100% após rodar o SQL.
      response ??= await supabase
          .from('postagens')
          .insert({
            'conteudo': conteudoFinal,
            'data_postagem': DateTime.now().toUtc().toIso8601String(),
            'arquivado': false,
            'fk_perfil': idPerfil,
          })
          .select('id_postagem')
          .single();

      if (ultimoErroInsert != null) {
        debugPrint(
          '⚠️ [criarPostagem] Banco sem colunas tipo_autor/fk_grupo_empresa? '
          'Rode docs/sql/migration_postagens_empresa.sql no Supabase.',
        );
      }

      final idPostagem = (response['id_postagem'] as num?)?.toInt();
      debugPrint('✅ [criarPostagem] Postagem criada! id: $idPostagem');

      // 4. Espelha as imagens na tabela imagens_postagens (quando existir).
      //    Mantém também as URLs dentro do 'conteudo' para compatibilidade
      //    com o formato legado. Se a tabela ainda não existir, ignora.
      if (idPostagem != null && urlsImagens.isNotEmpty) {
        try {
          final linhas = <Map<String, dynamic>>[];
          for (var i = 0; i < urlsImagens.length; i++) {
            linhas.add({
              'fk_postagem': idPostagem,
              'url_imagem': urlsImagens[i],
              'ordem': i,
            });
          }
          await supabase.from('imagens_postagens').insert(linhas);
          debugPrint('✅ [criarPostagem] imagens_postagens OK (${linhas.length})');
        } catch (e) {
          debugPrint(
            'ℹ️ [criarPostagem] imagens_postagens indisponível ($e). '
            'Rode docs/sql/migration_postagens_empresa.sql.',
          );
        }
      }

      return (sucesso: true, idPostagem: idPostagem, erro: null);
    } catch (e) {
      debugPrint('❌ [criarPostagem] ERRO GERAL: $e');
      debugPrint('❌ [criarPostagem] StackTrace: ${StackTrace.current}');
      return (
        sucesso: false,
        idPostagem: null,
        erro: 'Erro ao publicar: $e',
      );
    }
  }

  static Future<int?> buscarIdPerfil() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final usuarioResponse = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioResponse == null) return null;
      final usuarioId = usuarioResponse['id_usuario'];

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (dadosProf == null) return null;

      final idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
      final fkPerfil = (dadosProf['fk_perfil'] as num?)?.toInt();
      debugPrint('📝 [buscarIdPerfil] id_profissional: $idProfissional | fk_perfil atual: $fkPerfil');

      // 0. Se já tem fk_perfil preenchido, verifica se ele existe na tabela perfil
      if (fkPerfil != null) {
        try {
          final existe = await supabase
              .from('perfil')
              .select('id_perfil')
              .eq('id_perfil', fkPerfil)
              .maybeSingle();
          if (existe != null) {
            debugPrint('✅ [buscarIdPerfil] fk_perfil já válido: $fkPerfil');
            return fkPerfil;
          }
          debugPrint('ℹ️ [buscarIdPerfil] fk_perfil $fkPerfil não existe mais na tabela perfil. Criando novo...');
        } catch (e) {
          debugPrint('ℹ️ [buscarIdPerfil] Falha ao verificar perfil (sem permissão de leitura?): $e');
        }
      }

      debugPrint('📝 [buscarIdPerfil] Criando perfil automático...');

      // 1. Tentativa: INSERT direto (sem mexer em descricao/banner_url → autoincrement)
      try {
        debugPrint('📝 [buscarIdPerfil] Tentativa 1: INSERT na tabela perfil (autoincrement)...');
        final perfilResponse = await supabase
            .from('perfil')
            .insert({})
            .select('id_perfil')
            .single();
        final novoId = (perfilResponse['id_perfil'] as num).toInt();
        debugPrint('✅ [buscarIdPerfil] Perfil criado: $novoId');

        await supabase
            .from('dados_profissionais')
            .update({'fk_perfil': novoId})
            .eq('id_profissional', idProfissional!);
        debugPrint('✅ [buscarIdPerfil] dados_profissionais.fk_perfil atualizado para $novoId');

        return novoId;
      } catch (e1) {
        debugPrint('❌ [buscarIdPerfil] Tentativa 1 falhou: $e1');
      }

      // 2. Tentativa: INSERT com id_perfil = id_profissional
      try {
        debugPrint('📝 [buscarIdPerfil] Tentativa 2: INSERT com id_perfil = $idProfissional...');
        final perfilResponse = await supabase
            .from('perfil')
            .insert({'id_perfil': idProfissional!})
            .select('id_perfil')
            .single();
        final novoId2 = (perfilResponse['id_perfil'] as num).toInt();
        debugPrint('✅ [buscarIdPerfil] Perfil criado com id explícito: $novoId2');

        await supabase
            .from('dados_profissionais')
            .update({'fk_perfil': novoId2})
            .eq('id_profissional', idProfissional);
        debugPrint('✅ [buscarIdPerfil] dados_profissionais.fk_perfil atualizado para $novoId2');

        return novoId2;
      } catch (e2) {
        debugPrint('❌ [buscarIdPerfil] Tentativa 2 falhou: $e2');
      }

      // 3. Tentativa: via RPC criar_perfil (caso exista no Supabase)
      try {
        debugPrint('📝 [buscarIdPerfil] Tentativa 3: via RPC criar_perfil...');
        final idViaRpc = await supabase.rpc('criar_perfil');
        final novoId3 = (idViaRpc as num).toInt();
        debugPrint('✅ [buscarIdPerfil] Perfil criado via RPC: $novoId3');

        await supabase
            .from('dados_profissionais')
            .update({'fk_perfil': novoId3})
            .eq('id_profissional', idProfissional!);
        debugPrint('✅ [buscarIdPerfil] dados_profissionais.fk_perfil atualizado para $novoId3');

        return novoId3;
      } catch (e3) {
        debugPrint('❌ [buscarIdPerfil] Tentativa 3 (RPC) falhou: $e3');
      }

      debugPrint('❌ [buscarIdPerfil] Não foi possível criar o perfil automaticamente.');
      return null;
    } catch (e) {
      debugPrint('❌ [buscarIdPerfil] ERRO GERAL: $e');
      return null;
    }
  }

  static Future<List<PostagemResumo>> buscarPostagens({int? limit}) async {
    try {
      final idPerfil = await buscarIdPerfil();
      if (idPerfil == null) return [];

      return await buscarPostagensPorPerfil(idPerfil, limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// Busca as postagens da conta ativa.
  /// - isEmpresa=false (profissional CNPJ): só tipo_autor='profissional'.
  /// - isEmpresa=true: só tipo_autor='empresa' do grupo (fk_grupo_empresa).
  /// Se o banco ainda não tiver as colunas novas, cai para o comportamento
  /// legado (filtrar só por fk_perfil).
  static Future<List<PostagemResumo>> buscarPostagensConta({
    required int idPerfil,
    required bool isEmpresa,
    int? idGrupoEmpresa,
    int? limit,
    bool incluirArquivadas = false,
  }) async {
    // Caminho empresa exige grupo; sem grupo não há o que listar.
    if (isEmpresa && idGrupoEmpresa == null) return [];

    // Tenta o filtro novo (tipo_autor + fk_grupo_empresa).
    try {
      final comFiltro = await buscarPostagensPorPerfil(
        idPerfil,
        limit: limit,
        incluirArquivadas: incluirArquivadas,
        tipoAutor: isEmpresa ? 'empresa' : 'profissional',
        idGrupoEmpresa: isEmpresa ? idGrupoEmpresa : null,
        filtrarPorGrupo: isEmpresa,
      );
      // Se o banco novo retornou algo OU se o profissional não tem colisão
      // de perfil com a empresa, esse resultado já é o correto.
      // Para conta empresa com banco novo mas sem posts, retorna [] mesmo
      // (não deve vazar posts do profissional).
      return comFiltro;
    } catch (_) {
      // Cai no legado abaixo.
    }

    return await buscarPostagensPorPerfil(
      idPerfil,
      limit: limit,
      incluirArquivadas: incluirArquivadas,
    );
  }

  /// Busca todas as postagens do profissional, incluindo as arquivadas.
  /// Usado na página "Minhas Postagens" do profissional.
  static Future<List<PostagemResumo>> buscarTodasPostagens({int? limit}) async {
    try {
      final idPerfil = await buscarIdPerfil();
      if (idPerfil == null) return [];

      return await buscarPostagensPorPerfil(
        idPerfil,
        limit: limit,
        incluirArquivadas: true,
      );
    } catch (e) {
      return [];
    }
  }

  static Future<List<PostagemResumo>> buscarPostagensPorPerfil(
    int idPerfil, {
    int? limit,
    bool incluirArquivadas = false,
    String? tipoAutor,
    int? idGrupoEmpresa,
    bool filtrarPorGrupo = false,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Monta a seleção pedindo as colunas novas; se o banco ainda não
      // tiver a migration, refaz a query só com as colunas legadas.
      List<dynamic> rows;
      bool temColunasNovas = true;
      try {
        rows = await _executarQueryPostagens(
          supabase: supabase,
          idPerfil: idPerfil,
          incluirArquivadas: incluirArquivadas,
          limit: limit,
          tipoAutor: tipoAutor,
          idGrupoEmpresa: idGrupoEmpresa,
          filtrarPorGrupo: filtrarPorGrupo,
          comColunasNovas: true,
        );
      } catch (e) {
        debugPrint('ℹ️ [buscarPostagensPorPerfil] Sem colunas novas ($e). Usando query legada.');
        temColunasNovas = false;
        rows = await _executarQueryPostagens(
          supabase: supabase,
          idPerfil: idPerfil,
          incluirArquivadas: incluirArquivadas,
          limit: limit,
          tipoAutor: null,
          idGrupoEmpresa: null,
          filtrarPorGrupo: false,
          comColunasNovas: false,
        );
      }

      final postagens = <PostagemResumo>[];

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final idPostagem = (map['id_postagem'] as num).toInt();

        // Fallback client-side: se pediu filtro de empresa mas o banco
        // ainda não tem as colunas, não há como separar — nesse caso
        // a separação total exige rodar a migration.
        if (temColunasNovas && tipoAutor != null) {
          final tipo = map['tipo_autor']?.toString();
          if (tipo != null && tipo != tipoAutor) continue;
          // Postagem legada (tipo NULL) = profissional.
          if (tipo == null && tipoAutor == 'empresa') continue;
          if (filtrarPorGrupo && idGrupoEmpresa != null) {
            final grupo = (map['fk_grupo_empresa'] as num?)?.toInt();
            if (grupo != idGrupoEmpresa) continue;
          }
        }

        // Completa a imagem pela tabela imagens_postagens quando existir,
        // mantendo compat com o formato legado (URL dentro do conteudo).
        String? imagemViaTabela;
        try {
          final imgs = await supabase
              .from('imagens_postagens')
              .select('url_imagem')
              .eq('fk_postagem', idPostagem)
              .order('ordem', ascending: true)
              .limit(1);
          if (imgs.isNotEmpty) {
            imagemViaTabela =
                (imgs.first as Map)['url_imagem']?.toString();
          }
        } catch (_) {
          // Tabela ainda não criada — ignora e usa só o conteudo.
        }

        final curtidas = await _contarCurtidas(supabase, idPostagem);
        postagens.add(
          _parseRow(map, curtidas, imagemFallback: imagemViaTabela),
        );
      }

      return postagens;
    } catch (e) {
      debugPrint('❌ [buscarPostagensPorPerfil] ERRO: $e');
      return [];
    }
  }

  static Future<List<dynamic>> _executarQueryPostagens({
    required SupabaseClient supabase,
    required int idPerfil,
    required bool incluirArquivadas,
    int? limit,
    String? tipoAutor,
    int? idGrupoEmpresa,
    required bool filtrarPorGrupo,
    required bool comColunasNovas,
  }) async {
    final colunas = comColunasNovas
        ? 'id_postagem, conteudo, data_postagem, arquivado, tipo_autor, fk_grupo_empresa'
        : 'id_postagem, conteudo, data_postagem, arquivado';
    dynamic query = supabase
        .from('postagens')
        .select(colunas)
        .eq('fk_perfil', idPerfil);

    if (!incluirArquivadas) {
      query = query.eq('arquivado', false);
    }
    if (comColunasNovas && tipoAutor != null) {
      query = query.eq('tipo_autor', tipoAutor);
    }
    if (comColunasNovas && filtrarPorGrupo && idGrupoEmpresa != null) {
      query = query.eq('fk_grupo_empresa', idGrupoEmpresa);
    }

    dynamic ordenada = query.order('data_postagem', ascending: false);
    if (limit != null) {
      ordenada = ordenada.limit(limit);
    }
    final rows = await ordenada;
    return (rows as List);
  }

  /// Apaga permanentemente uma postagem do Supabase.
  /// Retorna `true` apenas se a postagem foi realmente removida do banco.
  static Future<bool> apagarPostagem(int idPostagem) async {
    try {
      final supabase = Supabase.instance.client;
      final removidas = await supabase
          .from('postagens')
          .delete()
          .eq('id_postagem', idPostagem)
          .select('id_postagem');

      final sucesso = removidas.isNotEmpty;
      debugPrint('🗑️ [apagarPostagem] id=$idPostagem sucesso=$sucesso linhas=${removidas.length}');
      return sucesso;
    } catch (e) {
      debugPrint('❌ [apagarPostagem] ERRO: $e');
      return false;
    }
  }

  /// Marca uma postagem como arquivada (arquivado = true).
  /// Retorna `true` apenas se a postagem foi realmente atualizada no banco.
  static Future<bool> arquivarPostagem(int idPostagem) async {
    try {
      final supabase = Supabase.instance.client;
      final atualizadas = await supabase
          .from('postagens')
          .update({'arquivado': true})
          .eq('id_postagem', idPostagem)
          .select('id_postagem');

      final sucesso = atualizadas.isNotEmpty;
      debugPrint('📦 [arquivarPostagem] id=$idPostagem sucesso=$sucesso linhas=${atualizadas.length}');
      return sucesso;
    } catch (e) {
      debugPrint('❌ [arquivarPostagem] ERRO: $e');
      return false;
    }
  }

  static Future<int> _contarCurtidas(
    SupabaseClient supabase,
    int idPostagem,
  ) async {
    try {
      final curtidasRows = await supabase
          .from('curtidas_postagem')
          .select('id_curtida_postagem')
          .eq('fk_postagem', idPostagem);
      return curtidasRows.length;
    } catch (_) {
      return 0;
    }
  }

  static PostagemResumo _parseRow(
    Map<String, dynamic> row,
    int curtidas, {
    String? imagemFallback,
  }) {
    final idPostagem = (row['id_postagem'] as num).toInt();
    final conteudo = row['conteudo']?.toString().trim() ?? '';
    final dataRaw = row['data_postagem']?.toString();
    final dataPostagem = dataRaw != null
        ? DateTime.tryParse(dataRaw) ?? DateTime.now()
        : DateTime.now();
    final arquivado = row['arquivado'] == true;

    // Separa linhas de texto de URLs de imagens
    final linhas = conteudo
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? imagemUrl;
    final textos = <String>[];
    for (final linha in linhas) {
      if (linha.startsWith('http://') || linha.startsWith('https://')) {
        imagemUrl ??= linha;
      } else {
        textos.add(linha);
      }
    }
    // Prioriza a imagem vinda de imagens_postagens quando o conteudo
    // legado não tiver URL (post criado só com a tabela nova).
    imagemUrl ??= imagemFallback;

    final titulo = textos.isNotEmpty
        ? textos.first
        : (imagemUrl != null ? 'Postagem' : 'Sem título');

    return PostagemResumo(
      idPostagem: idPostagem,
      titulo: titulo,
      imagemUrl: imagemUrl,
      dataPostagem: dataPostagem,
      curtidas: curtidas,
      arquivado: arquivado,
    );
  }
}