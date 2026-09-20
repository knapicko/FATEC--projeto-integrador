import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/servico_catalogo.dart';
import 'models/metodo_entrega.dart';
import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// ── Helpers ────────────────────────────────────────────────────────────────
Color _hexToColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF1D2430);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tela Principal: Adicionar/Gerenciar Serviços
// ═══════════════════════════════════════════════════════════════════════════
class AdicionarServicoProfissionalPage extends StatefulWidget {
  /// Quando fornecido, abre diretamente o formulário em modo de edição.
  final ServicoProfissional? servicoParaEditar;

  /// Quando fornecido (via catálogo), pré-preenche o formulário com os
  /// dados do serviço padrão.
  final ServicoCatalogo? sugestao;
  final int? idGrupoEmpresaInicial;
  final bool associacaoEmpresaInicial;
  final bool abrirFormularioInicial;

  /// Quando true, a associação segue a conta ativa e a outra opção fica
  /// desabilitada (cinza, não clicável) no bottom sheet de associação.
  final bool forcarContaAtiva;

  /// Quando true, força o modo "Loja" (empresa) independente da conta ativa.
  /// Usado pelo fluxo gestao_equipe -> adicionar serviço, que deve sempre
  /// criar/editar serviços da empresa (grupo_empresa).
  final bool forcarModoEmpresa;

  const AdicionarServicoProfissionalPage({
    super.key,
    this.servicoParaEditar,
    this.sugestao,
    this.idGrupoEmpresaInicial,
    this.associacaoEmpresaInicial = false,
    this.abrirFormularioInicial = false,
    this.forcarContaAtiva = false,
    this.forcarModoEmpresa = false,
  });

  @override
  State<AdicionarServicoProfissionalPage> createState() =>
      _AdicionarServicoProfissionalPageState();
}

