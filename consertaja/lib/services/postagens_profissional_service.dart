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
  }) async {
    try {
      debugPrint('📝 [criarPostagem] Iniciando...');
      final idPerfil = await buscarIdPerfil();
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
      debugPrint('📝 [criarPostagem] Inserindo no banco...');
      final response = await supabase
          .from('postagens')
          .insert({
            'conteudo': conteudoFinal,
            'data_postagem': DateTime.now().toUtc().toIso8601String(),
            'arquivado': false,
            'fk_perfil': idPerfil,
          })
          .select('id_postagem')
          .single();

      final idPostagem = (response['id_postagem'] as num?)?.toInt();
      debugPrint('✅ [criarPostagem] Postagem criada! id: $idPostagem');
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

      return buscarPostagensPorPerfil(idPerfil, limit: limit);
    } catch (e) {
      return [];
    }
  }

  static Future<List<PostagemResumo>> buscarPostagensPorPerfil(
    int idPerfil, {
    int? limit,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase
          .from('postagens')
          .select('id_postagem, conteudo, data_postagem')
          .eq('fk_perfil', idPerfil)
          .eq('arquivado', false)
          .order('data_postagem', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final rows = await query;
      final postagens = <PostagemResumo>[];

      for (final row in rows) {
        final idPostagem = (row['id_postagem'] as num).toInt();
        final curtidas = await _contarCurtidas(supabase, idPostagem);
        postagens.add(_parseRow(row, curtidas));
      }

      return postagens;
    } catch (e) {
      return [];
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

  static PostagemResumo _parseRow(Map<String, dynamic> row, int curtidas) {
    final idPostagem = (row['id_postagem'] as num).toInt();
    final conteudo = row['conteudo']?.toString().trim() ?? '';
    final dataRaw = row['data_postagem']?.toString();
    final dataPostagem = dataRaw != null
        ? DateTime.tryParse(dataRaw) ?? DateTime.now()
        : DateTime.now();

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

    final titulo = textos.isNotEmpty
        ? textos.first
        : (imagemUrl != null ? 'Postagem' : 'Sem título');

    return PostagemResumo(
      idPostagem: idPostagem,
      titulo: titulo,
      imagemUrl: imagemUrl,
      dataPostagem: dataPostagem,
      curtidas: 0,
    );
  }
}
