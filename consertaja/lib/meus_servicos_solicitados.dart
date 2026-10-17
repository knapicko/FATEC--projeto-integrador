import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gestao_equipe.dart';
import 'solicitacao_aceita.dart';
import 'services/solicitacoes_service.dart';
import 'tela_home_profissional.dart';
import 'tela_chat_profissional.dart';
import 'tela_mensagens.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/imagem_servico.dart';

/// Solicitação de serviço recebida pelo profissional (conta independente ou
/// conta empresa). Cada linha de `solicitacoes` vira um card.
class SolicitacaoRecebida {
  final int idSolicitacao;
  final DateTime dataSolicitacao;
  final double valorFinal;
  final String? detalhes;
  final String? dataAgendada;
  final String? horaAgendada;
  final String tipoExecucao;
  final int? fkGrupoEmpresa;
  final int fkProfissional;
  final int? fkUsuario;
  final int? fkEndereco;
  final String? statusTexto;

  final String nomeCliente;
  final String? fotoCliente;
  final String? imagemAnexoUrl;

  final String tituloServico;
  final String? descricaoServico;
  final String? imagemServicoUrl;
  final String? funcao;
  final String? corOficio;

  SolicitacaoRecebida({
    required this.idSolicitacao,
    required this.dataSolicitacao,
    required this.valorFinal,
    this.detalhes,
    this.dataAgendada,
    this.horaAgendada,
    required this.tipoExecucao,
    this.fkGrupoEmpresa,
    required this.fkProfissional,
    this.fkUsuario,
    this.fkEndereco,
    this.statusTexto,
    required this.nomeCliente,
    this.fotoCliente,
    this.imagemAnexoUrl,
    required this.tituloServico,
    this.descricaoServico,
    this.imagemServicoUrl,
    this.funcao,
    this.corOficio,
  });
}

/// Filtros da tela — espelham o `status` da tabela `status`.
enum FiltroSolicitacao {
  novos('Todos'),
  aceitos('Aceitos'),
  recusados('Recusados'),
  emAndamento('Em andamento'),
  concluidos('Concluídos');

  const FiltroSolicitacao(this.rotulo);
  final String rotulo;

  /// Normaliza o texto vindo do banco para comparação.
  static FiltroSolicitacao? porStatus(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('aberto') || s.contains('novo') || s.contains('pendente')) {
      return FiltroSolicitacao.novos;
    }
    if (s.contains('aceito')) return FiltroSolicitacao.aceitos;
    if (s.contains('recus') || s.contains('cancel')) {
      return FiltroSolicitacao.recusados;
    }
    if (s.contains('andamento') || s.contains('exec')) {
      return FiltroSolicitacao.emAndamento;
    }
    if (s.contains('conclu') || s.contains('finaliz') || s.contains('pago')) {
      return FiltroSolicitacao.concluidos;
    }
    return null;
  }
}

class MeusServicosSolicitadosPage extends StatefulWidget {
  const MeusServicosSolicitadosPage({super.key});

  @override
  State<MeusServicosSolicitadosPage> createState() =>
      _MeusServicosSolicitadosPageState();
}

