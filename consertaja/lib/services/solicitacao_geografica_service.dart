import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status da tabela `status` usados pela solicitação geográfica.
class StatusSolicitacaoGeo {
  StatusSolicitacaoGeo._();

  static const int solicitada = 39; // também = "Enviada" para o profissional
  static const int concluida = 40; // solicitação vinculada concluída/cancelada
  static const int visualizada = 41;
  static const int respondida = 42; // aceita por um profissional
  static const int cancelada = 43;

  static const int aceita = respondida;
}

/// Status da `solicitacoes` vinculada.
class StatusSolicitacaoVinculada {
  StatusSolicitacaoVinculada._();

  static const int aberto = 1;
  static const int aguardandoPagamento = 2;
  static const int concluido = 6;
  static const int cancelado = 7;

  /// Já passou do pagamento: dá para acompanhar em tempo real.
  static bool podeAcompanhar(int? status) =>
      status != null && status != aberto && status != aguardandoPagamento;
}

/// Método de realização que o cliente escolhe (vira `tipo_execucao`).
class MetodoEntregaGeo {
  const MetodoEntregaGeo({
    required this.valor,
    required this.descricao,
    required this.icone,
  });

  final String valor;
  final String descricao;
  final IconData icone;

  /// Atendimento em Domicílio primeiro.
  static const List<MetodoEntregaGeo> todos = [
    MetodoEntregaGeo(
      valor: 'Atendimento em Domicílio',
      descricao:
          'O profissional vai até o seu endereço e faz o serviço no local.',
      icone: Icons.home_repair_service_outlined,
    ),
    MetodoEntregaGeo(
      valor: 'Leva e Traz',
      descricao:
          'O profissional busca o item na sua casa, conserta e devolve no seu endereço.',
      icone: Icons.sync_alt_rounded,
    ),
    MetodoEntregaGeo(
      valor: 'Retirado no Local',
      descricao:
          'Você leva o item até o profissional e retira no mesmo lugar quando ficar pronto.',
      icone: Icons.storefront_outlined,
    ),
    MetodoEntregaGeo(
      valor: 'Receba em Casa',
      descricao:
          'Você deixa o item com o profissional e ele entrega na sua casa quando terminar.',
      icone: Icons.local_shipping_outlined,
    ),
  ];

  static MetodoEntregaGeo? porValor(String? valor) {
    for (final m in todos) {
      if (m.valor == valor) return m;
    }
    return null;
  }
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
    this.metodoEntrega,
  });

  final int id;
  final String titulo;
  final String descricao;
  final List<String> imagens;
  final String funcao;
  final String? cor;
  final String? metodoEntrega;
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
      metodoEntrega: m['metodo_entrega']?.toString(),
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
    required this.idStatus,
    this.metodoEntrega,
    this.centro,
  });

  final int id;
  final String titulo;
  final String descricao;
  final int? fkFuncao;
  final List<String> imagens;
  final int idStatus;
  final String? metodoEntrega;
  final LatLng? centro;

  bool get aceita => idStatus == StatusSolicitacaoGeo.aceita;
}

/// O que o cliente vê depois que um profissional aceitou.
class AcompanhamentoGeo {
  const AcompanhamentoGeo({
    required this.idSolicitacao,
    required this.idStatus,
    this.status,
    required this.valor,
    this.tipoExecucao,
    required this.ehEmpresa,
    this.idProfissional,
    this.idGrupoEmpresa,
    required this.nome,
    this.fotoUrl,
    this.tagEmpresa,
    this.corTagEmpresa,
    this.nota,
    required this.totalAvaliacoes,
    this.posicao,
  });

  final int idSolicitacao;
  final int? idStatus;
  final String? status;
  final double valor;
  final String? tipoExecucao;
  final bool ehEmpresa;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final String nome;
  final String? fotoUrl;
  final String? tagEmpresa;
  final String? corTagEmpresa;
  final double? nota;
  final int totalAvaliacoes;
  final LatLng? posicao;

