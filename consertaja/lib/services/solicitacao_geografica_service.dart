import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status da tabela `status` usados pela solicitação geográfica.
class StatusSolicitacaoGeo {
  StatusSolicitacaoGeo._();

  static const int solicitada = 39; // também = "Enviada" para o profissional
  static const int visualizada = 41;
  static const int respondida = 42;
  static const int cancelada = 43;
}

/// Função (área do pedido) da tabela `funcoes`.
class FuncaoPedido {
  const FuncaoPedido({
    required this.id,
    required this.funcao,
    this.descricao,
    this.cor,
  });

  final int id;
  final String funcao;
  final String? descricao;
  final String? cor;
}

/// Perfil (profissional independente ou empresa) dentro do raio.
class PerfilProximo {
  const PerfilProximo({
    required this.ehEmpresa,
    this.idProfissional,
    this.idGrupoEmpresa,
    required this.nome,
    this.fotoUrl,
    this.tagEmpresa,
    this.corTagEmpresa,
    required this.posicao,
    required this.distanciaKm,
    this.nota,
    this.ultimaConexao,
  });

  final bool ehEmpresa;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final String nome;
  final String? fotoUrl;
  final String? tagEmpresa;
  final String? corTagEmpresa;
  final LatLng posicao;
  final double distanciaKm;
  final double? nota;
  final DateTime? ultimaConexao;

  /// Chave única: um dono de empresa aparece 2x (perfil pessoal + empresa).
  String get chave => ehEmpresa ? 'e$idGrupoEmpresa' : 'p$idProfissional';

  String? get tagFormatada {
    final t = tagEmpresa?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.startsWith('#') ? t.toUpperCase() : '#${t.toUpperCase()}';
  }

  factory PerfilProximo.fromMap(Map<String, dynamic> m) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return PerfilProximo(
      ehEmpresa: m['tipo'] == 'empresa',
      idProfissional: (m['id_profissional'] as num?)?.toInt(),
      idGrupoEmpresa: (m['id_grupo_empresa'] as num?)?.toInt(),
      nome: m['nome']?.toString().trim().isNotEmpty == true
          ? m['nome'].toString().trim()
          : 'Profissional',
      fotoUrl: m['foto_url']?.toString(),
      tagEmpresa: m['tag_empresa']?.toString(),
      corTagEmpresa: m['cor_tag_empresa']?.toString(),
      posicao: LatLng(d(m['latitude']), d(m['longitude'])),
      distanciaKm: d(m['distancia_km']),
      nota: (m['nota'] as num?)?.toDouble(),
      ultimaConexao: m['ultima_conexao'] == null
          ? null
          : DateTime.tryParse(m['ultima_conexao'].toString()),
    );
  }
}

/// Solicitação geográfica vista pelo profissional no Radar.
class SolicitacaoGeoProxima {
  const SolicitacaoGeoProxima({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.imagens,
    required this.funcao,
    this.cor,
    required this.idStatus,
    required this.posicao,
    required this.distanciaKm,
    this.dataCriacao,
    required this.nomeCliente,
    this.fotoCliente,
    this.enderecoCliente,
  });

  final int id;
  final String titulo;
  final String descricao;
  final List<String> imagens;
  final String funcao;
  final String? cor;
  final int idStatus;
  final LatLng posicao;
  final double distanciaKm;
  final DateTime? dataCriacao;
  final String nomeCliente;
  final String? fotoCliente;
  final String? enderecoCliente;

  /// Ainda não visualizada por nenhum profissional.
  bool get nova => idStatus == StatusSolicitacaoGeo.solicitada;

