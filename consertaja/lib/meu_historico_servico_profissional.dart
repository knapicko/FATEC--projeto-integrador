import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/conta_profissional_ativa.dart';
import 'services/pedidos_cliente_service.dart';
import 'utils/abrir_solicitacao.dart';
import 'widgets/card_pedido_resumo.dart';
import 'widgets/selo_conta_ativa.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Histórico de todos os serviços que o profissional (ou a loja, com a conta
/// de loja ativa) recebeu. Mesmo visual do histórico do cliente.
class MeuHistoricoServicoProfissionalPage extends StatefulWidget {
  const MeuHistoricoServicoProfissionalPage({super.key});

  @override
  State<MeuHistoricoServicoProfissionalPage> createState() =>
      _MeuHistoricoServicoProfissionalPageState();
}

class _MeuHistoricoServicoProfissionalPageState
    extends State<MeuHistoricoServicoProfissionalPage> {
  ContaProfissionalAtiva? _conta;
  List<PedidoResumo>? _pedidos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final conta = await ContaProfissionalAtiva.carregar();
      final l = conta == null ? const <PedidoResumo>[] : await _listar(conta);
      if (!mounted) return;
      setState(() {
        _conta = conta;
        _pedidos = l;
        _erro = conta == null
            ? 'Não foi possível identificar sua conta.'
            : null;
      });
    } catch (e) {
      debugPrint('[histórico prof] $e');
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar seus serviços.');
      }
    }
  }

  static String? _url(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.startsWith('http') ? s : null;
  }

  /// Solicitações da conta ativa: loja (fk_grupo_empresa) ou independente
  /// (fk_profissional, sem loja).
  static Future<List<PedidoResumo>> _listar(ContaProfissionalAtiva c) async {
    var q = _db
        .from('solicitacoes')
        .select(
          'id_solicitacao, fk_status, valor_final, data_solicitacao, '
          'fk_servico_prof, fk_servico_temp, fk_usuario, '
          'imagens_anexadas_cliente',
        );
    if (c.empresa) {
      if (c.idGrupoEmpresa == null) return const [];
      q = q.eq('fk_grupo_empresa', c.idGrupoEmpresa!);
    } else {
      if (c.idProfissional == null) return const [];
      q = q
          .eq('fk_profissional', c.idProfissional!)
          .isFilter('fk_grupo_empresa', null);
    }
    final rows = List<Map<String, dynamic>>.from(
      await q.order('data_solicitacao', ascending: false),
    );
    if (rows.isEmpty) return const [];

    Set<int> col(String n) => {
      for (final r in rows)
        if (r[n] != null) (r[n] as num).toInt(),
    };

    Future<Map<int, Map<String, dynamic>>> porId(
      String tabela,
      String chave,
      String campos,
      Set<int> ids,
    ) async {
      if (ids.isEmpty) return {};
      try {
        final r = await _db
            .from(tabela)
            .select('$chave, $campos')
            .inFilter(chave, ids.toList());
        return {for (final x in r) (x[chave] as num).toInt(): x};
      } catch (e) {
        debugPrint('[histórico prof] $tabela: $e');
        return {};
      }
    }

    const camposServico =
        'titulo, imagem_url, funcoes(funcao, oficios(cor, cod_cor))';
    final resultados = await Future.wait([
      porId('status', 'id_status', 'status', col('fk_status')),
      porId(
        'servicos_profissional',
        'id_servico_prof',
        camposServico,
        col('fk_servico_prof'),
      ),
      porId(
        'servicos_chat_temporarios',
        'id_servico_temp',
        camposServico,
        col('fk_servico_temp'),
      ),
      porId(
        'usuarios',
        'id_usuario',
        'nome, foto_perfil_url',
        col('fk_usuario'),
      ),
    ]);
    final status = resultados[0];
    final servicos = resultados[1];
    final temps = resultados[2];
    final clientes = resultados[3];

    return [
      for (final r in rows)
        () {
          final id = (r['id_solicitacao'] as num).toInt();
          final st = (r['fk_status'] as num?)?.toInt();
          final s =
              servicos[(r['fk_servico_prof'] as num?)?.toInt() ?? -1] ??
              temps[(r['fk_servico_temp'] as num?)?.toInt() ?? -1];
          final funcoes = s?['funcoes'];
          final oficio = funcoes is Map ? funcoes['oficios'] : null;
          final cli = clientes[(r['fk_usuario'] as num?)?.toInt() ?? -1];
          final anexos = r['imagens_anexadas_cliente'];
          return PedidoResumo(
            id: id,
            fkStatus: st,
            status: status[st ?? -1]?['status']?.toString() ?? 'Pedido',
            titulo: s?['titulo']?.toString() ?? 'Serviço',
            // No histórico do profissional a pessoa do card é o cliente.
            prestador: cli?['nome']?.toString() ?? 'Cliente',
            fotoPrestador: _url(cli?['foto_perfil_url']),
            imagem:
                _url(s?['imagem_url']) ??
                (anexos is List && anexos.isNotEmpty
                    ? _url(anexos.first)
                    : null),
            valor: (r['valor_final'] as num?)?.toDouble() ?? 0,
            data: DateTime.tryParse(
              r['data_solicitacao']?.toString() ?? '',
            )?.toLocal(),
            // O profissional não avalia o cliente: nada pendente.
            avaliado: true,
            funcao: funcoes is Map ? funcoes['funcao']?.toString() : null,
            corOficio: oficio is Map
                ? (oficio['cod_cor'] ?? oficio['cor'])?.toString()
                : null,
          );
        }(),
    ];
  }

  Future<void> _tocar(PedidoResumo p) async {
    await abrirSolicitacaoPorStatus(context, p.id, comoProfissional: true);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final l = _pedidos;
    final conta = _conta;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: appBarPerfil(
        'Histórico de Serviços',
        acoes: [
          BotaoAjuda(
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui fica o histórico dos serviços que você recebeu.',
              conteudo: [
                'O selo no topo mostra de qual conta são os serviços: independente ou loja.',
                'Toque em um serviço para abrir a etapa dele.',
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _erro != null
            ? listaVaziaPerfil(Icons.wifi_off_rounded, 'Ops!', _erro!)
            : l == null || conta == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SkeletonBox(height: 58, borderRadius: 14),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 5; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonBox(height: 96, borderRadius: 18),
                    ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  SeloContaAtiva(
                    conta: conta,
                    texto: conta.empresa
                        ? 'Serviços recebidos pela loja'
                        : 'Serviços recebidos por você',
                  ),
                  const SizedBox(height: 12),
                  if (l.isEmpty)
                    SizedBox(
                      height: 420,
                      child: listaVaziaPerfil(
                        Icons.inventory_2_outlined,
                        'Nenhum serviço ainda',
                        'Quando um cliente pedir um serviço, ele aparece aqui.',
                      ),
                    )
                  else ...[
                    Text(
                      '${l.length} ${l.length == 1 ? 'serviço' : 'serviços'}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final p in l)
                      CardPedidoResumo(pedido: p, aoTocar: () => _tocar(p)),
                  ],
                ],
              ),
      ),
    );
  }
}
