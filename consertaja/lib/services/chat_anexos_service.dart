import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado do envio de um anexo do chat.
typedef ResultadoEnvioAnexo = ({
  bool sucesso,
  Map<String, dynamic>? linha,
  String? erro,
});

/// Faz o upload dos anexos do chat (fotos e documentos) para o bucket
/// 'Anexos Chat' do Supabase Storage e registra a mensagem em `mensagens`.
///
/// Layout do bucket:
///   `conversa_<id_conversa>/<timestamp>_<nome_do_arquivo>`
///
/// A tabela `mensagens` possui apenas a coluna de texto `conteudo` garantida:
///   - Imagem    -> `conteudo` recebe a URL pública, tipo_mensagem = 'Imagem'
///   - Documento -> `conteudo` recebe "nome_do_arquivo\nURL",
///                  tipo_mensagem = 'Documento'
/// Se o banco possuir as colunas extras `url_arquivo`/`legenda`, elas também
/// são preenchidas (a leitura do chat já as prioriza).
class ChatAnexosService {
  ChatAnexosService._();

  /// Bucket do Supabase Storage onde os anexos do chat são salvos.
  static const String bucketAnexos = 'Anexos Chat';

  /// Limite de tamanho por arquivo (o padrão do Supabase é 50 MB).
  static const int tamanhoMaximoBytes = 50 * 1024 * 1024;

  static const String _colunasCompletas =
      'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, '
      'tipo_mensagem, url_arquivo, legenda';
  static const String _colunasBasicas =
      'id_mensagem, conteudo, data_envio, fk_remitente_usuario, lida, '
      'tipo_mensagem';

  static const Set<String> _extensoesImagem = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  static const String _mensagemArquivoGrande =
      'Arquivo muito grande. O limite é de 50 MB.';

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Extensão (sem ponto) do nome do arquivo, em minúsculas.
  /// Retorna vazio quando o arquivo não possui extensão.
  static String extensaoDe(String nomeArquivo) {
    final nome = nomeArquivo.trim().toLowerCase();
    final ponto = nome.lastIndexOf('.');
    if (ponto <= 0 || ponto == nome.length - 1) return '';
    return nome.substring(ponto + 1);
  }

  /// Indica se o arquivo deve ser exibido como foto no chat.
  static bool ehImagem(String nomeArquivo) =>
      _extensoesImagem.contains(extensaoDe(nomeArquivo));

