import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/solicitacao_geografica_service.dart';
import '../utils/bottom_navigation_bar_profissional.dart';
import 'camada_mapa.dart';
import 'sonar_pulso.dart';

/// Prévia do Radar na home do profissional: o mesmo mapa da
/// solicitacao_geografica_profissional.dart, só que pequeno e sem gestos.
///
/// Mostra o raio de 5 km em volta do ENDEREÇO do profissional (centralizado),
/// a bolinha dele e as bolinhas das solicitações abertas da área, e embaixo o
/// texto "Há N solicitações de pedido na sua área". Tocar chama [aoTocar].
class PreviaRadarProfissional extends StatefulWidget {
  const PreviaRadarProfissional({
    super.key,
    required this.aoTocar,
    this.altura = 170,
    this.chaveInfo,
  });

  final VoidCallback aoTocar;
  final double altura;

  /// Chave do texto "Há N solicitações..." (destaque do tutorial).
  final Key? chaveInfo;

  @override
  State<PreviaRadarProfissional> createState() =>
      _PreviaRadarProfissionalState();
}

class _PreviaRadarProfissionalState extends State<PreviaRadarProfissional> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF1D2430);
  static const Color _textoSec = Color(0xFF6B7280);

  /// Centro quando não há endereço (São Paulo).
  static const LatLng _centroPadrao = LatLng(-23.5505, -46.6333);

  bool _carregando = true;
  bool _semEndereco = false;
  bool _erro = false;
  LatLng? _posicao;
  List<SolicitacaoGeoProxima> _solicitacoes = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final pos =
          await SolicitacaoGeograficaService.localizacaoEnderecoProfissional(
            contaEmpresa:
                BottomNavigationBarProfissional.leituraSincronaContaEmpresa(),
          );
      if (!mounted) return;
      if (pos == null) {
        setState(() {
          _semEndereco = true;
          _posicao = _centroPadrao;
          _carregando = false;
        });
        return;
      }
      final lista = await SolicitacaoGeograficaService.solicitacoesProximas(
        pos,
      );
      if (!mounted) return;
      setState(() {
        _posicao = pos;
        _solicitacoes = lista;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('[PreviaRadar] $e');
      if (mounted) {
        setState(() {
          _erro = true;
          _carregando = false;
        });
      }
    }
  }

  /// Caixa que enquadra o círculo de 5 km.
  LatLngBounds _limitesDoRaio(LatLng c) {
    const raio = SolicitacaoGeograficaService.raioKm;
    final dLat = raio / 111.32;
    final dLng = raio / (111.32 * math.cos(c.latitude * math.pi / 180));
    return LatLngBounds(
      LatLng(c.latitude - dLat, c.longitude - dLng),
      LatLng(c.latitude + dLat, c.longitude + dLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.aoTocar,
          child: Container(
            height: widget.altura,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E7EF)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(child: _mapa()),
                  // "Abrir" no canto: deixa claro que o card é tocável.
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Abrir Radar',
                            style: TextStyle(
                              color: _azul,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _azul,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_carregando)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _azul,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        KeyedSubtree(key: widget.chaveInfo, child: _textoResumo()),
      ],
    );
  }

  Widget _mapa() {
    final pos = _posicao;
    if (pos == null) return const SizedBox.expand();
    return IgnorePointer(
      // Só prévia: sem arrastar/zoom; o toque vai para o GestureDetector.
      child: FlutterMap(
        key: ValueKey('${pos.latitude},${pos.longitude}'),
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: _limitesDoRaio(pos),
            padding: const EdgeInsets.all(10),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          const CamadaMapaCinza(),
          if (!_semEndereco)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: pos,
                  radius: SolicitacaoGeograficaService.raioKm * 1000,
                  useRadiusInMeter: true,
                  color: _azul.withValues(alpha: 0.14),
                  borderColor: _azul.withValues(alpha: 0.5),
                  borderStrokeWidth: 1.3,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final (i, s) in _solicitacoes.indexed)
                Marker(
                  point: s.posicao,
                  width: 54,
                  height: 54,
                  child: SonarPulso(
                    cor: _azul,
                    tamanho: 16,
                    alcance: 3.2,
                    atraso: Duration(milliseconds: i * 430),
                    child: _bolinha(16, borda: 2),
                  ),
                ),
              if (!_semEndereco)
                Marker(
                  point: pos,
                  width: 70,
                  height: 70,
                  child: SonarPulso(
                    cor: _azul,
                    tamanho: 22,
                    alcance: 3.0,
                    duracao: const Duration(milliseconds: 2600),
                    child: _bolinha(22, borda: 3, icone: Icons.sensors),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bolinha(double tamanho, {required double borda, IconData? icone}) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: _azul,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borda),
        boxShadow: [
          BoxShadow(color: _azul.withValues(alpha: 0.45), blurRadius: 6),
        ],
      ),
      child: icone == null
          ? null
          : Icon(icone, color: Colors.white, size: tamanho * 0.5),
    );
  }

  Widget _textoResumo() {
    const estilo = TextStyle(
      fontSize: 13,
      color: _texto,
      fontWeight: FontWeight.w500,
    );
    if (_carregando) {
      return const Text(
        'Buscando solicitações na sua área...',
        style: TextStyle(fontSize: 13, color: _textoSec),
      );
    }
    if (_erro) {
      return const Text(
        'Não foi possível carregar o Radar agora.',
        style: TextStyle(fontSize: 13, color: _textoSec),
      );
    }
    if (_semEndereco) {
      return const Text(
        'Cadastre o seu endereço para ver os pedidos da sua área.',
        style: TextStyle(fontSize: 13, color: _textoSec),
      );
    }
    final n = _solicitacoes.length;
    if (n == 0) {
      return const Text(
        'Nenhuma solicitação de pedido na sua área agora',
        style: estilo,
      );
    }
    return RichText(
      text: TextSpan(
        style: estilo,
        children: [
          const TextSpan(text: 'Há '),
          TextSpan(
            text: '$n',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _azul),
          ),
          TextSpan(
            text: n == 1
                ? ' solicitação de pedido na sua área'
                : ' solicitações de pedido na sua área',
          ),
        ],
      ),
    );
  }
}