  /// "#CAEDSS" — só empresas têm tag.
  String? get tagFormatada {
    if (!ehEmpresa) return null;
    final t = tagEmpresa?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.startsWith('#') ? t.toUpperCase() : '#${t.toUpperCase()}';
  }

  factory AcompanhamentoGeo.fromMap(Map<String, dynamic> m) {
    final lat = (m['latitude'] as num?)?.toDouble();
    final lng = (m['longitude'] as num?)?.toDouble();
    return AcompanhamentoGeo(
      idSolicitacao: (m['id_solicitacao'] as num).toInt(),
      idStatus: (m['fk_status'] as num?)?.toInt(),
      status: m['status']?.toString(),
      valor: (m['valor_final'] as num?)?.toDouble() ?? 0,
      tipoExecucao: m['tipo_execucao']?.toString(),
      ehEmpresa: m['eh_empresa'] == true,
      idProfissional: (m['id_profissional'] as num?)?.toInt(),
      idGrupoEmpresa: (m['id_grupo_empresa'] as num?)?.toInt(),
      nome: m['nome']?.toString().trim().isNotEmpty == true
          ? m['nome'].toString().trim()
          : 'Profissional',
      fotoUrl: m['foto_url']?.toString(),
      tagEmpresa: m['tag_empresa']?.toString(),
      corTagEmpresa: m['cor_tag_empresa']?.toString(),
      nota: (m['nota'] as num?)?.toDouble(),
      totalAvaliacoes: (m['total_avaliacoes'] as num?)?.toInt() ?? 0,
      posicao: lat != null && lng != null ? LatLng(lat, lng) : null,
    );
  }
}

/// Solicitação geográfica que o profissional aceitou (ainda não concluída).
class SolicitacaoGeoAceita {
  const SolicitacaoGeoAceita({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.imagens,
    required this.funcao,
    this.cor,
    this.metodoEntrega,
    required this.posicao,
    this.dataCriacao,
    required this.idSolicitacao,
    this.idStatus,
    this.status,
    required this.valor,
    this.dataAceite,
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
  final String? metodoEntrega;
  final LatLng posicao;
  final DateTime? dataCriacao;
  final int idSolicitacao;
  final int? idStatus;
  final String? status;
  final double valor;
  final DateTime? dataAceite;
  final String nomeCliente;
  final String? fotoCliente;
  final String? enderecoCliente;

  factory SolicitacaoGeoAceita.fromMap(Map<String, dynamic> m) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    DateTime? dt(Object? v) => v == null ? null : DateTime.tryParse('$v');
    final imgs = m['img_solicitacao'];
    return SolicitacaoGeoAceita(
      id: (m['id_solicitacao_geografica'] as num).toInt(),
      titulo: m['titulo']?.toString() ?? '',
      descricao: m['descricao']?.toString() ?? '',
      imagens: imgs is List
          ? imgs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      funcao: m['funcao']?.toString() ?? '',
      cor: m['cor']?.toString(),
      metodoEntrega: m['metodo_entrega']?.toString(),
      posicao: LatLng(d(m['latitude']), d(m['longitude'])),
      dataCriacao: dt(m['data_criacao']),
      idSolicitacao: (m['id_solicitacao'] as num).toInt(),
      idStatus: (m['fk_status'] as num?)?.toInt(),
      status: m['status']?.toString(),
      valor: d(m['valor_final']),
      dataAceite: dt(m['data_aceite']),
      nomeCliente: m['nome_cliente']?.toString().trim().isNotEmpty == true
          ? m['nome_cliente'].toString().trim()
          : 'Cliente',
      fotoCliente: m['foto_cliente']?.toString(),
      enderecoCliente: m['endereco_cliente']?.toString(),
    );
  }
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

  /// Origem da última [localizacaoAtual]: true = GPS do aparelho.
  static bool ultimaLocalizacaoFoiGps = false;

  /// Localização real do CLIENTE: GPS (latitude/longitude do aparelho) →
  /// endereço ativo cadastrado → fallback. (O profissional usa
  /// [localizacaoEnderecoProfissional].)
  static Future<LatLng> localizacaoAtual() async {
    ultimaLocalizacaoFoiGps = false;
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
          ultimaLocalizacaoFoiGps = true;
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
          final lat = coordenada(end['latitude']);
          final lng = coordenada(end['longitude']);
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('[SolicGeo] endereço ativo indisponível: $e');
    }
    return _fallback;
  }