  /// `contentType` do arquivo, usado no upload para o Storage.
  static String contentTypeDe(String nomeArquivo) {
    switch (extensaoDe(nomeArquivo)) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      default:
        return 'application/octet-stream';
    }
  }

  /// Monta o `conteudo` de uma mensagem de documento: nome do arquivo + URL.
  static String montarConteudoDocumento({
    required String nomeArquivo,
    required String url,
  }) => '${nomeArquivo.trim()}\n${url.trim()}';

  /// Separa o `conteudo` de um documento em nome e URL.
  /// Retorna `null` quando não há URL válida no conteúdo.
  static ({String nome, String url})? separarConteudoDocumento(
    String conteudo,
  ) {
    final linhas = conteudo
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (linhas.isEmpty) return null;

    final indiceUrl = linhas.lastIndexWhere(
      (l) => l.startsWith('http://') || l.startsWith('https://'),
    );
    if (indiceUrl < 0) return null;

    final url = linhas[indiceUrl];
    final nome = linhas.where((l) => l != url).join(' ').trim();
    return (nome: nome, url: url);
  }

  /// Envia uma foto do chat (galeria ou câmera).
  static Future<ResultadoEnvioAnexo> enviarImagem({
    required int idConversa,
    required int idUsuarioLogado,
    required XFile imagem,
    String? legenda,
  }) {
    final nome = imagem.name.trim().isEmpty ? 'foto.jpg' : imagem.name.trim();
    return _enviar(
      idConversa: idConversa,
      idUsuarioLogado: idUsuarioLogado,
      nomeArquivo: nome,
      caminhoLocal: kIsWeb ? null : imagem.path,
      leitorBytes: imagem.readAsBytes,
      legenda: legenda,
    );
  }

  /// Envia um documento (PDF, planilha, etc.) escolhido pelo usuário.
  ///
  /// [caminhoLocal] é o caminho do arquivo no disco (null na web);
  /// [leitorBytes] lê o conteúdo quando não há caminho local.
  static Future<ResultadoEnvioAnexo> enviarDocumento({
    required int idConversa,
    required int idUsuarioLogado,
    required String nomeArquivo,
    required String? caminhoLocal,
    required Future<Uint8List> Function() leitorBytes,
  }) {
    return _enviar(
      idConversa: idConversa,
      idUsuarioLogado: idUsuarioLogado,
      nomeArquivo: nomeArquivo,
      caminhoLocal: caminhoLocal,
      leitorBytes: leitorBytes,
      legenda: nomeArquivo,
    );
  }

  static Future<ResultadoEnvioAnexo> _enviar({
    required int idConversa,
    required int idUsuarioLogado,
    required String nomeArquivo,
    required Future<Uint8List> Function() leitorBytes,
    required String? caminhoLocal,
    String? legenda,
  }) async {
    try {
      if (_supabase.auth.currentUser == null) {
        return (
          sucesso: false,
          linha: null,
          erro: 'Faça login para enviar anexos.',
        );
      }

      final ehFoto = ehImagem(nomeArquivo);
      final caminho = _construirCaminho(idConversa, nomeArquivo);
      final contentType = contentTypeDe(nomeArquivo);
      debugPrint('📤 [ChatAnexos] Upload: $caminho (bucket: $bucketAnexos)');

      if (!kIsWeb && caminhoLocal != null && caminhoLocal.isNotEmpty) {
        final arquivoLocal = File(caminhoLocal);
        final tamanho = await arquivoLocal.length();
        if (tamanho > tamanhoMaximoBytes) {
          return (sucesso: false, linha: null, erro: _mensagemArquivoGrande);
        }
        await _supabase.storage.from(bucketAnexos).upload(
          caminho,
          arquivoLocal,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      } else {
        final bytes = await leitorBytes();
        if (bytes.length > tamanhoMaximoBytes) {
          return (sucesso: false, linha: null, erro: _mensagemArquivoGrande);
        }
        await _supabase.storage.from(bucketAnexos).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      }

      final url = _supabase.storage.from(bucketAnexos).getPublicUrl(caminho);
      debugPrint('✅ [ChatAnexos] Upload OK: $url');

      final linha = await _inserirMensagem(
        idConversa: idConversa,
        idUsuarioLogado: idUsuarioLogado,
        tipoMensagem: ehFoto ? 'Imagem' : 'Documento',
        conteudo: ehFoto
            ? url
            : montarConteudoDocumento(nomeArquivo: nomeArquivo, url: url),
        urlArquivo: url,
        legenda: legenda,
      );

      if (linha == null) {
        return (
          sucesso: false,
          linha: null,
          erro: 'Anexo enviado, mas não foi possível registrar a mensagem.',
        );
      }
      return (sucesso: true, linha: linha, erro: null);
    } catch (e, s) {
      debugPrint('❌ [ChatAnexos] ERRO no envio: $e');
      debugPrint('❌ [ChatAnexos] stack: $s');
      return (sucesso: false, linha: null, erro: _mensagemErro(e));
    }
  }

  /// Envia uma mensagem de áudio gravada pelo usuário.
  /// [extensao]/[contentType] variam por plataforma (m4a no mobile,
  /// m4a ou webm na web, conforme o codec suportado pelo navegador).
  static Future<ResultadoEnvioAnexo> enviarAudio({
    required int idConversa,
    required int idUsuarioLogado,
    required Uint8List bytes,
    required int duracaoSegundos,
    String extensao = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    try {
      final nomeArquivo =
          'audio_${DateTime.now().millisecondsSinceEpoch}.$extensao';
      final caminho = _construirCaminho(idConversa, nomeArquivo);

      await _supabase.storage.from(bucketAnexos).uploadBinary(
            caminho,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final url = _supabase.storage.from(bucketAnexos).getPublicUrl(caminho);
      debugPrint('✅ [ChatAnexos] Upload áudio OK: $url');

      final linha = await _inserirMensagem(
        idConversa: idConversa,
        idUsuarioLogado: idUsuarioLogado,
        tipoMensagem: 'Audio',
        conteudo: url,
        urlArquivo: url,
        duracaoSegundos: duracaoSegundos,
      );

      if (linha == null) {
        return (
          sucesso: false,
          linha: null,
          erro: 'Áudio enviado, mas não foi possível registrar a mensagem.',
        );
      }
      return (sucesso: true, linha: linha, erro: null);
    } catch (e, s) {
      debugPrint('❌ [ChatAnexos] ERRO no envio de áudio: $e');
      debugPrint('❌ [ChatAnexos] stack: $s');
      return (sucesso: false, linha: null, erro: _mensagemErro(e));
    }
  }

  /// Insere a mensagem do anexo em `mensagens`.
  /// Se o banco não tiver as colunas extras, reenvia apenas o essencial.
  static Future<Map<String, dynamic>?> _inserirMensagem({
    required int idConversa,
    required int idUsuarioLogado,
    required String tipoMensagem,
    required String conteudo,
    required String urlArquivo,
    String? legenda,
    int? duracaoSegundos,
  }) async {
    final legendaTratada = legenda?.trim();
    try {
      return await _supabase
          .from('mensagens')
          .insert({
            'fk_conversa': idConversa,
            'tipo_mensagem': tipoMensagem,
            'conteudo': conteudo,
            'fk_remitente_usuario': idUsuarioLogado,
            'lida': false,
            'url_arquivo': urlArquivo,
            if (legendaTratada != null && legendaTratada.isNotEmpty)
              'legenda': legendaTratada,
            'duracao_audio': ?duracaoSegundos,
          })
          .select(_colunasCompletas)
          .maybeSingle();
    } on PostgrestException {
      // `url_arquivo`/`legenda`/`duracao_audio` podem não existir: a URL já
      // vai em `conteudo`.
      return await _supabase
          .from('mensagens')
          .insert({
            'fk_conversa': idConversa,
            'tipo_mensagem': tipoMensagem,
            'conteudo': conteudo,
            'fk_remitente_usuario': idUsuarioLogado,
          })
          .select(_colunasBasicas)
          .maybeSingle();
    }
  }

  /// Caminho do arquivo dentro do bucket: uma pasta por conversa.
  static String _construirCaminho(int idConversa, String nomeArquivo) {
    final nomeLimpo = nomeArquivo
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final carimbo = DateTime.now().millisecondsSinceEpoch;
    return 'conversa_$idConversa/${carimbo}_$nomeLimpo';
  }

  /// Converte erros técnicos em mensagens amigáveis para o usuário.
  static String _mensagemErro(Object erro) {
    final texto = erro.toString().toLowerCase();
    if (texto.contains('bucket not found') || texto.contains('not found')) {
      return "Bucket '$bucketAnexos' não encontrado no Supabase Storage.";
    }
    if (texto.contains('row-level security') ||
        texto.contains('unauthorized') ||
        texto.contains('policy') ||
        texto.contains('403')) {
      return 'Sem permissão para enviar anexos. Verifique as políticas do bucket.';
    }
    if (texto.contains('maximum allowed size') || texto.contains('too large')) {
      return 'O arquivo excede o tamanho máximo permitido pelo bucket.';
    }
    return 'Não foi possível enviar o anexo. Tente de novo.';
  }
}