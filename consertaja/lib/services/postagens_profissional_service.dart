import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/postagem_resumo.dart';

class PostagensProfissionalService {
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

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('fk_perfil')
          .eq('fk_usuario', usuarioResponse['id_usuario'])
          .maybeSingle();
      if (dadosProf == null) return null;

      return (dadosProf['fk_perfil'] as num?)?.toInt();
    } catch (e) {
      return null;
    }
  }

  static Future<List<PostagemResumo>> buscarPostagens({int? limit}) async {
    try {
      final idPerfil = await buscarIdPerfil();
      if (idPerfil == null) return [];

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

    String? imagemUrl;
    String titulo = conteudo;
    if (conteudo.startsWith('http://') || conteudo.startsWith('https://')) {
      imagemUrl = conteudo;
      titulo = 'Postagem';
    } else if (titulo.isEmpty) {
      titulo = 'Sem título';
    }

    return PostagemResumo(
      idPostagem: idPostagem,
      titulo: titulo,
      imagemUrl: imagemUrl,
      dataPostagem: dataPostagem,
      curtidas: 0,
    );
  }
}