class _MeusServicosSolicitadosPageState
    extends State<MeusServicosSolicitadosPage> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _textoEscuro = Color(0xFF0F172A);
  static const Color _textoMuted = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _contaEmpresaAtiva = false;
  String? _erro;

  List<SolicitacaoRecebida> _todas = [];
  FiltroSolicitacao _filtro = FiltroSolicitacao.novos;

  @override
  void initState() {
    super.initState();
    _contaEmpresaAtiva =
        BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
    BottomNavigationBarProfissional.precarregarContaEmpresa().then((ativa) {
      if (mounted && ativa != _contaEmpresaAtiva) {
        setState(() => _contaEmpresaAtiva = ativa);
        _carregar();
      }
    });
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Faça login.');
      final usuarioRow = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final idUsuario = (usuarioRow?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) throw Exception('Usuário não localizado.');
      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();
      final idProf = (dadosProf?['id_profissional'] as num?)?.toInt();
      if (idProf == null) throw Exception('Perfil não localizado.');
      final idGrupo = (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();
      // Empresa: SÓ fk_grupo_empresa do grupo. Independente: SÓ do
      // profissional SEM fk_grupo_empresa.
      // Há 2 FKs solicitacoes->status; desambigua pela constraint.
      var query = _supabase
          .from('solicitacoes')
          .select(
            'id_solicitacao, data_solicitacao, valor_final, detalhes, '
            'data_agendada, hora_agendada, tipo_execucao, fk_grupo_empresa, '
            'fk_status, fk_profissional, fk_usuario, fk_endereco, fk_servico_prof, '
            'status!solicitacoes_fk_status_fkey(status)',
          );
      if (_contaEmpresaAtiva) {
        if (idGrupo == null) {
          if (mounted) {
            setState(() {
              _todas = [];
              _carregando = false;
            });
          }
          return;
        }
        query = query.eq('fk_grupo_empresa', idGrupo);
      } else {
        query = query
            .eq('fk_profissional', idProf)
            .isFilter('fk_grupo_empresa', null);
      }
      final rows = await query.order('data_solicitacao', ascending: false);
      final lista = <SolicitacaoRecebida>[];
      for (final row in rows) {
        lista.add(await _montarSolicitacao(Map<String, dynamic>.from(row)));
      }
      if (mounted) {
        setState(() {
          _todas = lista;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _carregando = false;
        });
      }
    }
  }

  Future<SolicitacaoRecebida> _montarSolicitacao(
    Map<String, dynamic> row,
  ) async {
    final idSolicitacao = (row['id_solicitacao'] as num).toInt();
    final dataSolicitacao =
        DateTime.tryParse(row['data_solicitacao']?.toString() ?? '') ??
        DateTime.now();
    final valorFinal =
        double.tryParse(row['valor_final']?.toString() ?? '0') ?? 0.0;
    final detalhes = row['detalhes']?.toString().trim().isNotEmpty == true
        ? row['detalhes'].toString().trim()
        : null;
    final tipoExecucao =
        row['tipo_execucao']?.toString().trim().isNotEmpty == true
        ? row['tipo_execucao'].toString().trim()
        : 'Serviço';
    final fkGrupo = (row['fk_grupo_empresa'] as num?)?.toInt();
    final fkProf = (row['fk_profissional'] as num?)?.toInt() ?? 0;
    final statusTexto = _extrairStatus(row['status']);
    String nomeCliente = 'Cliente';
    String? fotoCliente;
    String? imagemAnexoUrl;
    try {
      final idCliente = (row['fk_usuario'] as num?)?.toInt();
      if (idCliente != null) {
        final u = await _supabase
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', idCliente)
            .maybeSingle();
        final nome = u?['nome']?.toString().trim() ?? '';
        if (nome.isNotEmpty) nomeCliente = nome;
        final foto = u?['foto_perfil_url']?.toString().trim() ?? '';
        if (foto.isNotEmpty) fotoCliente = foto;
      }
    } catch (_) {}
    try {
      final anexo = await _supabase
          .from('solicitacoes_anexos')
          .select('anexo_url')
          .eq('fk_solicitacao', idSolicitacao)
          .limit(1)
          .maybeSingle();
      final url = anexo?['anexo_url']?.toString().trim() ?? '';
      if (url.isNotEmpty) imagemAnexoUrl = url;
    } catch (_) {}
    String titulo = 'Serviço';
    String? descricao;
    String? imagemUrl;
    String? funcao;
    String? corOficio;
    try {
      final idServ = (row['fk_servico_prof'] as num?)?.toInt();
      if (idServ != null) {
        final s = await _supabase
            .from('servicos_profissional')
            .select('titulo, descricao, imagem_url, oficios(funcao, cor)')
            .eq('id_servico_prof', idServ)
            .maybeSingle();
        if (s != null) {
          final t = s['titulo']?.toString().trim() ?? '';
          if (t.isNotEmpty) titulo = t;
          final d = s['descricao']?.toString().trim() ?? '';
          if (d.isNotEmpty) descricao = d;
          final img = s['imagem_url']?.toString().trim() ?? '';
          if (img.isNotEmpty) imagemUrl = img;
          final dynamic ofRaw = s['oficios'];
          final Map<String, dynamic>? ofMap = ofRaw is Map<String, dynamic>
              ? ofRaw
              : (ofRaw is List && ofRaw.isNotEmpty
                    ? Map<String, dynamic>.from(ofRaw.first as Map)
                    : null);
          if (ofMap != null) {
            final info = OficioInfo.fromMap(ofMap);
            if (info.funcao.isNotEmpty) funcao = info.funcao;
            corOficio = info.cor;
          }
        }
      }
    } catch (_) {}
    return SolicitacaoRecebida(
      idSolicitacao: idSolicitacao,
      dataSolicitacao: dataSolicitacao.toLocal(),
      valorFinal: valorFinal,
      detalhes: detalhes,
      dataAgendada: row['data_agendada']?.toString(),
      horaAgendada: row['hora_agendada']?.toString(),
      tipoExecucao: tipoExecucao,
      fkGrupoEmpresa: fkGrupo,
      fkProfissional: fkProf,
      fkUsuario: (row['fk_usuario'] as num?)?.toInt(),
      fkEndereco: (row['fk_endereco'] as num?)?.toInt(),
      statusTexto: statusTexto,
      nomeCliente: nomeCliente,
      fotoCliente: fotoCliente,
      imagemAnexoUrl: imagemAnexoUrl,
      tituloServico: titulo,
      descricaoServico: descricao,
      imagemServicoUrl: imagemUrl,
      funcao: funcao,
      corOficio: corOficio,
    );
  }

  String? _extrairStatus(dynamic statusRaw) {
    if (statusRaw is Map) return statusRaw['status']?.toString();
    if (statusRaw is List && statusRaw.isNotEmpty) {
      final primeiro = statusRaw.first;
      if (primeiro is Map) return primeiro['status']?.toString();
      return primeiro?.toString();
    }
    final texto = statusRaw?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  List<SolicitacaoRecebida> get _filtradas {
    final aceitos = _todas.where((item) => _ehAceita(item)).toList();
    final abertos = _todas.where(_ehAberta).toList();
    if (_filtro == FiltroSolicitacao.novos) {
      return [...aceitos, ...abertos.where((item) => !aceitos.contains(item))];
    }

    return _todas
        .where((s) => FiltroSolicitacao.porStatus(s.statusTexto) == _filtro)
        .toList();
  }

  int get _quantidadeAceitosTodos =>
      _todas.where((item) => _ehAceita(item)).length;

  bool _ehAceita(SolicitacaoRecebida item) =>
      FiltroSolicitacao.porStatus(item.statusTexto) ==
      FiltroSolicitacao.aceitos;

  bool _ehAberta(SolicitacaoRecebida item) {
    final status = FiltroSolicitacao.porStatus(item.statusTexto);
    return status == FiltroSolicitacao.novos || status == null;
  }

  int _contar(FiltroSolicitacao filtro) {
    if (filtro == FiltroSolicitacao.novos) {
      return _todas.where((item) => _ehAceita(item) || _ehAberta(item)).length;
    }
    return _todas
        .where((s) => FiltroSolicitacao.porStatus(s.statusTexto) == filtro)
        .length;
  }

  bool _podeIniciarDeslocamento(SolicitacaoRecebida item) {
    final tipo = item.tipoExecucao
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a');
    return (tipo.contains('leva') && tipo.contains('traz')) ||
        tipo.contains('domicilio');
  }

  void _abrirChat(SolicitacaoRecebida item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: item.nomeCliente,
          fotoProfissional: item.fotoCliente ?? '',
          oficioPrincipal: item.funcao ?? item.tituloServico,
          idProfissional: item.fkGrupoEmpresa == null
              ? item.fkProfissional
              : null,
          idGrupoEmpresa: item.fkGrupoEmpresa,
        ),
      ),
    );
  }

  String _rotuloDataSolicitacao(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(data.year, data.month, data.day);
    final hora =
        '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    final diff = hoje.difference(dia).inDays;
    if (diff == 0) return 'Hoje, $hora';
    if (diff == 1) return 'Ontem';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String _formatarAgendada(String? data, String? hora) {
    if ((data ?? '').isEmpty) return '';
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    try {
      final partes = data!.split('-');
      if (partes.length == 3) {
        final dia = int.tryParse(partes[2]) ?? 1;
        final mes = int.tryParse(partes[1]) ?? 1;
        var horaFmt = '';
        if ((hora ?? '').isNotEmpty) {
          final ph = hora!.split(':');
          if (ph.length >= 2) horaFmt = '\n${ph[0]}:${ph[1]}';
        }
        return '$dia de ${meses[(mes - 1).clamp(0, 11)]},$horaFmt';
      }
    } catch (_) {}
    return data!;
  }

  String _formatarPreco(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  IconData _iconeMetodo(String tipo) {
    final limpo = tipo.trim().toLowerCase();
    if (limpo.contains('leva') || limpo.contains('traz')) {
      return Icons.local_shipping_outlined;
    } else if (limpo.contains('retirad') || limpo.contains('local')) {
      return Icons.storefront_outlined;
    } else if (limpo.contains('receba') || limpo.contains('casa')) {
      return Icons.home_outlined;
    } else if (limpo.contains('domic')) {
      return Icons.home_repair_service_outlined;
    }
    return Icons.handyman_outlined;
  }

  Widget _buildConfirmacaoRecusaSheet() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recusar solicitação?',
              style: TextStyle(
                color: _textoEscuro,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta solicitação será marcada como recusada e não aparecerá mais na aba Novos.',
              style: TextStyle(color: _textoMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sim, recusar solicitação',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textoEscuro,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recusar(SolicitacaoRecebida item) async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildConfirmacaoRecusaSheet(),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _supabase.rpc(
        'recusar_solicitacao',
        params: {
          'p_id_solicitacao': item.idSolicitacao,
          'p_id_profissional': item.fkProfissional,
        },
      );
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação atualizada.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _aceitar(SolicitacaoRecebida item) async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildConfirmacaoAceiteSheet(item),
    );
    if (confirmar != true || !mounted) return;
    try {
      await SolicitacoesService.aceitar(
        idSolicitacao: item.idSolicitacao,
        idProfissional: item.fkProfissional,
      );
      await _garantirStatusAceito(item.idSolicitacao);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SolicitacaoAceitaPage(solicitacao: item),
        ),
      );
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aceitar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildConfirmacaoAceiteSheet(SolicitacaoRecebida item) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _azul.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: _azul, size: 29),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aceitar pedido?',
              style: TextStyle(
                color: _textoEscuro,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Você aceitará o serviço "${item.tituloServico}" para '
              '${item.nomeCliente}.',
              style: const TextStyle(
                color: _textoMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sim, aceitar pedido',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textoEscuro,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSolicitacaoAceita(SolicitacaoRecebida item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolicitacaoAceitaPage(solicitacao: item),
      ),
    );
  }

  Future<void> _garantirStatusAceito(int idSolicitacao) async {
    final status = await _supabase
        .from('status')
        .select('id_status')
        .eq('tipo_status', 'Serviço')
        .eq('status', 'Aceito')
        .limit(1)
        .maybeSingle();
    final idStatus = (status?['id_status'] as num?)?.toInt();
    if (idStatus == null) {
      throw Exception(
        'Status Aceito ausente. Execute o SQL de status do serviço.',
      );
    }
    await _supabase
        .from('solicitacoes')
        .update({'fk_status': idStatus})
        .eq('id_solicitacao', idSolicitacao);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            _buildHeader(),
            _buildFiltros(),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: _azul))
                  : _erro != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _erro!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _textoMuted),
                        ),
                      ),
                    )
                  : _filtradas.isEmpty
                  ? _buildListaVazia()
                  : RefreshIndicator(
                      color: _azul,
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                        itemCount:
                            _filtro == FiltroSolicitacao.novos &&
                                _quantidadeAceitosTodos > 0 &&
                                _filtradas.length > _quantidadeAceitosTodos
                            ? _filtradas.length + 1
                            : _filtradas.length,
                        itemBuilder: (context, index) {
                          final temDivisoria =
                              _filtro == FiltroSolicitacao.novos &&
                              _quantidadeAceitosTodos > 0 &&
                              _filtradas.length > _quantidadeAceitosTodos;
                          if (temDivisoria &&
                              index == _quantidadeAceitosTodos) {
                            return _buildDivisoriaNovos();
                          }
                          final indiceCard =
                              temDivisoria && index > _quantidadeAceitosTodos
                              ? index - 1
                              : index;
                          return _buildCard(_filtradas[indiceCard]);
                        },
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBarProfissional(
          key: const ValueKey('bottomProfissional'),
          currentIndex: 3,
          // Sem prop isContaEmpresa: resolve pelo cache interno, igual às
          // demais telas — sem piscar Perfil/Empresa.
          onReselecionarAbaAtual: (_) => _carregar(),
          onTap: (index) {
            if (index == 3) {
              _carregar();
              return;
            }
            if (index == 0) {
              AppNavigationUtil.navegarAba(
                context,
                const TelaHomeProfissional(isVisitante: false),
                isHome: true,
              );
              return;
            }
            if (index == 2) {
              AppNavigationUtil.navegarAba(
                context,
                const TelaMensagensPage(
                  isVisitante: false,
                  isProfissional: true,
                ),
                isHome: false,
              );
              return;
            }
            if (index == 4) {
              // 5º botão: conta empresa -> "Empresa" (gestão), senão "Perfil".
              // Cache síncrono, igual às demais telas.
              final ehEmpresa =
                  BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
              if (ehEmpresa) {
                // Conta empresa: 5º item é "Empresa" -> abre a gestão.
                Navigator.of(context).push(
                  AppNavigationUtil.rotaSemAnimacao(
                    const GestaoEquipePage(),
                    nome: 'GestaoEquipePage',
                  ),
                );
              } else {
                AppNavigationUtil.navegarAba(
                  context,
                  const TelaMeuPerfilProfissionalPage(isVisitante: false),
                  isHome: false,
                );
              }
              return;
            }
            // Radar (1): volta para a home.
            AppNavigationUtil.navegarAba(
              context,
              const TelaHomeProfissional(isVisitante: false),
              isHome: true,
            );
          },
        ),
      ),
    );
  }

  // (Removido: método local TextStyle sombreava o do Flutter.)

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
          child: const Row(
            children: [
              BackButton(color: _azul),
              Expanded(
                child: Text(
                  'Serviços Solicitados',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _azul,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: null,
                icon: Icon(Icons.more_vert, color: Color(0xFFCBD5E1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: FiltroSolicitacao.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filtro = FiltroSolicitacao.values[index];
            final ativo = _filtro == filtro;
            final total = _contar(filtro);
            return GestureDetector(
              onTap: () => setState(() => _filtro = filtro),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ativo ? _azul.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ativo ? _azul : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filtro.rotulo,
                      style: TextStyle(
                        color: ativo ? _azul : _textoMuted,
                        fontSize: 13,
                        fontWeight: ativo ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    if (filtro == FiltroSolicitacao.novos && total > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _azul,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListaVazia() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'Você ainda não possui solicitações de serviços',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textoEscuro,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivisoriaNovos() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'SOLICITAÇÕES EM ABERTO',
              style: TextStyle(
                color: _textoMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildCard(SolicitacaoRecebida item) {
    if (_filtro == FiltroSolicitacao.novos && _ehAceita(item)) {
      return GestureDetector(
        onTap: () => _abrirSolicitacaoAceita(item),
        child: _buildCardAceito(item),
      );
    }
    final corBase = CorOficio.parse(item.corOficio);
    final descricao = item.detalhes?.isNotEmpty == true
        ? item.detalhes!
        : (item.descricaoServico ?? '');
    final agendada = _formatarAgendada(item.dataAgendada, item.horaAgendada);
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatarCliente(item),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nomeCliente,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _textoEscuro,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.funcao?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: CorOficio.corFundo(corBase),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.funcao!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: CorOficio.corTexto(corBase),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _rotuloDataSolicitacao(item.dataSolicitacao),
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textoMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ImagemServico(
                imagemUrl: item.imagemServicoUrl,
                funcao: item.funcao,
                cor: item.corOficio,
                height: 150,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.tituloServico,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _azul,
              ),
            ),
            if (descricao.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                descricao,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textoMuted,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            _buildLinhaAgendada(agendada),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, color: _azul, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Preço médio: ${_formatarPreco(item.valorFinal)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textoEscuro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_iconeMetodo(item.tipoExecucao), color: _azul, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.tipoExecucao,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _azul,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_filtro == FiltroSolicitacao.novos)
              _buildBotoes(item)
            else if (_filtro == FiltroSolicitacao.aceitos)
              _buildBotoesAceito(item),
          ],
        ),
      ),
    );
    if (_filtro == FiltroSolicitacao.aceitos && _ehAceita(item)) {
      return GestureDetector(
        onTap: () => _abrirSolicitacaoAceita(item),
        child: card,
      );
    }
    return card;
  }

  Widget _buildCardAceito(SolicitacaoRecebida item) {
    final descricao = item.detalhes?.isNotEmpty == true
        ? item.detalhes!
        : (item.descricaoServico ?? 'Detalhes não informados.');
    final agendada = _formatarAgendada(item.dataAgendada, item.horaAgendada);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _azul, width: 2),
        boxShadow: [
          BoxShadow(
            color: _azul.withValues(alpha: .12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _azul.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '●  SERVIÇO ACEITO • EM ANDAMENTO',
              style: TextStyle(
                color: _azul,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildAvatarCliente(item),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nomeCliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textoEscuro,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.funcao?.isNotEmpty == true)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.funcao!,
                          style: const TextStyle(
                            color: Color(0xFF8A5A00),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatarPreco(item.valorFinal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: _azul.withValues(alpha: .28)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tituloServico,
                  style: const TextStyle(
                    color: Color(0xFF073B78),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  descricao,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textoMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImagemServicoAceito(item),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: _azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agendada.isEmpty ? 'Agendamento não informado' : agendada,
                  style: const TextStyle(
                    color: _textoEscuro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: _azul),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Valor acordado e pagamento garantido no app',
                  style: TextStyle(color: _azul, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_podeIniciarDeslocamento(item))
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Iniciar deslocamento'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              if (_podeIniciarDeslocamento(item)) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _abrirChat(item),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Mensagem'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textoEscuro,
                    side: const BorderSide(color: Color(0xFFB8C2D1)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinhaAgendada(String agendada) {
    const textoDistancia = Text(
      '2.5 km de você',
      style: TextStyle(fontSize: 12, color: _textoMuted),
    );
    if (agendada.isEmpty) {
      return const Row(
        children: [
          Spacer(),
          Icon(Icons.location_on_outlined, color: _azul, size: 20),
          SizedBox(width: 4),
          textoDistancia,
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.calendar_month_outlined, color: _azul, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            agendada,
            style: const TextStyle(
              fontSize: 13,
              color: _textoEscuro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(Icons.location_on_outlined, color: _azul, size: 20),
        const SizedBox(width: 4),
        textoDistancia,
      ],
    );
  }

  Widget _buildBotoes(SolicitacaoRecebida item) {
    Widget aceitar = SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _aceitar(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: _azul,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Text(
          'Aceitar Pedido',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
    Widget recusarOuDetalhes = SizedBox(
      height: 44,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _filtro == FiltroSolicitacao.novos
            ? () => _recusar(item)
            : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: _azul,
          side: const BorderSide(color: _azul),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Text(
          _filtro == FiltroSolicitacao.novos ? 'Recusar' : 'Ver Detalhes',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: aceitar),
        const SizedBox(width: 10),
        Expanded(child: recusarOuDetalhes),
      ],
    );
  }

  Widget _buildBotoesAceito(SolicitacaoRecebida item) {
    final podeDeslocar = _podeIniciarDeslocamento(item);
    return Row(
      children: [
        if (podeDeslocar)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Iniciar deslocamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (podeDeslocar) const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _abrirChat(item),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Mensagem'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textoEscuro,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagemServicoAceito(SolicitacaoRecebida item) {
    final anexo = item.imagemAnexoUrl?.trim() ?? '';
    if (anexo.isNotEmpty) {
      return Image.network(
        anexo,
        width: double.infinity,
        height: 130,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagemServicoFallback(item),
      );
    }
    return _imagemServicoFallback(item);
  }

  Widget _imagemServicoFallback(SolicitacaoRecebida item) {
    return SizedBox(
      width: double.infinity,
      height: 130,
      child: ImagemServico(
        imagemUrl: item.imagemServicoUrl,
        funcao: item.funcao,
        cor: item.corOficio,
        height: 130,
      ),
    );
  }

  Widget _buildAvatarCliente(SolicitacaoRecebida item) {
    final foto = item.fotoCliente?.trim() ?? '';
    if (foto.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          foto,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarIniciais(item.nomeCliente),
        ),
      );
    }
    return _avatarIniciais(item.nomeCliente);
  }

  Widget _avatarIniciais(String nome) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
      child: Text(
        obterIniciais(nome),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
