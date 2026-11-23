import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tipo de conexão atual (Wi-Fi x dados móveis), para as opções de
/// "Rede e dados" das configurações.
class RedeService extends ChangeNotifier {
  RedeService._();

  static final RedeService instance = RedeService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  List<ConnectivityResult> _atual = const [ConnectivityResult.wifi];
  bool _iniciado = false;

  /// Conectado por Wi-Fi ou cabo (rede que não consome franquia).
  bool get emWifi =>
      _atual.contains(ConnectivityResult.wifi) ||
      _atual.contains(ConnectivityResult.ethernet);

  bool get semConexao =>
      _atual.isEmpty || _atual.every((r) => r == ConnectivityResult.none);

  /// Texto curto para mostrar nas configurações.
  String get descricao {
    if (semConexao) return 'Sem conexão';
    if (emWifi) return 'Wi-Fi';
    if (_atual.contains(ConnectivityResult.mobile)) return 'Dados móveis';
    if (_atual.contains(ConnectivityResult.vpn)) return 'VPN';
    return 'Outra rede';
  }

  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    try {
      _atual = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('RedeService: $e');
    }
    _sub = _connectivity.onConnectivityChanged.listen((r) {
      _atual = r;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
