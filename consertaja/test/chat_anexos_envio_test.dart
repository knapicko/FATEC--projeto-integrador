import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:consertaja/services/chat_anexos_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

const _urlFake = 'https://fake.supabase.co';

List<http.Request> _pedidos = [];
late Directory _tempDir;
late File _foto;
late File _documento;

/// Quando `true`, o mock do Storage responde erro de bucket inexistente.
bool _falharUpload = false;

/// Armazenamento PKCE em memória (evita o plugin shared_preferences no teste).
class _ArmazenamentoPkceFake extends GotrueAsyncStorage {
  final Map<String, String> _valores = {};

  @override
  Future<String?> getItem({required String key}) async => _valores[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _valores[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _valores.remove(key);
  }
}

/// JWT sem assinatura válida, apenas para o Supabase Auth reconhecer a sessão.
String _jwtFake() {
  String parte(Map<String, dynamic> json) => base64Url
      .encode(utf8.encode(jsonEncode(json)))
      .replaceAll('=', '');
  final agora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '${parte({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${parte({
        'sub': 'auth-123',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'teste@teste.com',
        'iat': agora,
        'exp': agora + 3600,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      })}.'
      '${base64Url.encode(utf8.encode('assinatura-fake')).replaceAll('=', '')}';
}

http.Response _json(
  Object corpo,
  http.BaseRequest req, {
  int status = 200,
}) =>
    http.Response(
      jsonEncode(corpo),
      status,
      headers: {'content-type': 'application/json'},
      request: req,
    );

/// Caminho da requisição já decodificado (bucket tem espaço no nome).
String _caminho(http.Request req) => Uri.decodeComponent(req.url.path);