  factory SolicitacaoGeoProxima.fromMap(Map<String, dynamic> m) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    final imgs = m['img_solicitacao'];
    return SolicitacaoGeoProxima(
      id: (m['id_solicitacao_geografica'] as num).toInt(),
      titulo: m['titulo']?.toString() ?? '',
      descricao: m['descricao']?.toString() ?? '',
      imagens: imgs is List
          ? imgs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      funcao: m['funcao']?.toString() ?? '',
      cor: m['cor']?.toString(),
      idStatus:
          (m['fk_status'] as num?)?.toInt() ?? StatusSolicitacaoGeo.solicitada,
      posicao: LatLng(d(m['latitude']), d(m['longitude'])),
      distanciaKm: d(m['distancia_km']),
      dataCriacao: m['data_criacao'] == null
          ? null
          : DateTime.tryParse(m['data_criacao'].toString()),
      nomeCliente: m['nome_cliente']?.toString().trim().isNotEmpty == true
          ? m['nome_cliente'].toString().trim()
          : 'Cliente',
      fotoCliente: m['foto_cliente']?.toString(),
      enderecoCliente: m['endereco_cliente']?.toString(),
    );
  }
}

/// Solicitação geográfica do próprio cliente (para reabrir a tela).
class MinhaSolicitacaoGeo {
  const MinhaSolicitacaoGeo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.fkFuncao,
    required this.imagens,
    this.centro,
  });

  final int id;
  final String titulo;
  final String descricao;
  final int? fkFuncao;
  final List<String> imagens;
  final LatLng? centro;
}

class SolicitacaoGeograficaService {
  SolicitacaoGeograficaService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Raio padrão do círculo do mapa.
  static const double raioKm = 5;

  /// Centro usado se não houver GPS nem endereço (São Paulo).
  static const LatLng _fallback = LatLng(-23.5505, -46.6333);

  /// Todas as funções (áreas do pedido), em ordem alfabética.
  static Future<List<FuncaoPedido>> carregarFuncoes() async {
    final rows = await _db
        .from('funcoes')
        .select('id_funcao, funcao, descricao, ...oficios(cor)')
        .order('funcao');
    return rows
        .map(
          (r) => FuncaoPedido(
            id: (r['id_funcao'] as num).toInt(),
            funcao: r['funcao']?.toString() ?? '',
            descricao: r['descricao']?.toString(),
            cor: r['cor']?.toString(),
          ),
        )
        .where((f) => f.funcao.isNotEmpty)
        .toList();
  }