  /// Localização do PROFISSIONAL = endereço cadastrado (nunca o GPS).
  ///
  /// [contaEmpresa] = conta ativa é a empresa:
  ///   • empresa → endereço da empresa (ass_grupo_empresa_endereco);
  ///   • independente → endereço comercial (ass_profissional_endereco) e,
  ///     se não houver, o endereço ativo do usuário (ass_usuario_endereco).
  /// Retorna null se nenhum endereço com coordenadas estiver cadastrado.
  static Future<LatLng?> localizacaoEnderecoProfissional({
    required bool contaEmpresa,
  }) async {
    final idUsuario = await _meuIdUsuario();
    if (idUsuario == null) return null;
    final perfis = await _db
        .from('dados_profissionais')
        .select('id_profissional, fk_grupo_empresa, fk_perfil')
        .eq('fk_usuario', idUsuario);
    if (perfis.isEmpty) return null;

    final idsEnderecos = <int>[];
    Future<void> juntar(List<dynamic> vinculos) async {
      final ordenados = [...vinculos]
        ..sort(
          (a, b) => ((b['endereco_ativo'] == true) ? 1 : 0).compareTo(
            (a['endereco_ativo'] == true) ? 1 : 0,
          ),
        );
      for (final v in ordenados) {
        final id = (v['fk_endereco'] as num?)?.toInt();
        if (id != null && !idsEnderecos.contains(id)) idsEnderecos.add(id);
      }
    }

    if (contaEmpresa) {
      final grupos = <int>{};
      for (final p in perfis) {
        final g = (p['fk_grupo_empresa'] as num?)?.toInt();
        if (g != null) grupos.add(g);
        final fkPerfil = (p['fk_perfil'] as num?)?.toInt();
        if (fkPerfil != null) {
          final donos = await _db
              .from('grupo_empresa')
              .select('id_grupo_empresa')
              .eq('fk_perfil', fkPerfil);
          for (final d in donos) {
            final id = (d['id_grupo_empresa'] as num?)?.toInt();
            if (id != null) grupos.add(id);
          }
        }
      }
      if (grupos.isNotEmpty) {
        await juntar(
          await _db
              .from('ass_grupo_empresa_endereco')
              .select('fk_endereco, endereco_ativo')
              .inFilter('fk_grupo_empresa', grupos.toList()),
        );
      }
    } else {
      final idsProf = perfis
          .map((p) => (p['id_profissional'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      if (idsProf.isNotEmpty) {
        await juntar(
          await _db
              .from('ass_profissional_endereco')
              .select('fk_endereco, endereco_ativo')
              .inFilter('fk_profissional', idsProf),
        );
      }
      await juntar(
        await _db
            .from('ass_usuario_endereco')
            .select('fk_endereco, endereco_ativo')
            .eq('fk_usuario', idUsuario),
      );
    }
    if (idsEnderecos.isEmpty) return null;

    // Endereço sem coordenada (cadastrado sem mexer no mapa) é geocodificado
    // e salvo: assim o cliente também passa a ver este perfil no mapa dele.
    await garantirCoordenadas(idsEnderecos);

    final enderecos = await _db
        .from('enderecos')
        .select('id_endereco, latitude, longitude')
        .inFilter('id_endereco', idsEnderecos);
    // Respeita a prioridade montada acima (ativo/comercial primeiro).
    for (final id in idsEnderecos) {
      final e = enderecos.where((r) => r['id_endereco'] == id).firstOrNull;
      final lat = coordenada(e?['latitude']);
      final lng = coordenada(e?['longitude']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  /// Lê latitude/longitude do banco aceitando "-23,55" e ignorando 0/vazio.
  static double? coordenada(Object? v) {
    final s = v?.toString().trim().replaceAll(',', '.') ?? '';
    final d = double.tryParse(s);
    if (d == null || d == 0) return null;
    return d;
  }

  /// Geocodifica (Nominatim, o mesmo do meus_enderecos) os endereços sem
  /// latitude/longitude e grava no banco. Falhas são ignoradas.
  static Future<void> garantirCoordenadas(List<int> idsEnderecos) async {
    if (idsEnderecos.isEmpty) return;
    try {
      final rows = await _db
          .from('enderecos')
          .select(
            'id_endereco, logradouro, numero, bairro, fk_cidade, latitude, longitude',
          )
          .inFilter('id_endereco', idsEnderecos);
      final semCoord = rows
          .where(
            (r) =>
                coordenada(r['latitude']) == null ||
                coordenada(r['longitude']) == null,
          )
          .take(3)
          .toList();
      for (final r in semCoord) {
        final logradouro = r['logradouro']?.toString().trim() ?? '';
        if (logradouro.isEmpty) continue;
        String cidade = '';
        String uf = '';
        final fkCidade = (r['fk_cidade'] as num?)?.toInt();
        if (fkCidade != null) {
          final c = await _db
              .from('cidades')
              .select('nome_cidade, fk_estado')
              .eq('id_cidade', fkCidade)
              .maybeSingle();
          cidade = c?['nome_cidade']?.toString() ?? '';
          final fkEstado = (c?['fk_estado'] as num?)?.toInt();
          if (fkEstado != null) {
            final e = await _db
                .from('estados')
                .select('sigla_estado')
                .eq('id_estado', fkEstado)
                .maybeSingle();
            uf = e?['sigla_estado']?.toString() ?? '';
          }
        }
        final numero = r['numero']?.toString().trim() ?? '';
        final bairro = r['bairro']?.toString().trim() ?? '';
        final consulta = [
          numero.isNotEmpty ? '$logradouro, $numero' : logradouro,
          if (bairro.isNotEmpty) bairro,
          if (cidade.isNotEmpty) cidade,
          if (uf.isNotEmpty) uf,
          'Brasil',
        ].join(', ');
        final resp = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(consulta)}&format=json&limit=1',
          ),
          headers: const {
            'User-Agent': 'ConsertaJa/1.0 (contato@consertaja.com.br)',
          },
        );
        if (resp.statusCode != 200) continue;
        final lista = jsonDecode(resp.body);
        if (lista is! List || lista.isEmpty) continue;
        final lat = double.tryParse('${lista.first['lat']}');
        final lng = double.tryParse('${lista.first['lon']}');
        if (lat == null || lng == null) continue;
        await _db
            .from('enderecos')
            .update({'latitude': lat, 'longitude': lng})
            .eq('id_endereco', r['id_endereco']);
        // Nominatim pede no máximo 1 requisição por segundo.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    } catch (e) {
      debugPrint('[SolicGeo] geocodificar endereços: $e');
    }
  }

  /// Garante coordenadas nos endereços do CLIENTE logado (usado para achar o
  /// endereço a até 100 m do ponto do pedido).
  static Future<void> garantirCoordenadasDoCliente() async {
    final idUsuario = await _meuIdUsuario();
    if (idUsuario == null) return;
    try {
      final ass = await _db
          .from('ass_usuario_endereco')
          .select('fk_endereco')
          .eq('fk_usuario', idUsuario);
      await garantirCoordenadas(
        ass
            .map((r) => (r['fk_endereco'] as num?)?.toInt())
            .whereType<int>()
            .toList(),
      );
    } catch (e) {
      debugPrint('[SolicGeo] coordenadas do cliente: $e');
    }
  }

  /// Números do Radar para explicar uma lista vazia (RPC diagnostico_radar).
  static Future<Map<String, dynamic>?> diagnostico(LatLng ponto) async {
    try {
      final r = await _db.rpc(
        'diagnostico_radar',
        params: {'p_lat': ponto.latitude, 'p_lng': ponto.longitude},
      );
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (e) {
      debugPrint('[SolicGeo] diagnóstico: $e');
      return null;
    }
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
    try {
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
          .map(
            (r) => PerfilProximo.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .where((p) => p.posicao.latitude != 0 || p.posicao.longitude != 0)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(_mensagemRpc(e));
    }
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
    required String metodoEntrega,
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
          'p_metodo_entrega': metodoEntrega,
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
          'docs/sql/migration_solicitacoes_geograficas_v3.sql no Supabase.',
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
          'img_solicitacao, latitude, longitude, fk_status, metodo_entrega',
        )
        .eq('fk_usuario', idUsuario)
        // Concluída (40) e cancelada (43) não reabrem: o cliente começa outra.
        .inFilter('fk_status', [
          StatusSolicitacaoGeo.solicitada,
          StatusSolicitacaoGeo.visualizada,
          StatusSolicitacaoGeo.aceita,
        ])
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
      idStatus:
          (row['fk_status'] as num?)?.toInt() ??
          StatusSolicitacaoGeo.solicitada,
      metodoEntrega: row['metodo_entrega']?.toString(),
      centro: lat != null && lng != null ? LatLng(lat, lng) : null,
    );
  }

  /// Status atual da solicitação geográfica (para saber se foi aceita).
  static Future<int?> statusDa(int idSolicitacaoGeo) async {
    final row = await _db
        .from('solicitacoes_geograficas')
        .select('fk_status')
        .eq('id_solicitacao_geografica', idSolicitacaoGeo)
        .maybeSingle();
    return (row?['fk_status'] as num?)?.toInt();
  }

  /// Cliente: profissional que aceitou + solicitação vinculada.
  static Future<AcompanhamentoGeo?> acompanhamento(int idSolicitacaoGeo) async {
    try {
      final rows = await _db.rpc(
        'acompanhamento_solicitacao_geografica',
        params: {'p_id_solicitacao_geografica': idSolicitacaoGeo},
      );
      final lista = rows as List;
      if (lista.isEmpty) return null;
      return AcompanhamentoGeo.fromMap(
        Map<String, dynamic>.from(lista.first as Map),
      );
    } on PostgrestException catch (e) {
      throw Exception(_mensagemRpc(e));
    }
  }

  /// Profissional aceita: cria a `solicitacoes` (Aguardando Pagamento) e
  /// devolve o id dela.
  static Future<int> aceitar({
    required int idSolicitacaoGeo,
    required double valor,
    required bool contaEmpresa,
  }) async {
    try {
      final id = await _db.rpc(
        'aceitar_solicitacao_geografica',
        params: {
          'p_id_solicitacao_geografica': idSolicitacaoGeo,
          'p_valor': valor,
          'p_conta_empresa': contaEmpresa,
        },
      );
      return (id as num).toInt();
    } on PostgrestException catch (e) {
      throw Exception(_mensagemRpc(e));
    }
  }

  /// Profissional: solicitações do Radar que ele aceitou (não concluídas).
  static Future<List<SolicitacaoGeoAceita>> aceitas({
    required bool contaEmpresa,
  }) async {
    try {
      final rows = await _db.rpc(
        'solicitacoes_geograficas_aceitas',
        params: {'p_conta_empresa': contaEmpresa},
      );
      return (rows as List)
          .map(
            (r) => SolicitacaoGeoAceita.fromMap(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(_mensagemRpc(e));
    }
  }

  static String _mensagemRpc(PostgrestException e) {
    if (e.code == 'PGRST202') {
      return 'Banco desatualizado. Rode '
          'docs/sql/migration_solicitacoes_geograficas_v4.sql no Supabase.';
    }
    return e.message;
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
          'docs/sql/migration_solicitacoes_geograficas_v3.sql no Supabase.',
        );
      }
      throw Exception(e.message);
    }
  }

  /// Cancela: antes do aceite → 43; depois do aceite e antes de pagar, a
  /// solicitação vinculada vai para Cancelado (7) e a geográfica para 40.
  static Future<void> cancelar(int idSolicitacao) async {
    try {
      await _db.rpc(
        'cancelar_solicitacao_geografica',
        params: {'p_id_solicitacao_geografica': idSolicitacao},
      );
    } on PostgrestException catch (e) {
      throw Exception(_mensagemRpc(e));
    }
  }
}
