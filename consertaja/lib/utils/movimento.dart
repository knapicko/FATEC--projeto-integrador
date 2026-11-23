import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

import '../services/app_settings_controller.dart';

/// Acessibilidade → "Reduzir animações".
///
/// [duracao] zera a duração das animações quando a opção está ligada (a
/// mudança acontece na hora, sem movimento). Usado nos AnimationController e
/// nas animações implícitas (AnimatedContainer, AnimatedOpacity...).
Duration duracao(Duration d) =>
    AppSettingsController.semAnimacao ? Duration.zero : d;

extension RepetirAnimacao on AnimationController {
  /// `repeat` que respeita "Reduzir animações": com a opção ligada a animação
  /// em loop fica parada no estado final (visível) em vez de se mexer.
  TickerFuture repetir({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    if (AppSettingsController.semAnimacao ||
        (duration ?? Duration.zero) <= Duration.zero && period == null) {
      stop();
      value = upperBound;
      return TickerFuture.complete();
    }
    return repeat(
      min: min,
      max: max,
      reverse: reverse,
      period: period,
      count: count,
    );
  }
}

/// Acessibilidade → "Reduzir transparências": sem desfoque de fundo.
ui.ImageFilter desfoque(double sigma) => AppSettingsController.semTransparencia
    ? ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0)
    : ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
