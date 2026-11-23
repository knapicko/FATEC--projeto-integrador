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

  /// Selo "!" na aba Perfil/Empresa da barra inferior.
  static final abaPendenteCliente = ValueNotifier<bool>(false);
  static final abaPendenteProfissional = ValueNotifier<bool>(false);
  static DateTime? _ultimaCliente;
  static DateTime? _ultimaProfissional;

  /// Reconfere o que falta (no máximo a cada 15 s, a não ser [forcar]).
  static Future<void> atualizarAbaPendente({
    required bool profissional,
    bool forcar = false,
  }) async {
    if (_db.auth.currentUser == null) {
      abaPendenteCliente.value = false;
      abaPendenteProfissional.value = false;
      return;
    }
    final agora = DateTime.now();
    final ultima = profissional ? _ultimaProfissional : _ultimaCliente;
    if (!forcar &&
        ultima != null &&
        agora.difference(ultima) < const Duration(seconds: 15)) {
      return;
    }
    if (profissional) {
      _ultimaProfissional = agora;
      final pend = await pendenciasProfissional();
      abaPendenteProfissional.value = pend.isNotEmpty;
    } else {
      _ultimaCliente = agora;
      abaPendenteCliente.value = !await clienteTemEndereco();
    }
  }

  // Chaves de pendência do profissional.
  static const disponibilidade = 'disponibilidade';
  static const entrega = 'entrega';

  /// Meio de locomoção (e placa, quando motorizado).
  static const locomocao = 'locomocao';

  /// Meios de locomoção aceitos e os que exigem placa.
  static const meiosLocomocao = [
    'Carro',
    'Moto',
    'Bicicleta',
    'Transporte público',
    'Caminhão',
  ];
  static bool exigePlaca(String? meio) =>
      meio == 'Carro' || meio == 'Moto' || meio == 'Caminhão';

  /// Placa no padrão antigo (ABC-1234) ou Mercosul (ABC1D23).
  static bool placaValida(String? placa) => RegExp(
    r'^[A-Z]{3}-?[0-9][A-Z0-9][0-9]{2}$',
  ).hasMatch((placa ?? '').trim().toUpperCase());

  /// Falta definir como se locomove (ou a placa do veículo).
  static Future<bool> locomocaoPendente({
    int? idGrupo,
    int? idProfissional,
  }) async {
    try {
      final r = idGrupo != null
          ? await _db
                .from('grupo_empresa')
                .select('meio_locomocao, placa_veiculo')
                .eq('id_grupo_empresa', idGrupo)
                .maybeSingle()
          : idProfissional == null
          ? null
          : await _db
                .from('dados_profissionais')
                .select('meio_locomocao, placa_veiculo')
                .eq('id_profissional', idProfissional)
                .maybeSingle();
      if (r == null) return false;
      final meio = r['meio_locomocao']?.toString().trim() ?? '';
      if (meio.isEmpty || meio == 'null') return true;
      return exigePlaca(meio) && !placaValida(r['placa_veiculo']?.toString());
    } catch (_) {
      // Banco sem as colunas (docs/sql/v0_10_ajustes.sql): não bloqueia.
      return false;
    }
  }

  /// A chave PIX só é obrigatória quando o Pix está entre as formas de
  /// pagamento aceitas (sem nada salvo, o padrão é Pix).
  static bool precisaChavePix(Map<String, dynamic>? dados) {
    final pag =
        dados?['pagamento_aceito']?.toString().trim().toLowerCase() ?? '';
    final aceitaPix =
        pag.isEmpty ||
        pag == 'null' ||
        pag.split(',').any((e) => e.trim() == 'pix');
    return aceitaPix && _vazio(dados?['chave_pix']);
  }

  /// Métodos de entrega ainda no padrão do cadastro (só "leva e traz"): o
  /// profissional precisa salvá-los pelo menos uma vez.
  static Future<bool> entregaNuncaDefinida({
    int? idGrupo,
    int? idProfissional,
  }) async {
    try {
      final r = idGrupo != null
          ? await _db
                .from('grupo_empresa')
                .select('metodo_entrega_definido')
                .eq('id_grupo_empresa', idGrupo)
                .maybeSingle()
          : idProfissional == null
          ? null
          : await _db
                .from('dados_profissionais')
                .select('metodo_entrega_definido')
                .eq('id_profissional', idProfissional)
                .maybeSingle();
      return r != null && r['metodo_entrega_definido'] != true;
    } catch (_) {
      // Sem a coluna (docs/sql/v0_7_ajustes.sql): vale só o vazio.
      return false;
    }
  }

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

  /// Linha de dados_profissionais da pessoa logada, achada pelo login
  /// (auth_id) — e não por uma linha de `usuarios` qualquer. Tentativas de
  /// cadastro repetidas podem deixar mais de uma linha; aqui vale a que tem
  /// dados de profissional (a independente primeiro). Null se não houver.
  static Future<Map<String, dynamic>?> dadosProfissionalLogado(
    String colunas,
  ) async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    try {
      final r = await _db
          .from('dados_profissionais')
          .select('$colunas, fk_usuario, usuarios!inner(auth_id)')
          .eq('usuarios.auth_id', user.id)
          .order('fk_grupo_empresa', nullsFirst: true)
          .order('id_profissional')
          .limit(1);
      if (r.isNotEmpty) return Map<String, dynamic>.from(r.first);
      return null;
    } catch (e) {
      debugPrint('[requisitos] dados do profissional: $e');
    }
    // Sem a relação usuarios <-> dados_profissionais: busca em duas etapas.
    final us = await _db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id);
    for (final u in us) {
      final r = await _db
          .from('dados_profissionais')
          .select('$colunas, fk_usuario')
          .eq('fk_usuario', u['id_usuario'])
          .order('id_profissional')
          .limit(1);
      if (r.isNotEmpty) return Map<String, dynamic>.from(r.first);
    }
    return null;
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
      // Conta ativa confirmada (o cache síncrono podia estar desatualizado
      // e conferir a OUTRA conta — aí o Radar não abria).
      final empresa =
          contaEmpresa ??
          await BottomNavigationBarProfissional.precarregarContaEmpresa();
      final dp = await dadosProfissionalLogado(
        'id_profissional, fk_perfil, fk_grupo_empresa, anos_experiencia, '
        'chave_pix, pagamento_aceito, metodo_entrega',
      );
      // Não conseguiu ler os dados do profissional: considera tudo pendente
      // (antes devolvia "nada pendente" e liberava criar serviço).
      if (dp == null) {
        return {
          disponibilidade,
          entrega,
          locomocao,
          financeiro,
          enderecos,
          conta,
        };
      }
      final idProf = (dp['id_profissional'] as num?)?.toInt();

      Map<String, dynamic>? grupo;
      if (empresa) {
        try {
          final porPerfil = dp['fk_perfil'] == null
              ? null
              : await _db
                    .from('grupo_empresa')
                    .select(
                      'id_grupo_empresa, chave_pix, pagamento_aceito, '
                      'metodo_entrega_empresa',
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
                          'id_grupo_empresa, chave_pix, pagamento_aceito, '
                          'metodo_entrega_empresa',
                        )
                        .eq('id_grupo_empresa', dp['fk_grupo_empresa'])
                        .maybeSingle());
        } catch (_) {}
      }
      final idGrupo = (grupo?['id_grupo_empresa'] as num?)?.toInt();

      if (precisaChavePix(grupo ?? dp)) pend.add(financeiro);
      final metodo = grupo != null
          ? (grupo['metodo_entrega_empresa'] ?? dp['metodo_entrega'])
          : dp['metodo_entrega'];
      if (_vazio(metodo)) pend.add(entrega);
      if (await entregaNuncaDefinida(
        idGrupo: idGrupo,
        idProfissional: idProf,
      )) {
        pend.add(entrega);
      }
      if (await locomocaoPendente(idGrupo: idGrupo, idProfissional: idProf)) {
        pend.add(locomocao);
      }

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
      if (pend.contains(locomocao))
        (Icons.two_wheeler_outlined, 'Locomoção e placa', locomocao),
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
      titulo: 'Falta pouco para começar',
      mensagem:
          'Para adicionar serviços e usar o Radar, defina estes itens da '
          'sua conta:',
      itens: falta,
      botao: 'Entendi',
    );
    if (escolha is String && context.mounted) {
      final Widget pagina = switch (escolha) {
        entrega || locomocao => const MetodoEntregaProfissionalPage(),
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