/// Simula o Supabase: Auth, Storage e PostgREST (sem as colunas extras).
Future<http.Response> _mockSupabase(http.Request req) async {
  _pedidos.add(req);
  final caminho = _caminho(req);

  if (caminho.contains('/auth/v1/user')) {
    return _json({
      'id': 'auth-123',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'teste@teste.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, req);
  }

  if (caminho.contains('/storage/v1/object/')) {
    if (_falharUpload) {
      return _json({
        'statusCode': '404',
        'error': 'Bucket not found',
        'message': 'Bucket not found',
      }, req, status: 404);
    }
    return _json({'Key': caminho}, req);
  }

  if (caminho.contains('/rest/v1/mensagens')) {
    final corpo = jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;
    // O banco do projeto não possui `url_arquivo`/`legenda`:
    // o service deve cair no insert simplificado.
    if (corpo.containsKey('url_arquivo') || corpo.containsKey('legenda')) {
      return _json({
        'code': 'PGRST204',
        'message': "Could not find the 'url_arquivo' column of 'mensagens'",
        'details': 'Searched for the column url_arquivo',
        'hint': null,
      }, req, status: 400);
    }
    // maybeSingle() espera um objeto único (PostgREST com
    // Accept: application/vnd.pgrst.object+json).
    return _json({
      'id_mensagem': 99,
      'conteudo': corpo['conteudo'],
      'data_envio': DateTime.now().toUtc().toIso8601String(),
      'fk_remitente_usuario': corpo['fk_remitente_usuario'],
      'lida': false,
      'tipo_mensagem': corpo['tipo_mensagem'],
    }, req);
  }

  return _json(const <String, dynamic>{}, req);
}

List<http.Request> _pedidosDoStorage() =>
    _pedidos.where((r) => _caminho(r).contains('/storage/v1/object/')).toList();

Map<String, dynamic> _corpoJson(http.Request req) =>
    jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    _tempDir = await Directory.systemTemp.createTemp('chat_anexos_test');
    _foto = File('${_tempDir.path}/foto.jpg')
      ..writeAsBytesSync(List<int>.filled(64, 7));
    _documento = File('${_tempDir.path}/contrato.pdf')
      ..writeAsBytesSync(List<int>.filled(128, 9));

    await Supabase.initialize(
      url: _urlFake,
      publishableKey: 'chave-fake',
      httpClient: MockClient(_mockSupabase),
      authOptions: FlutterAuthClientOptions(
        persistSession: false,
        pkceAsyncStorage: _ArmazenamentoPkceFake(),
      ),
    );

    await Supabase.instance.client.auth.setSession(
      'refresh-token-fake',
      accessToken: _jwtFake(),
    );
  });

  setUp(() {
    _pedidos.clear();
    _falharUpload = false;
  });

  tearDownAll(() async {
    await _tempDir.delete(recursive: true);
  });

  test('valida que a sessão fake foi criada', () {
    expect(Supabase.instance.client.auth.currentUser?.id, 'auth-123');
  });

  test('envia foto para o bucket "Anexos Chat" e grava a mensagem', () async {
    final resultado = await ChatAnexosService.enviarImagem(
      idConversa: 7,
      idUsuarioLogado: 1,
      imagem: XFile(_foto.path, name: 'foto.jpg'),
    );

    expect(resultado.sucesso, isTrue, reason: resultado.erro);
    expect(resultado.erro, isNull);
    expect(resultado.linha?['id_mensagem'], 99);

    // 1) Upload no bucket correto, com pasta da conversa e nome do arquivo
    // (o SDK do Storage envia como multipart; o content-type fica na parte
    // do arquivo, não no header da requisição).
    final uploads = _pedidosDoStorage();
    expect(uploads, hasLength(1));
    final caminho = _caminho(uploads.single);
    expect(caminho, contains('/storage/v1/object/Anexos Chat/conversa_7/'));
    expect(caminho, endsWith('_foto.jpg'));
    final corpoUpload = latin1.decode(uploads.single.bodyBytes);
    expect(corpoUpload, contains('image/jpeg'));
    expect(corpoUpload, contains('filename='));

    // 2) Mensagem gravada como Imagem com a URL pública em `conteudo`.
    // O service tenta primeiro com `url_arquivo` e cai no insert simples.
    final inserts = _pedidos
        .where((r) => _caminho(r).contains('/rest/v1/mensagens'))
        .toList();
    expect(inserts, hasLength(2));
    final corpo = _corpoJson(inserts.last);
    expect(corpo['fk_conversa'], 7);
    expect(corpo['fk_remitente_usuario'], 1);
    expect(corpo['tipo_mensagem'], 'Imagem');
    // O insert de fallback não envia `lida` (usa o default do banco).
    expect(corpo.containsKey('url_arquivo'), isFalse);
    expect(
      corpo['conteudo'],
      contains('/storage/v1/object/public/Anexos%20Chat/conversa_7/'),
    );
    expect(corpo['conteudo'], endsWith('_foto.jpg'));
  });

  test('envia documento com nome + URL em `conteudo`', () async {
    final resultado = await ChatAnexosService.enviarDocumento(
      idConversa: 12,
      idUsuarioLogado: 1,
      nomeArquivo: 'contrato.pdf',
      caminhoLocal: _documento.path,
      leitorBytes: _documento.readAsBytes,
    );

    expect(resultado.sucesso, isTrue, reason: resultado.erro);

    final uploads = _pedidosDoStorage();
    expect(uploads, hasLength(1));
    final caminho = _caminho(uploads.single);
    expect(caminho, contains('/storage/v1/object/Anexos Chat/conversa_12/'));
    expect(caminho, endsWith('_contrato.pdf'));
    final corpoUpload = latin1.decode(uploads.single.bodyBytes);
    expect(corpoUpload, contains('application/pdf'));

    final inserts = _pedidos
        .where((r) => _caminho(r).contains('/rest/v1/mensagens'))
        .toList();
    expect(inserts, hasLength(2));
    final corpo = _corpoJson(inserts.last);
    expect(corpo['tipo_mensagem'], 'Documento');

    final conteudo = corpo['conteudo'] as String;
    final separado = ChatAnexosService.separarConteudoDocumento(conteudo);
    expect(separado, isNotNull);
    expect(separado!.nome, 'contrato.pdf');
    expect(separado.url, contains('Anexos%20Chat/conversa_12/'));
    expect(separado.url, endsWith('_contrato.pdf'));
  });

  test('erro de bucket inexistente vira mensagem amigável', () async {
    _falharUpload = true;

    final resultado = await ChatAnexosService.enviarImagem(
      idConversa: 7,
      idUsuarioLogado: 1,
      imagem: XFile(_foto.path, name: 'foto.jpg'),
    );

    expect(resultado.sucesso, isFalse);
    expect(resultado.linha, isNull);
    expect(resultado.erro, contains('Anexos Chat'));

    // Nenhuma mensagem deve ser gravada quando o upload falha.
    expect(
      _pedidos.where((r) => _caminho(r).contains('/rest/v1/mensagens')),
      isEmpty,
    );
  });

  test('arquivo acima de 50 MB é recusado antes do upload', () async {
    final resultado = await ChatAnexosService.enviarDocumento(
      idConversa: 3,
      idUsuarioLogado: 1,
      nomeArquivo: 'grande.zip',
      caminhoLocal: null,
      leitorBytes: () async =>
          Uint8List(ChatAnexosService.tamanhoMaximoBytes + 1),
    );

    expect(resultado.sucesso, isFalse);
    expect(resultado.erro, contains('50 MB'));
    expect(_pedidosDoStorage(), isEmpty);
  });
}