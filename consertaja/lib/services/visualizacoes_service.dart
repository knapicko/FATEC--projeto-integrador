import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conta visitas ao perfil e aos serviços (funil de visibilidade das
/// Estatísticas do profissional). O banco ignora o próprio dono e repetições
/// da mesma pessoa em 30 minutos.
class VisualizacoesService {
  VisualizacoesService._();

  static Future<void> registrar({
    int? idProfissional,
    int? idGrupoEmpresa,
    int? idServico,
    bool servico = false,
  }) async {
    if (idProfissional == null && idGrupoEmpresa == null) return;
    try {
      await Supabase.instance.client.rpc(
        'registrar_visualizacao',
        params: {
          'p_id_profissional': idGrupoEmpresa == null ? idProfissional : null,
          'p_id_grupo_empresa': idGrupoEmpresa,
          'p_id_servico': idServico,
          'p_tipo': servico ? 'servico' : 'perfil',
        },
      );
    } catch (e) {
      // Banco sem a v0_13: só não conta a visita.
      debugPrint('Visualizacoes: $e');
    }
  }
}