  /// Localização real do usuário logado (cliente ou profissional):
  /// GPS → endereço ativo cadastrado → fallback.
  static Future<LatLng> localizacaoAtual() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permissao = await Geolocator.checkPermission();
        if (permissao == LocationPermission.denied) {
          permissao = await Geolocator.requestPermission();
        }
        if (permissao == LocationPermission.always ||
            permissao == LocationPermission.whileInUse) {
          final ultima = await Geolocator.getLastKnownPosition();
          final pos =
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                ),
              ).timeout(
                const Duration(seconds: 8),
                onTimeout: () => ultima ?? (throw Exception('timeout')),
              );
          return LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      debugPrint('[SolicGeo] GPS indisponível: $e');
    }

    try {
      final idUsuario = await _meuIdUsuario();
      if (idUsuario != null) {
        final ass = await _db
            .from('ass_usuario_endereco')
            .select('enderecos(latitude, longitude)')
            .eq('fk_usuario', idUsuario)
            .eq('endereco_ativo', true)
            .limit(1)
            .maybeSingle();
        final end = ass?['enderecos'];
        if (end is Map) {
          final lat = double.tryParse(end['latitude']?.toString() ?? '');
          final lng = double.tryParse(end['longitude']?.toString() ?? '');
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('[SolicGeo] endereço ativo indisponível: $e');
    }
    return _fallback;
  }

  static Future<int?> _meuIdUsuario() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final row = await _db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id)
        .maybeSingle();
    return (row?['id_usuario'] as num?)?.toInt();
  }

  /// Perfis com a função escolhida dentro do raio (ordenados por distância).
  /// Sem função: todos os perfis do raio (para mostrar no mapa).
  static Future<List<PerfilProximo>> buscarProximos(
    LatLng centro, {
    int? fkFuncao,
  }) async {
    final rows = await _db.rpc(
      'profissionais_proximos_geo',
      params: {
        'p_lat': centro.latitude,
        'p_lng': centro.longitude,
        'p_raio_km': raioKm,
        'p_fk_funcao': fkFuncao,
      },
    );
    return (rows as List)
        .map((r) => PerfilProximo.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Envia as imagens para o bucket 'Imagens Anexadas Cliente' e devolve as
  /// URLs públicas. Caminho exigido pela policy: solicitacao-temp/{uid}/...
  static Future<List<String>> enviarImagens(List<XFile> imagens) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw Exception('Sessão expirada. Entre novamente.');
    const bucket = 'Imagens Anexadas Cliente';
    final urls = <String>[];
    for (var i = 0; i < imagens.length; i++) {
      final caminho =
          'solicitacao-temp/$uid/geografica_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
      await _db.storage
          .from(bucket)
          .uploadBinary(caminho, await imagens[i].readAsBytes());
      urls.add(_db.storage.from(bucket).getPublicUrl(caminho));
    }
    return urls;
  }

  /// Cria a solicitação geográfica (RPC). Por enquanto não notifica ninguém:
  /// os profissionais da área a veem no Radar.
  static Future<int> criar({
    required String titulo,
    required String descricao,
    required int fkFuncao,
    required List<String> imagens,
    required LatLng centro,
  }) async {
    try {
      final id = await _db.rpc(
        'criar_solicitacao_geografica',
        params: {
          'p_titulo': titulo.trim(),
          'p_descricao': descricao.trim(),
          'p_fk_funcao': fkFuncao,
          'p_img_solicitacao': imagens,
          'p_lat': centro.latitude,
          'p_lng': centro.longitude,
          'p_raio_km': raioKm,
        },
      );
      return (id as num).toInt();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw Exception(
          'Banco sem a solicitação geográfica. Rode '
          'docs/sql/migration_solicitacoes_geograficas_v2.sql no Supabase.',
        );
      }
      throw Exception(e.message);
    }
  }

  /// Solicitação do cliente logado que ainda não foi cancelada (a mais
  /// recente), para reabrir a tela já com os dados.
  static Future<MinhaSolicitacaoGeo?> minhaSolicitacaoAtiva() async {
    final idUsuario = await _meuIdUsuario();
    if (idUsuario == null) return null;
    final row = await _db
        .from('solicitacoes_geograficas')
        .select(
          'id_solicitacao_geografica, titulo, descricao, fk_funcao, '
          'img_solicitacao, latitude, longitude',
        )
        .eq('fk_usuario', idUsuario)
        .neq('fk_status', StatusSolicitacaoGeo.cancelada)
        .order('data_criacao', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    final imgs = row['img_solicitacao'];
    return MinhaSolicitacaoGeo(
      id: (row['id_solicitacao_geografica'] as num).toInt(),
      titulo: row['titulo']?.toString() ?? '',
      descricao: row['descricao']?.toString() ?? '',
      fkFuncao: (row['fk_funcao'] as num?)?.toInt(),
      imagens: imgs is List ? imgs.map((e) => e.toString()).toList() : const [],
      centro: lat != null && lng != null ? LatLng(lat, lng) : null,
    );
  }

  /// Radar do profissional: solicitações abertas cuja área alcança [posicao]
  /// e cuja função é de um ofício dele.
  static Future<List<SolicitacaoGeoProxima>> solicitacoesProximas(
    LatLng posicao,
  ) async {
    try {
      final rows = await _db.rpc(
        'solicitacoes_geograficas_proximas',
        params: {'p_lat': posicao.latitude, 'p_lng': posicao.longitude},
      );
      return (rows as List)
          .map(
            (r) => SolicitacaoGeoProxima.fromMap(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw Exception(
          'Banco sem o Radar do profissional. Rode '
          'docs/sql/migration_solicitacoes_geograficas_v2.sql no Supabase.',
        );
      }
      throw Exception(e.message);
    }
  }

  static Future<void> cancelar(int idSolicitacao) async {
    await _db
        .from('solicitacoes_geograficas')
        .update({'fk_status': StatusSolicitacaoGeo.cancelada})
        .eq('id_solicitacao_geografica', idSolicitacao);
  }
}
