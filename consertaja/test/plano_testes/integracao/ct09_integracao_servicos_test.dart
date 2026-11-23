// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT49 a CT54 — Testes de INTEGRAÇÃO com backend simulado
// Requisitos: RF001/RF002/RF004 (cadastro, login e verificação de documento),
//             RF009/RF014 (aceite da solicitação e avanço de etapa)
// Abordagem: Integração entre os serviços do app e o cliente Supabase/HTTP,
//            com o servidor substituído por um MockClient (package:http).
//            Nenhuma chamada sai para a internet.
//
// ATENÇÃO: CT54 documenta o defeito DEF-03 e FALHA até a correção.
// =============================================================================
import 'dart:convert';

import 'package:consertaja/services/consulta_cadastro_service.dart';
import 'package:consertaja/services/solicitacoes_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _urlFake = 'https://fake.supabase.co';

/// Requisições recebidas pelo "servidor" simulado.
final List<http.Request> _pedidos = [];

/// Resposta da RPC `aceitar_solicitacao` (lista vazia = já aceita).
List<Map<String, dynamic>> _respostaAceite = [];

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

http.Response _json(Object? corpo, http.BaseRequest req, {int status = 200}) =>
    http.Response(
      jsonEncode(corpo),
      status,
      headers: {'content-type': 'application/json'},
      request: req,
    );

/// Simula o PostgREST do Supabase para as tabelas usadas nos testes.
Future<http.Response> _mockSupabase(http.Request req) async {
  _pedidos.add(req);
  final caminho = Uri.decodeComponent(req.url.path);
  final q = req.url.queryParameters;

  if (caminho.endsWith('/rest/v1/dados_profissionais')) {
    // maybeSingle(): conforme a versão do postgrest, a requisição pede um
    // objeto único (Accept: vnd.pgrst.object+json) ou uma lista de 1 item.
    final grupo = q['id_profissional'] == 'eq.7' ? 3 : null;
    final linha = {'fk_grupo_empresa': grupo};
    final pedeObjeto =
        (req.headers['accept'] ?? '').contains('vnd.pgrst.object+json');
    return _json(pedeObjeto ? linha : [linha], req);
  }

  if (caminho.endsWith('/rest/v1/solicitacoes') && req.method == 'GET') {
    if (q.containsKey('fk_profissional')) {
      return _json([
        {'id_solicitacao': 1, 'data_solicitacao': '2026-11-10T10:00:00Z'},
        {'id_solicitacao': 2, 'data_solicitacao': '2026-11-12T10:00:00Z'},
      ], req);
    }
    if (q.containsKey('fk_grupo_empresa')) {
      return _json([
        {'id_solicitacao': 2, 'data_solicitacao': '2026-11-12T10:00:00Z'},
        {'id_solicitacao': 3, 'data_solicitacao': '2026-11-15T10:00:00Z'},
      ], req);
    }
  }

  if (caminho.endsWith('/rest/v1/rpc/aceitar_solicitacao')) {
    return _json(_respostaAceite, req);
  }

  if (caminho.endsWith('/rest/v1/solicitacoes') && req.method == 'PATCH') {
    return _json(<dynamic>[], req);
  }

  return _json(const <String, dynamic>{}, req);
}

/// Simula a BrasilAPI (consulta de CNPJ).
Future<http.Response> _mockBrasilApi(http.Request req) async {
  if (req.url.path.endsWith('/11222333000181')) {
    return _json({
      'razao_social': 'CONSERTA JA SERVICOS LTDA',
      'nome_fantasia': 'Conserta Já',
      'data_inicio_atividade': '2010-03-15',
      'ddd_telefone_1': '1133334444',
    }, req);
  }
  return _json({'message': 'CNPJ não encontrado'}, req, status: 404);
}