class _AdicionarServicoProfissionalPageState
    extends State<AdicionarServicoProfissionalPage> {
  // Cores
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _deepBlue = Color(0xFF003F87);
  static const Color _softBlue = Color(0xFFEAF9FF);
  static const Color _panel = Color(0xFFF5F8FB);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF1D2A39);
  static const Color _textMuted = Color(0xFF7B8393);
  static const Color _border = Color(0xFFE6ECF2);

  List<ServicoProfissional> _servicosAtivos = [];
  List<ServicoCatalogo> _catalogoFiltrado = [];
  bool _carregando = true;
  int? _idGrupoEmpresa;
  // Conta ativa (mesma flag da home): false = profissional (CNPJ),
  // true = empresa. Resolve no _carregar() junto com o contexto.
  bool _contaEmpresaAtiva = false;

  @override
  void initState() {
    super.initState();
    _carregar().then((_) {
      if (!mounted) return;
      if (widget.abrirFormularioInicial ||
          widget.servicoParaEditar != null ||
          widget.sugestao != null) {
        _abrirFormulario(
          servicoParaEditar: widget.servicoParaEditar,
          sugestao: widget.sugestao,
        );
      }
    });
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final results = await Future.wait([
      ServicosProfissionalService.buscarServicos(),
      ServicosProfissionalService.buscarCatalogo(),
      ServicosProfissionalService.buscarContextoAssociacao(),
      _lerContaEmpresaAtiva(),
    ]);
    final todosServicos = results[0] as List<ServicoProfissional>;
    final catalogo = results[1] as List<ServicoCatalogo>;
    final contexto = results[2]
        as ({
          int idProfissional,
          int? idGrupoEmpresa,
          bool ehLoja,
          bool ehMembroEmpresa,
          bool ehDonoEmpresa,
        })?;
    final contaEmpresa =
        widget.forcarModoEmpresa ? true : (results[3] as bool);
    final idGrupo = widget.idGrupoEmpresaInicial ?? contexto?.idGrupoEmpresa;

    // Distinção pela CONTA ATIVA:
    // - empresa: SÓ serviços com fk_grupo_empresa do grupo.
    // - profissional: SÓ serviços individuais (fk_grupo_empresa == null).
    final servicos = contaEmpresa
        ? todosServicos
            .where((s) =>
                s.fkGrupoEmpresa != null && s.fkGrupoEmpresa == idGrupo)
            .toList()
        : todosServicos.where((s) => s.fkGrupoEmpresa == null).toList();

    // Ofícios da conta ativa (para filtrar as sugestões pelo mesmo ofício).
    Set<int> oficiosConta = {};
    if (contaEmpresa) {
      if (idGrupo != null) {
        final funcoes =
            await ServicosProfissionalService.buscarFuncoesDaEmpresa(idGrupo);
        oficiosConta = funcoes.map((f) => f.id).toSet();
      }
    } else {
      final funcoes =
          await ServicosProfissionalService.buscarFuncoesDoProfissional();
      oficiosConta = funcoes.map((f) => f.id).toSet();
    }

    if (mounted) {
      setState(() {
        _contaEmpresaAtiva = contaEmpresa;
        _idGrupoEmpresa = idGrupo;
        _servicosAtivos = servicos;
        // Sugestões: só as que têm o mesmo ofício da conta ativa.
        // Se a conta não tem ofício cadastrado, mostra o catálogo cheio
        // (evita tela vazia) — ajuste aqui para [] se preferir esconder.
        _catalogoFiltrado = oficiosConta.isEmpty
            ? catalogo
            : catalogo.where((c) => oficiosConta.contains(c.fkOficio)).toList();
        _carregando = false;
      });
    }
  }

  static const String _prefContaAtivaKey = 'consertaja_conta_empresa_ativa';

  Future<bool> _lerContaEmpresaAtiva() async {
    final doCache =
        BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return doCache;
      final prefs = await SharedPreferences.getInstance();
      final ativa = prefs.getBool('${_prefContaAtivaKey}_${user.id}');
      if (ativa == null) return doCache;
      BottomNavigationBarProfissional.notificarTrocaConta(ativa);
      return ativa;
    } catch (_) {
      return doCache;
    }
  }

  /// Abre o bottom sheet do formulário de criação/edição.
  Future<void> _abrirFormulario({
    ServicoProfissional? servicoParaEditar,
    ServicoCatalogo? sugestao,
  }) async {
    // A associação padrão segue a conta ativa (não o parâmetro solto).
    // Na EDIÇÃO, mantém a associação original do serviço (não troca o dono).
    // Fluxo gestão da equipe (forcarModoEmpresa): sempre "Loja".
    final contaAtivaEfetiva =
        widget.forcarModoEmpresa ? true : _contaEmpresaAtiva;
    final travadoEfetivo =
        widget.forcarContaAtiva || widget.forcarModoEmpresa;
    final associacaoPadrao = servicoParaEditar != null
        ? servicoParaEditar.fkGrupoEmpresa != null
        : (travadoEfetivo
            ? contaAtivaEfetiva
            : widget.associacaoEmpresaInicial);
    final mudou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormularioServicoSheet(
        servicoParaEditar: servicoParaEditar,
        sugestao: sugestao,
        idGrupoEmpresa: widget.idGrupoEmpresaInicial ?? _idGrupoEmpresa,
        associacaoEmpresaInicial: associacaoPadrao,
        // Trava na conta ativa: a outra opção aparece cinza/desabilitada.
        travadaNaContaAtiva: travadoEfetivo,
        contaEmpresaAtiva: contaAtivaEfetiva,
      ),
    );
    if (mudou == true) {
      await _carregar();
      if (mounted) {
        Navigator.of(context).pop(true); // retorna para meus_servicos
      }
    }
  }

  Future<void> _confirmarExclusao(ServicoProfissional s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover serviço?'),
        content: Text('Deseja remover "${s.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final deletou = await ServicosProfissionalService.deletarServico(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletou ? 'Serviço removido.' : 'Erro ao remover serviço.',
            ),
            backgroundColor: deletou ? Colors.green : Colors.red,
          ),
        );
        if (deletou) _carregar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panel,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: _panel,
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _primaryBlue,
                      size: 22,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Adicionar Serviço',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _carregar,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _primaryBlue,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── Conteúdo ──────────────────────────────────────────────────
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryBlue),
                    )
                  : RefreshIndicator(
                      color: _primaryBlue,
                      onRefresh: _carregar,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          // ── Seção 1: Serviços Oferecidos ───────────────
                          _buildSecaoAtivos(),

                          const SizedBox(height: 28),

                          // ── Seção 2: Sugestões do Catálogo ─────────────
                          if (_catalogoFiltrado.isNotEmpty) ...[
                            _buildSecaoSugestoes(),
                            const SizedBox(height: 28),
                          ],

                          // ── Seção 3: Criar serviço personalizado ───────
                          _buildCardPersonalizado(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seção 1: Serviços já oferecidos ──────────────────────────────────────
  Widget _buildSecaoAtivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho
        Row(
          children: [
            const Text(
              'Serviços Oferecidos',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_servicosAtivos.length} Ativo${_servicosAtivos.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Color(0xFF6C7783),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_servicosAtivos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.home_repair_service_outlined,
                  color: Color(0xFF9AA4B2),
                  size: 36,
                ),
                SizedBox(height: 10),
                Text(
                  'Nenhum serviço cadastrado ainda.',
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...List.generate(_servicosAtivos.length, (i) {
            final s = _servicosAtivos[i];
            return _buildCardServicoAtivo(s);
          }),
      ],
    );
  }

  Widget _buildCardServicoAtivo(ServicoProfissional s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: s.imagemUrl != null && s.imagemUrl!.isNotEmpty
                ? Image.network(
                    s.imagemUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => _placeholderImg(72),
                  )
                : _placeholderImg(72),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${s.valor.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Botão editar
          GestureDetector(
            onTap: () => _abrirFormulario(servicoParaEditar: s),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: _primaryBlue,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botão deletar
          GestureDetector(
            onTap: () => _confirmarExclusao(s),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seção 2: Sugestões do Catálogo ───────────────────────────────────────
  // Mostra SÓ sugestões do mesmo ofício da conta ativa
  // (filtradas em _catalogoFiltrado no _carregar).
  Widget _buildSecaoSugestoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sugestões para Você',
          style: TextStyle(
            color: _textDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Serviços com alta demanda na sua região',
          style: TextStyle(color: _textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _catalogoFiltrado.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) => _buildCardCatalogo(_catalogoFiltrado[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCardCatalogo(ServicoCatalogo item) {
    final catColor = _hexToColor(item.cor ?? '#1D2430');
    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: item.imagemUrl != null && item.imagemUrl!.isNotEmpty
                ? Image.network(
                    item.imagemUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) =>
                        _placeholderImgCor(100, catColor),
                  )
                : _placeholderImgCor(100, catColor),
          ),

          // Badge categoria
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.funcao ?? item.titulo,
                style: TextStyle(
                  color: catColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 2),
            child: Text(
              item.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Descrição
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: Text(
              item.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),

          const Spacer(),

          // Botão + Adicionar
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton(
                onPressed: () => _abrirFormulario(sugestao: item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _softBlue,
                  foregroundColor: _primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  '+ Adicionar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seção 3: Criar serviço personalizado ─────────────────────────────────
  Widget _buildCardPersonalizado() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      decoration: BoxDecoration(
        color: _deepBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.build_circle_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Criar Serviço Personalizado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Não encontrou o que precisava? Crie um serviço do zero, com seu próprio nome e preço.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCAD9EF),
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => _abrirFormulario(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _deepBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: const Text(
                'Criar Novo Serviço',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _placeholderImg(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFEAF9FF),
      child: const Icon(
        Icons.home_repair_service_rounded,
        color: Color(0xFF0FB3FF),
        size: 28,
      ),
    );
  }

  Widget _placeholderImgCor(double height, Color cor) {
    return Container(
      height: height,
      width: double.infinity,
      color: cor.withValues(alpha: 0.1),
      child: Icon(
        Icons.home_repair_service_rounded,
        color: cor.withValues(alpha: 0.6),
        size: 32,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom Sheet: Formulário de Criação / Edição
// ═══════════════════════════════════════════════════════════════════════════
class _FormularioServicoSheet extends StatefulWidget {
  final ServicoProfissional? servicoParaEditar;
  final ServicoCatalogo? sugestao;
  final int? idGrupoEmpresa;
  final bool associacaoEmpresaInicial;

  /// Quando true, a associação fica travada na conta ativa: o bottom sheet
  /// de associação mostra as 2 opções, mas a que não bate com a conta
  /// logada fica cinza e não pode ser escolhida.
  final bool travadaNaContaAtiva;

  /// Conta ativa no momento da abertura (true = empresa).
  final bool contaEmpresaAtiva;

  const _FormularioServicoSheet({
    this.servicoParaEditar,
    this.sugestao,
    this.idGrupoEmpresa,
    this.associacaoEmpresaInicial = false,
    this.travadaNaContaAtiva = false,
    this.contaEmpresaAtiva = false,
  });

  @override
  State<_FormularioServicoSheet> createState() =>
      _FormularioServicoSheetState();
}

class _FormularioServicoSheetState extends State<_FormularioServicoSheet> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _deepBlue = Color(0xFF003F87);
  static const Color _textDark = Color(0xFF1D2A39);
  static const Color _textMuted = Color(0xFF7B8393);
  static const Color _border = Color(0xFFE6ECF2);

  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _valorNumericoCtrl = TextEditingController();

  String _categoriaSelecionada = '';
  String _categoriaCor = '#1D2430';
  final Set<String> _tiposExecucaoSelecionados = <String>{};
  String _cargaServico = 'Médio';
  int? _fkOficioSelecionado;
  bool _salvando = false;
  late bool _associacaoEmpresa;
  int? _fkGrupoEmpresa;

  /// Controla se o usuário tentou salvar (para mostrar erro na categoria).
  bool _tentouSalvar = false;

  /// Lista de ofícios (categorias) carregada do banco.
  List<({int id, String funcao, String cor})> _oficios = [];
  bool _carregandoOficios = true;
  List<MetodoEntregaOpcao> _metodosEntregaDisponiveis = [];
  bool _carregandoMetodosEntrega = true;

  /// URL já salva no banco (edição)
  String? _imagemUrlExistente;

  /// Arquivo local novo selecionado pelo usuário
  XFile? _imagemLocalNova;

  bool get _modoEdicao => widget.servicoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final s = widget.servicoParaEditar;
    final sug = widget.sugestao;
    _associacaoEmpresa = widget.associacaoEmpresaInicial;
    _fkGrupoEmpresa = widget.idGrupoEmpresa;

    // Travado na conta ativa: força o default da conta logada
    // (empresa => Empresa; profissional => Conta profissional).
    if (widget.travadaNaContaAtiva && s == null) {
      _associacaoEmpresa = widget.contaEmpresaAtiva;
    }

    if (s != null) {
      // Modo edição: pré-preenche com dados existentes
      _tituloCtrl.text = s.titulo;
      _descricaoCtrl.text = s.descricao;
      _valorNumericoCtrl.text = s.valor.toStringAsFixed(2);
      _categoriaSelecionada = s.funcao ?? '';
      _categoriaCor = s.cor ?? '#1D2430';
      _fkOficioSelecionado = s.fkOficio;
      _imagemUrlExistente = s.imagemUrl;
      _cargaServico = s.cargaServico;
      _fkGrupoEmpresa = s.fkGrupoEmpresa;
      _associacaoEmpresa = s.fkGrupoEmpresa != null;
    } else if (sug != null) {
      // Modo sugestão: pré-preenche com dados do catálogo
      _tituloCtrl.text = sug.titulo;
      _descricaoCtrl.text = sug.descricao;
      _categoriaSelecionada = sug.funcao ?? '';
      _categoriaCor = sug.cor ?? '#1D2430';
      _fkOficioSelecionado = sug.fkOficio;
      _imagemUrlExistente = sug.imagemUrl;
    }
    // Carrega as funções da associação inicialmente selecionada.
    _carregarOficios();
    _carregarMetodosEntrega();
  }

  Future<void> _carregarMetodosEntrega() async {
    if (mounted) setState(() => _carregandoMetodosEntrega = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregandoMetodosEntrega = false);
        return;
      }

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final usuarioId = (usuario?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) {
        if (mounted) setState(() => _carregandoMetodosEntrega = false);
        return;
      }

      // Associação Empresa => puxa grupo_empresa.metodo_entrega_empresa;
      // associação Profissional => puxa dados_profissionais.metodo_entrega.
      // Default (vazio/sem linha/sem coluna) = 'Leva e Traz'.
      List<String> valoresSalvos = <String>[];
      if (_associacaoEmpresa) {
        final idGrupo = _fkGrupoEmpresa ?? await _buscarIdGrupoDoUsuario(usuarioId);
        if (idGrupo != null) {
          if (mounted && _fkGrupoEmpresa == null) {
            setState(() => _fkGrupoEmpresa = idGrupo);
          }
          try {
            final grupo = await supabase
                .from('grupo_empresa')
                .select('metodo_entrega_empresa')
                .eq('id_grupo_empresa', idGrupo)
                .maybeSingle();
            valoresSalvos = _separarValores(grupo?['metodo_entrega_empresa']);
          } catch (_) {
            // Banco ainda sem a migration: sem valores da empresa.
            valoresSalvos = <String>[];
          }
        }
      } else {
        final dados = await supabase
            .from('dados_profissionais')
            .select('metodo_entrega')
            .eq('fk_usuario', usuarioId)
            .maybeSingle();
        valoresSalvos = _separarValores(dados?['metodo_entrega']);
      }
      if (valoresSalvos.isEmpty) valoresSalvos = <String>['Leva e Traz'];
      final disponiveis = metodosEntregaOpcoes
          .where((opcao) => valoresSalvos.contains(opcao.valor))
          .toList();

      if (mounted) {
        setState(() {
          _metodosEntregaDisponiveis = disponiveis;
          _tiposExecucaoSelecionados
            ..clear()
            ..addAll(
              _separarValores(widget.servicoParaEditar?.tipoExecucao).where(
                valoresSalvos.contains,
              ),
            );
          _carregandoMetodosEntrega = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoMetodosEntrega = false);
    }
  }

  List<String> _separarValores(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return <String>[];
    return raw
        .toString()
        .split(',')
        .map((valor) => valor.trim())
        .where((valor) => valor.isNotEmpty)
        .toList();
  }

  Future<int?> _buscarIdGrupoDoUsuario(int usuarioId) async {
    try {
      final dados = await Supabase.instance.client
          .from('dados_profissionais')
          .select('fk_grupo_empresa')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      return (dados?['fk_grupo_empresa'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  String _tipoExecucaoParaSalvar() {
    return _metodosEntregaDisponiveis
        .where((opcao) => _tiposExecucaoSelecionados.contains(opcao.valor))
        .map((opcao) => opcao.valor)
        .join(', ');
  }

  Future<void> _carregarOficios() async {
    final oficios = await ServicosProfissionalService.buscarFuncoesParaServico(
      associacaoEmpresa: _associacaoEmpresa,
      idGrupoEmpresa: _fkGrupoEmpresa,
    );
    if (mounted) {
      setState(() {
        _oficios = oficios;
        _carregandoOficios = false;
      });
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _valorNumericoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarImagem() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: _primaryBlue,
              ),
              title: const Text('Câmera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: _primaryBlue,
              ),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            if (_imagemLocalNova != null || _imagemUrlExistente != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Remover imagem',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  setState(() {
                    _imagemLocalNova = null;
                    _imagemUrlExistente = null;
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img != null && mounted) {
      setState(() => _imagemLocalNova = img);
    }
  }

  Future<void> _salvar() async {
    setState(() => _tentouSalvar = true);
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaSelecionada.isEmpty) {
      setState(() => _tentouSalvar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma função'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_carregandoMetodosEntrega || _tiposExecucaoSelecionados.isEmpty) {
      setState(() => _tentouSalvar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _carregandoMetodosEntrega
                ? 'Carregando métodos de entrega.'
                : 'Selecione pelo menos um método de entrega.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final oficioPermitido = _oficios.any(
      (oficio) => oficio.id == _fkOficioSelecionado,
    );
    if (!oficioPermitido) {
      setState(() => _tentouSalvar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um ofício associado ao seu perfil.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _salvando = true);

    final valorNum = _valorNumericoCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_valorNumericoCtrl.text.trim().replaceAll(',', '.'));

    final ({bool sucesso, String? erro}) resultado;

    if (_modoEdicao) {
      resultado = await ServicosProfissionalService.atualizarServico(
        id: widget.servicoParaEditar!.id,
        titulo: _tituloCtrl.text,
        descricao: _descricaoCtrl.text,
        valor: valorNum ?? 0,
        fkOficio: _fkOficioSelecionado ?? 0,
        imagemUrl: _imagemUrlExistente,
        imagemLocal: _imagemLocalNova,
        fkGrupoEmpresa: _associacaoEmpresa ? _fkGrupoEmpresa : null,
        tipoExecucao: _tipoExecucaoParaSalvar(),
        cargaServico: _cargaServico,
      );
    } else {
      final r = await ServicosProfissionalService.criarServico(
        titulo: _tituloCtrl.text,
        descricao: _descricaoCtrl.text,
        valor: valorNum ?? 0,
        fkOficio: _fkOficioSelecionado ?? 0,
        imagemUrl: _imagemUrlExistente,
        imagemLocal: _imagemLocalNova,
        fkGrupoEmpresa: _associacaoEmpresa ? _fkGrupoEmpresa : null,
        tipoExecucao: _tipoExecucaoParaSalvar(),
        cargaServico: _cargaServico,
      );
      resultado = (sucesso: r.sucesso, erro: r.erro);
    }

    if (!mounted) return;
    setState(() => _salvando = false);

    if (resultado.sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modoEdicao
                ? 'Serviço atualizado com sucesso!'
                : 'Serviço criado com sucesso!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.erro ?? 'Erro desconhecido.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selecionarAssociacao() async {
    // Travado na conta ativa: mostra as 2 opções, mas a que não bate com
    // a conta logada fica cinza e não pode ser escolhida.
    final travado = widget.travadaNaContaAtiva;
    final contaEmpresa = widget.contaEmpresaAtiva;
    final profissionalBloqueado = travado && contaEmpresa;
    final empresaBloqueada =
        travado && !contaEmpresa || _fkGrupoEmpresa == null;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Associação do serviço',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            if (travado) ...[
              const SizedBox(height: 4),
              Text(
                contaEmpresa
                    ? 'Conta de empresa: o serviço será da empresa.'
                    : 'Conta profissional: o serviço será individual.',
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
            ],
            const SizedBox(height: 8),
            Opacity(
              opacity: profissionalBloqueado ? 0.4 : 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: profissionalBloqueado
                      ? Colors.grey.shade200
                      : const Color(0xFFEAF9FF),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: profissionalBloqueado
                        ? Colors.grey
                        : _primaryBlue,
                  ),
                ),
                title: Text(
                  'Conta profissional',
                  style: TextStyle(
                    color: profissionalBloqueado ? Colors.grey : _textDark,
                  ),
                ),
                subtitle: Text(
                  profissionalBloqueado
                      ? 'Indisponível na conta de empresa.'
                      : 'O serviço ficará visível no seu perfil individual.',
                  style: TextStyle(
                    color: profissionalBloqueado
                        ? Colors.grey
                        : _textMuted,
                  ),
                ),
                trailing: !_associacaoEmpresa
                    ? const Icon(Icons.check_circle, color: _primaryBlue)
                    : null,
                enabled: !profissionalBloqueado,
                onTap: profissionalBloqueado
                    ? null
                    : () {
                        setState(() {
                          _associacaoEmpresa = false;
                        });
                        _carregarOficios();
                        _carregarMetodosEntrega();
                        Navigator.of(ctx).pop();
                      },
              ),
            ),
            Opacity(
              opacity: empresaBloqueada ? 0.4 : 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: empresaBloqueada
                      ? Colors.grey.shade200
                      : const Color(0xFFEAF9FF),
                  child: Icon(
                    Icons.business_outlined,
                    color:
                        empresaBloqueada ? Colors.grey : _primaryBlue,
                  ),
                ),
                title: Text(
                  'Empresa',
                  style: TextStyle(
                    color: empresaBloqueada ? Colors.grey : _textDark,
                  ),
                ),
                subtitle: Text(
                  _fkGrupoEmpresa == null
                      ? 'Nenhuma empresa está associada a este perfil.'
                      : (empresaBloqueada
                          ? 'Indisponível na conta profissional.'
                          : 'O serviço ficará na conta da empresa vinculada ao seu CNPJ.'),
                  style: TextStyle(
                    color:
                        empresaBloqueada ? Colors.grey : _textMuted,
                  ),
                ),
                trailing: _associacaoEmpresa
                    ? const Icon(Icons.check_circle, color: _primaryBlue)
                    : null,
                enabled: !empresaBloqueada,
                onTap: empresaBloqueada
                    ? null
                    : () {
                        setState(() => _associacaoEmpresa = true);
                        _carregarOficios();
                        _carregarMetodosEntrega();
                        Navigator.of(ctx).pop();
                      },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _selecionarCategoria() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecionar Função',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D2A39),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: _carregandoOficios
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _oficios.length,
                    itemBuilder: (ctx2, i) {
                      final cat = _oficios[i];
                      final sel = cat.funcao == _categoriaSelecionada;
                      final cor = _hexToColor(cat.cor);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: cor.withValues(alpha: 0.15),
                          child: Icon(Icons.circle, color: cor, size: 12),
                        ),
                        title: Text(
                          cat.funcao,
                          style: TextStyle(
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? cor : const Color(0xFF1D2A39),
                          ),
                        ),
                        trailing: sel
                            ? Icon(Icons.check_circle, color: cor)
                            : null,
                        onTap: () {
                          setState(() {
                            _categoriaSelecionada = cat.funcao;
                            _categoriaCor = cat.cor;
                            _fkOficioSelecionado = cat.id;
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Título do sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  _modoEdicao ? 'Editar Serviço' : 'Novo Serviço',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          const Divider(height: 1),

          // Formulário scrollável
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  // ── Picker de imagem ─────────────────────────────────
                  _buildLabel('Foto do Serviço'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selecionarImagem,
                    child: _buildImagemPicker(),
                  ),
                  const SizedBox(height: 18),

                  // ── Título ───────────────────────────────────────────
                  _buildLabel('Título *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _tituloCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDec(
                      hint: 'Ex: Instalação de Ar Condicionado',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o título'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Categoria ────────────────────────────────────────
                  _buildLabel('Função *'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _selecionarCategoria,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _tentouSalvar && _categoriaSelecionada.isEmpty
                              ? Colors.red
                              : _border,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: _hexToColor(_categoriaCor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _categoriaSelecionada.isEmpty
                                  ? 'Selecione uma função'
                                  : _categoriaSelecionada,
                              style: TextStyle(
                                color: _categoriaSelecionada.isEmpty
                                    ? _textMuted
                                    : _textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_tentouSalvar && _categoriaSelecionada.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Selecione uma função',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),

                  _buildTipoExecucao(),
                  const SizedBox(height: 16),

                  _buildLabel('Carga do serviço *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _cargaServico,
                    decoration: _inputDec(hint: 'Selecione a carga'),
                    items: const [
                      DropdownMenuItem(value: 'Leve', child: Text('Leve')),
                      DropdownMenuItem(value: 'Médio', child: Text('Médio')),
                      DropdownMenuItem(value: 'Alto', child: Text('Alto')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _cargaServico = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Descrição ────────────────────────────────────────
                  _buildLabel('Descrição *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descricaoCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDec(
                      hint: 'Descreva o serviço, materiais, prazo...',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe a descrição'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Associação *'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _selecionarAssociacao,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _associacaoEmpresa
                                ? Icons.business_outlined
                                : Icons.person_outline_rounded,
                            color: _primaryBlue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _associacaoEmpresa
                                  ? 'Empresa'
                                  : 'Conta profissional',
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Valor mínimo ─────────────────────────────────────
                  _buildLabel('Valor mínimo (R\$) *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _valorNumericoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: _inputDec(hint: '150,00'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe o valor mínimo';
                      }
                      final valor = double.tryParse(
                        v.trim().replaceAll(',', '.'),
                      );
                      if (valor == null || valor <= 0) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── Botão salvar ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deepBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _deepBlue.withValues(
                          alpha: 0.5,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _modoEdicao
                                  ? 'Salvar Alterações'
                                  : 'Criar Serviço',
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
        ],
      ),
    );
  }

  Widget _buildImagemPicker() {
    final temImagem =
        _imagemLocalNova != null || (_imagemUrlExistente?.isNotEmpty == true);

    if (!temImagem) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD0DBE9),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: _primaryBlue,
              size: 40,
            ),
            SizedBox(height: 10),
            Text(
              'Toque para adicionar uma foto',
              style: TextStyle(
                color: _textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Câmera ou galeria',
              style: TextStyle(color: Color(0xFFB0BAC9), fontSize: 11),
            ),
          ],
        ),
      );
    }

    // Decide qual imagem exibir
    Widget imagem;
    if (_imagemLocalNova != null) {
      // Para mobile usamos Image.file; na web Image.network com o path
      if (kIsWeb) {
        imagem = Image.network(
          _imagemLocalNova!.path,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (ctx, e, st) =>
              Container(height: 160, color: const Color(0xFFEAF9FF)),
        );
      } else {
        imagem = Image.file(
          File(_imagemLocalNova!.path),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
    } else {
      imagem = Image.network(
        _imagemUrlExistente!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (ctx, e, st) => Container(
          height: 160,
          color: const Color(0xFFEAF9FF),
          child: const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFF0FB3FF),
            size: 40,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: imagem),
        Positioned(
          right: 10,
          bottom: 10,
          child: GestureDetector(
            onTap: _selecionarImagem,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildLabel(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: _textDark,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTipoExecucao() {
    if (_carregandoMetodosEntrega) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_metodosEntregaDisponiveis.isEmpty) {
      return const Text(
        'Nenhum método de entrega foi configurado no perfil.',
        style: TextStyle(color: _textMuted, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Tipo de execução *'),
        const SizedBox(height: 6),
        ..._metodosEntregaDisponiveis.map((opcao) {
          final selecionado = _tiposExecucaoSelecionados.contains(opcao.valor);
          return Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: selecionado,
              fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return _primaryBlue;
                }
                return null;
              }),
              checkColor: Colors.white,
              onChanged: (marcado) {
                setState(() {
                  if (marcado == true) {
                    _tiposExecucaoSelecionados.add(opcao.valor);
                  } else {
                    _tiposExecucaoSelecionados.remove(opcao.valor);
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Icon(opcao.icone, color: _primaryBlue),
              title: Text(
                opcao.titulo,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  InputDecoration _inputDec({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
