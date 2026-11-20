import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/bottom_navigation_bar_profissional.dart';
import 'requisitos_conta.dart';

/// Conta do profissional que está ativa agora: independente (CPF/CNPJ do
/// próprio profissional) ou loja (grupo_empresa). As telas usam isso para
/// mostrar só os dados da conta certa.
class ContaProfissionalAtiva {
  const ContaProfissionalAtiva({
    required this.empresa,
    required this.idProfissional,
    required this.idUsuario,
    this.idGrupoEmpresa,
    this.nomeEmpresa,
    this.fotoEmpresa,
    this.nomeProfissional,
    this.fotoProfissional,
    this.donoEmpresa = false,
    this.membroEmpresa = false,
  });

  /// true = conta de loja ativa; false = profissional independente.
  final bool empresa;
  final int? idProfissional;
  final int? idUsuario;
  final int? idGrupoEmpresa;
  final String? nomeEmpresa;
  final String? fotoEmpresa;
  final String? nomeProfissional;
  final String? fotoProfissional;
  final bool donoEmpresa;

  /// Funcionário de uma loja (não é o dono): não edita os serviços.
  final bool membroEmpresa;

  bool get podeEditar => !membroEmpresa;

  String get rotulo => empresa ? 'Loja' : 'Independente';

  /// Nome mostrado no selo da conta ativa.
  String get nomeExibicao => empresa
      ? (nomeEmpresa?.trim().isNotEmpty == true ? nomeEmpresa!.trim() : 'Loja')
      : (nomeProfissional?.trim().isNotEmpty == true
            ? nomeProfissional!.trim()
            : 'Profissional');

  String? get fotoExibicao => empresa ? fotoEmpresa : fotoProfissional;

  static Future<ContaProfissionalAtiva?> carregar() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) return null;
    final empresa =
        await BottomNavigationBarProfissional.precarregarContaEmpresa();
    final u = await db
        .from('usuarios')
        .select('id_usuario, nome, foto_perfil_url')
        .eq('auth_id', user.id)
        .limit(1)
        .maybeSingle();
    final dp = await RequisitosConta.dadosProfissionalLogado(
      'id_profissional, fk_perfil, fk_grupo_empresa',
    );
    final idPerfil = (dp?['fk_perfil'] as num?)?.toInt();
    final fkGrupo = (dp?['fk_grupo_empresa'] as num?)?.toInt();

    // Loja: a do dono (mesmo perfil) ou a que o funcionário pertence.
    Map<String, dynamic>? grupo;
    try {
      if (idPerfil != null) {
        grupo = await db
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, foto_url_empresa, fk_perfil',
            )
            .eq('fk_perfil', idPerfil)
            .limit(1)
            .maybeSingle();
      }
      if (grupo == null && fkGrupo != null) {
        grupo = await db
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, foto_url_empresa, fk_perfil',
            )
            .eq('id_grupo_empresa', fkGrupo)
            .maybeSingle();
      }
    } catch (_) {}
    final dono =
        grupo != null &&
        idPerfil != null &&
        (grupo['fk_perfil'] as num?)?.toInt() == idPerfil;

    String? url(Object? v) {
      final s = v?.toString().trim() ?? '';
      return s.startsWith('http') ? s : null;
    }

    return ContaProfissionalAtiva(
      empresa: empresa,
      idProfissional: (dp?['id_profissional'] as num?)?.toInt(),
      idUsuario: (u?['id_usuario'] as num?)?.toInt(),
      idGrupoEmpresa: (grupo?['id_grupo_empresa'] as num?)?.toInt(),
      nomeEmpresa: grupo?['nome_empresa']?.toString(),
      fotoEmpresa: url(grupo?['foto_url_empresa']),
      nomeProfissional: u?['nome']?.toString(),
      fotoProfissional: url(u?['foto_perfil_url']),
      donoEmpresa: dono,
      membroEmpresa: fkGrupo != null && !dono,
    );
  }
}