void main() {
  late ConsultaCadastroService cadastro;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: _urlFake,
      publishableKey: 'chave-fake',
      httpClient: MockClient(_mockSupabase),
      authOptions: FlutterAuthClientOptions(
        persistSession: false,
        pkceAsyncStorage: _ArmazenamentoPkceFake(),
      ),
    );
    cadastro = ConsultaCadastroService();
  });

  setUp(() {
    _pedidos.clear();
    _respostaAceite = [];
  });

  group('RF009/RF014 — Solicitações recebidas pelo profissional', () {
    test('CT49 - Junta pedidos individuais e da loja, sem duplicar, mais recentes primeiro', () async {
      final pedidos = await SolicitacoesService.buscarParaProfissional(7);
      final ids = pedidos.map((p) => p['id_solicitacao']).toList();
      expect(ids, [3, 2, 1]);
    });

    test('CT50 - Aceite chama a RPC e avança a etapa para 1 (pagamento)', () async {
      _respostaAceite = [
        {'id_solicitacao': 10, 'fk_status': 2, 'etapa_solicitacao': 0},
      ];
      final pedido = await SolicitacoesService.aceitar(
        idSolicitacao: 10,
        idProfissional: 7,
      );
      expect(pedido['etapa_solicitacao'], 1);
      expect(pedido['fk_status'], 2);

      final rpc = _pedidos.singleWhere(
        (r) => r.url.path.endsWith('/rpc/aceitar_solicitacao'),
      );
      final corpo = jsonDecode(rpc.body) as Map<String, dynamic>;
      expect(corpo['p_id_solicitacao'], 10);
      expect(corpo['p_id_profissional'], 7);

      final patch = _pedidos.singleWhere((r) => r.method == 'PATCH');
      expect(jsonDecode(patch.body), {'etapa_solicitacao': 1});
      expect(patch.url.queryParameters['id_solicitacao'], 'eq.10');
      // não retrocede etapas já avançadas
      expect(patch.url.queryParameters['etapa_solicitacao'], 'lt.1');
    });

    test('CT51 - Solicitação já aceita por outro profissional gera erro', () async {
      _respostaAceite = [];
      await expectLater(
        SolicitacoesService.aceitar(idSolicitacao: 11, idProfissional: 7),
        throwsA(isA<Exception>()),
      );
      expect(_pedidos.where((r) => r.method == 'PATCH'), isEmpty);
    });
  });

  group('RF001/RF004 — Validação de documento no cadastro', () {
    test('CT52 - CPF/CNPJ validados localmente e CNPJ consultado na BrasilAPI', () async {
      final cpf = await cadastro.validarDocumento('529.982.247-25');
      expect(cpf.valido, isTrue);

      final curto = await cadastro.validarDocumento('123');
      expect(curto.valido, isFalse);
      expect(curto.erro, 'O CPF/CNPJ informado não é válido');

      final vazio = await cadastro.validarDocumento('');
      expect(vazio.valido, isFalse);

      final cnpjInvalido = await cadastro.validarDocumento('11.222.333/0001-82');
      expect(cnpjInvalido.valido, isFalse);

      final cnpj = await http.runWithClient(
        () => cadastro.validarDocumento('11.222.333/0001-81'),
        () => MockClient(_mockBrasilApi),
      );
      expect(cnpj.valido, isTrue);
      expect(cnpj.empresa?.razaoSocial, 'CONSERTA JA SERVICOS LTDA');
      expect(cnpj.empresa?.nomeFantasia, 'Conserta Já');
      expect(cnpj.empresa?.dataFundacaoBr, '15/03/2010');
      expect(cnpj.empresa?.telefone, '1133334444');

      // CNPJ com dígito válido mas inexistente na Receita
      final inexistente = await http.runWithClient(
        () => cadastro.validarDocumento('45.997.418/0001-53'),
        () => MockClient(_mockBrasilApi),
      );
      expect(inexistente.valido, isFalse);
    });
  });

  group('RF001/RF002 — Formato de e-mail (cadastro e login)', () {
    test('CT53 - Aceita e-mails válidos e recusa formatos inválidos', () {
      expect(cadastro.emailFormatoValido('joao.silva@fatec.sp.gov.br'), isTrue);
      expect(cadastro.emailFormatoValido('  maria@gmail.com  '), isTrue);
      expect(cadastro.emailFormatoValido('ana_souza-01@empresa.com'), isTrue);
      expect(cadastro.emailFormatoValido('joao@'), isFalse);
      expect(cadastro.emailFormatoValido('joao silva@gmail.com'), isFalse);
      expect(cadastro.emailFormatoValido('joaogmail.com'), isFalse);
      expect(cadastro.emailFormatoValido(''), isFalse);
    });

    test('CT54 - [DEF-03] Aceita domínios com mais de 4 letras (.online, .store)', () {
      expect(cadastro.emailFormatoValido('contato@consertaja.online'), isTrue);
      expect(cadastro.emailFormatoValido('vendas@loja.store'), isTrue);
    }, tags: ['defeito']);
  });
}
