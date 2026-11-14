import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Filtro preto e branco usado nos mapas do app (igual ao meus_enderecos).
const List<double> matrizMapaCinza = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Token do Mapbox — o MESMO da tela de deslocamento
/// (tela_deslocamento_profissional.dart): `--dart-define=MAPBOX_ACCESS_TOKEN=...`
/// ou o salvo em SharedPreferences ('mapbox_access_token').
class TokenMapbox {
  TokenMapbox._();

  static const String _doBuild = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static String? _cache;

  static String get atual => _cache ?? _doBuild.trim();

  static Future<String> carregar() async {
    if (_cache != null) return _cache!;
    var token = _doBuild.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString('mapbox_access_token')?.trim() ?? '';
      if (salvo.isNotEmpty) token = salvo;
    } catch (_) {}
    _cache = token;
    return token;
  }
}

/// Camada de tiles para os mapas em TELA CHEIA do Radar (cliente/profissional).
///
/// Usa o Mapbox (estilo light, já em tons de cinza) com o token do app. Sem
/// token cai no CARTO e, se este falhar, no OpenStreetMap. Não pré-carrega
/// tiles fora da tela e tenta de novo os que deram erro.
class CamadaMapaCinza extends StatefulWidget {
  const CamadaMapaCinza({super.key});

  @override
  State<CamadaMapaCinza> createState() => _CamadaMapaCinzaState();
}

class _CamadaMapaCinzaState extends State<CamadaMapaCinza> {
  static const String _estilo = 'light-v11';
  String _token = TokenMapbox.atual;

  @override
  void initState() {
    super.initState();
    TokenMapbox.carregar().then((t) {
      if (mounted && t != _token) setState(() => _token = t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final temToken = _token.isNotEmpty;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(matrizMapaCinza),
      child: TileLayer(
        // A key muda quando o token chega, para recarregar os tiles.
        key: ValueKey(temToken),
        urlTemplate: temToken
            ? 'https://api.mapbox.com/styles/v1/mapbox/$_estilo/tiles/256/{z}/{x}/{y}@2x?access_token=$_token'
            : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'br.com.consertaja',
        maxNativeZoom: 19,
        maxZoom: 20,
        panBuffer: 0,
        evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
      ),
    );
  }
}

/// Crédito exigido pelos provedores de mapa (canto do mapa).
class CreditoMapa extends StatelessWidget {
  const CreditoMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final texto = TokenMapbox.atual.isNotEmpty
        ? '© Mapbox © OpenStreetMap'
        : '© OpenStreetMap © CARTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 9, color: Color(0xFF4B5563)),
      ),
    );
  }
}
