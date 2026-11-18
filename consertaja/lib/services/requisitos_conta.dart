import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../alterar_disponibilidade.dart';
import '../meus_dados_financeiros_profissional.dart';
import '../meus_enderecos.dart';
import '../metodo_entrega_profissional.dart';
import '../utils/bottom_navigation_bar_profissional.dart';

SupabaseClient get _db => Supabase.instance.client;

bool _vazio(Object? v) {
  final t = v?.toString().trim() ?? '';
  return t.isEmpty || t == 'null' || t == '[]';
}

/// O que falta configurar na conta. Usado nos avisos "!" (home e meu perfil)
/// e para bloquear ações até a conta estar pronta.
class RequisitosConta {
  RequisitosConta._();

  // Chaves de pendência do profissional.
  static const disponibilidade = 'disponibilidade';
  static const entrega = 'entrega';
  static const financeiro = 'financeiro';
  static const enderecos = 'enderecos';
  static const conta = 'conta';

  static Future<int?> _idUsuario() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final u = await _db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id)
        .limit(1)
        .maybeSingle();
    return (u?['id_usuario'] as num?)?.toInt();
  }

  /// O cliente tem pelo menos 1 endereço cadastrado?
  static Future<bool> clienteTemEndereco() async {
    try {
      final id = await _idUsuario();
      if (id == null) return false;
      final rows = await _db
          .from('ass_usuario_endereco')
          .select('fk_endereco')
          .eq('fk_usuario', id)
          .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return true; // sem conexão: não bloqueia à toa
    }
  }

  /// Pendências do profissional na conta ativa (independente ou loja).
  static Future<Set<String>> pendenciasProfissional({
    bool? contaEmpresa,
  }) async {
    final pend = <String>{};
    try {
      final empresa =
          contaEmpresa ??
          BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
      final idUsuario = await _idUsuario();
      if (idUsuario == null) return pend;
      final dp = await _db
          .from('dados_profissionais')
          .select(
            'id_profissional, fk_perfil, fk_grupo_empresa, anos_experiencia, '
            'chave_pix, metodo_entrega',
          )
          .eq('fk_usuario', idUsuario)
          .limit(1)
          .maybeSingle();
      if (dp == null) return pend;
      final idProf = (dp['id_profissional'] as num?)?.toInt();

      Map<String, dynamic>? grupo;
      if (empresa) {
        try {
          final porPerfil = dp['fk_perfil'] == null
              ? null
              : await _db
                    .from('grupo_empresa')
                    .select(
                      'id_grupo_empresa, chave_pix, metodo_entrega_empresa',
                    )
                    .eq('fk_perfil', dp['fk_perfil'])
                    .limit(1)
                    .maybeSingle();
          grupo =
              porPerfil ??
              (dp['fk_grupo_empresa'] == null
                  ? null
                  : await _db
                        .from('grupo_empresa')
                        .select(
                          'id_grupo_empresa, chave_pix, metodo_entrega_empresa',
                        )
                        .eq('id_grupo_empresa', dp['fk_grupo_empresa'])
                        .maybeSingle());
        } catch (_) {}
      }
      final idGrupo = (grupo?['id_grupo_empresa'] as num?)?.toInt();

      if (_vazio((grupo ?? dp)['chave_pix'])) pend.add(financeiro);
      final metodo = grupo != null
          ? (grupo['metodo_entrega_empresa'] ?? dp['metodo_entrega'])
          : dp['metodo_entrega'];
      if (_vazio(metodo)) pend.add(entrega);

      try {
        final q = _db
            .from('agenda_profissional')
            .select('dias_semana')
            .eq('fk_solicitacao', 0);
        final agenda = idGrupo != null
            ? await q.eq('fk_grupo_empresa', idGrupo).limit(1).maybeSingle()
            : idProf == null
            ? null
            : await q.eq('fk_profissional', idProf).limit(1).maybeSingle();
        if (_vazio(agenda?['dias_semana'])) pend.add(disponibilidade);
      } catch (_) {}

      if (!empresa) {
        var descricao = '';
        if (dp['fk_perfil'] != null) {
          try {
            final perfil = await _db
                .from('perfil')
                .select('descricao_perfil')
                .eq('id_perfil', dp['fk_perfil'])
                .maybeSingle();
            descricao = perfil?['descricao_perfil']?.toString().trim() ?? '';
          } catch (_) {}
        }
        if (descricao.isEmpty || _vazio(dp['anos_experiencia'])) {
          pend.add(conta);
        }
      }

      try {
        final ends = idGrupo != null
            ? await _db
                  .from('ass_grupo_empresa_endereco')
                  .select('fk_endereco')
                  .eq('fk_grupo_empresa', idGrupo)
                  .limit(1)
            : idProf == null
            ? const <Map<String, dynamic>>[]
            : await _db
                  .from('ass_profissional_endereco')
                  .select('fk_endereco')
                  .eq('fk_profissional', idProf)
                  .limit(1);
        if (ends.isEmpty) pend.add(enderecos);
      } catch (_) {}
    } catch (e) {
      debugPrint('[requisitos] $e');
    }
    return pend;
  }

  /// Cliente: sem endereço não pede serviço / não usa o Radar. Mostra o
  /// aviso e devolve false.
  static Future<bool> garantirEnderecoCliente(BuildContext context) async {
    if (await clienteTemEndereco()) return true;
    if (!context.mounted) return false;
    final ir = await _sheet(
      context,
      icone: Icons.location_on_outlined,
      titulo: 'Cadastre um endereço',
      mensagem:
          'Para pedir serviços, usar o Radar ou montar sua lista, você '
          'precisa ter pelo menos 1 endereço cadastrado.',
      itens: const [],
      botao: 'Cadastrar endereço',
    );
    if (ir == true && context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MeusEnderecosPage()));
    }
    return false;
  }

  /// Profissional: só cria serviços com método de entrega, chave PIX,
  /// endereço e disponibilidade definidos.
  static Future<bool> garantirProntoParaServicos(BuildContext context) async {
    final pend = await pendenciasProfissional();
    final falta = [
      if (pend.contains(entrega))
        (Icons.local_shipping_outlined, 'Método de entrega', entrega),
      if (pend.contains(financeiro))
        (Icons.account_balance_wallet_outlined, 'Chave PIX', financeiro),
      if (pend.contains(enderecos))
        (Icons.location_on_outlined, 'Endereço', enderecos),
      if (pend.contains(disponibilidade))
        (Icons.calendar_month_outlined, 'Disponibilidade', disponibilidade),
    ];
    if (falta.isEmpty) return true;
    if (!context.mounted) return false;
    final escolha = await _sheet(
      context,
      icone: Icons.playlist_add_check_rounded,
      titulo: 'Falta pouco para criar serviços',
      mensagem: 'Antes de adicionar serviços, defina estes itens da sua conta:',
      itens: falta,
      botao: 'Entendi',
    );
    if (escolha is String && context.mounted) {
      final Widget pagina = switch (escolha) {
        entrega => const MetodoEntregaProfissionalPage(),
        financeiro => const MeusDadosFinanceirosProfissionalPage(),
        enderecos => const MeusEnderecosPage(isProfissional: true),
        _ => AlterarDisponibilidadePage(
          isEmpresa:
              BottomNavigationBarProfissional.leituraSincronaContaEmpresa(),
        ),
      };
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => pagina));
    }
    return false;
  }

  static Future<Object?> _sheet(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    required String mensagem,
    required List<(IconData, String, String)> itens,
    required String botao,
  }) {
    const azul = Color(0xFF0FB3FF);
    return showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7E6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: const Color(0xFFF59E0B), size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final (ic, rotulo, chave) in itens)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(ic, color: azul),
                  title: Text(
                    rotulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Text(
                    'Definir ›',
                    style: TextStyle(color: azul, fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(ctx, chave),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, itens.isEmpty),
                  style: FilledButton.styleFrom(
                    backgroundColor: azul,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    botao,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
