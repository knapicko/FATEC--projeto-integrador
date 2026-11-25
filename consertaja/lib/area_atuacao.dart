import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/salvamento_automatico.dart';
import 'widgets/skeleton_loading.dart';
import 'utils/icone_oficio.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';
import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';
import 'services/areas_atuacao_service.dart';

class AreaAtuacaoPage extends StatefulWidget {
  const AreaAtuacaoPage({super.key});

  @override
  State<AreaAtuacaoPage> createState() => _AreaAtuacaoPageState();
}

class _AreaAtuacaoPageState extends State<AreaAtuacaoPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _cardBlueBg = Color(0xFFE8F7FF);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;

  /// Cada escolha/remoção de área salva sozinha (sem botão "Salvar").
  late final SalvamentoAutomatico _autosave = SalvamentoAutomatico(
    _salvarAlteracoes,
    atraso: const Duration(milliseconds: 300),
  );
  List<Map<String, dynamic>> _oficiosDisponiveis = [];
  final List<Map<String, dynamic>> _oficiosSelecionados = [];
  final PageController _detalhesController = PageController();
  int? _idProfissional;
  int _detalheAtual = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _autosave.dispose();
    _detalhesController.dispose();
    super.dispose();
  }

  Future<int?> _buscarIdUsuario(String authId) async {
    final response = await _supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authId)
        .maybeSingle();
    if (response == null) return null;
    final id = response['id_usuario'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // Áreas = OFÍCIOS (cada um com as funções que inclui).
      _oficiosDisponiveis = await AreasAtuacaoService.carregarOficios();

      final usuarioId = await _buscarIdUsuario(user.id);
      if (usuarioId == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // limit(1): não quebra se o usuário tiver mais de um registro.
      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .order('id_profissional')
          .limit(1)
          .maybeSingle();

      if (dadosProf != null) {
        _idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
      }

      if (_idProfissional != null) {
        // O banco guarda as funções; a tela mostra os ofícios delas.
        final funcoes = await AreasAtuacaoService.funcoesDoProfissional(
          _idProfissional!,
        );
        _oficiosSelecionados
          ..clear()
          ..addAll(
            AreasAtuacaoService.oficiosDasFuncoes(
              _oficiosDisponiveis,
              funcoes,
            ).take(3),
          );
      }

      if (mounted) setState(() => _carregando = false);
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      }
    }
  }

  /// Imagem da função vinda do banco (`funcoes.img_funcao`). Sem imagem
  /// cadastrada (ou se falhar), mostra o ícone da função num fundo azul.
  Widget _imagemDetalheOficio(Map<String, dynamic> oficio) {
    final nome = oficio['funcao']?.toString() ?? '';
    final url = oficio['img_funcao']?.toString().trim() ?? '';
    final reserva = Container(
      height: 194,
      width: double.infinity,
      color: _cardBlueBg,
      alignment: Alignment.center,
      child: IconeOficio.imagemPorFuncao(nome, tamanho: 54),
    );
    if (url.isEmpty || url == 'null') return reserva;
    return ImagemApp(child: Image.network(
      url,
      width: double.infinity,
      height: 194,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progresso) => progresso == null
          ? child
          : const SkeletonBox(height: 194, borderRadius: 0),
      errorBuilder: (_, _, _) => reserva,
    ));
  }

  void _abrirSeletorOficio(int slotIndex) {
    final idsSelecionados = _oficiosSelecionados
        .map((e) => (e['id_oficio'] as num?)?.toInt())
        .whereType<int>()
        .toSet();

    final opcoes = _oficiosDisponiveis.where((oficio) {
      final id = (oficio['id_oficio'] as num?)?.toInt();
      if (id == null) return false;
      if (slotIndex < _oficiosSelecionados.length) {
        final atual = (_oficiosSelecionados[slotIndex]['id_oficio'] as num?)
            ?.toInt();
        if (id == atual) return true;
      }
      return !idsSelecionados.contains(id);
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Selecione um ofício',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
              ),
              if (opcoes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma área disponível.',
                    style: TextStyle(color: _textGray),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: opcoes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final oficio = opcoes[index];
                      final nome = oficio['funcao']?.toString() ?? '';
                      return ListTile(
                        leading: CorOriginal(interface: true, child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconeOficio.imagemPorFuncao(
                            oficio['funcao']?.toString(),
                            tamanho: 28,
                          ),
                        )),
                        title: Text(
                          nome,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        // Funções que o ofício inclui.
                        subtitle: Text(
                          (oficio['funcoes_nomes'] as List? ?? const [])
                              .join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _aplicarMudanca(slotIndex, oficio);
                        },
                      );
                    },
                  ),
                ),
              if (slotIndex < _oficiosSelecionados.length)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remover área',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _aplicarMudanca(slotIndex, null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  int? _idOficio(Map<String, dynamic> o) => (o['id_oficio'] as num?)?.toInt();

  /// Troca ([novo] != null) ou remove o ofício do [slot]. Se o ofício que sai
  /// tem serviços ativos (em qualquer função dele), avisa antes: eles serão
  /// DESATIVADOS (não excluídos).
  Future<void> _aplicarMudanca(int slot, Map<String, dynamic>? novo) async {
    final antigo = slot < _oficiosSelecionados.length
        ? _oficiosSelecionados[slot]
        : null;
    final idSaindo = antigo == null ? null : _idOficio(antigo);
    final mesmo = novo != null && idSaindo != null && _idOficio(novo) == idSaindo;

    if (antigo != null && !mesmo && _idProfissional != null) {
      final afetados = await ServicosProfissionalService.servicosAtivosDasFuncoes(
        _idProfissional!,
        AreasAtuacaoService.funcoesDe([antigo]),
      );
      if (!mounted) return;
      if (afetados.isNotEmpty) {
        final confirmou = await _confirmarDesativacao(
          area: antigo['funcao']?.toString() ?? 'esta área',
          servicos: afetados,
          trocar: novo != null,
        );
        if (confirmou != true || !mounted) return;
        final ok = await ServicosProfissionalService.desativarPorTrocaDeArea([
          for (final s in afetados) s.id,
        ]);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível desativar os serviços. A área não foi alterada.',
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              afetados.length == 1
                  ? '1 serviço foi desativado. Você pode reativá-lo em Meus Serviços.'
                  : '${afetados.length} serviços foram desativados. Você pode reativá-los em Meus Serviços.',
            ),
          ),
        );
      }
    }

    setState(() {
      if (novo == null) {
        if (slot < _oficiosSelecionados.length) {
          _oficiosSelecionados.removeAt(slot);
        }
        if (_detalheAtual >= _oficiosSelecionados.length) _detalheAtual = 0;
      } else if (slot < _oficiosSelecionados.length) {
        _oficiosSelecionados[slot] = novo;
      } else {
        _oficiosSelecionados.add(novo);
      }
    });
    _autosave.agendar();
  }

  Future<bool?> _confirmarDesativacao({
    required String area,
    required List<ServicoProfissional> servicos,
    required bool trocar,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
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
                const SizedBox(height: 18),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  trocar ? 'Trocar a área "$area"?' : 'Remover a área "$area"?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  servicos.length == 1
                      ? 'Você tem 1 serviço nesta área. Ele será DESATIVADO '
                            '(não excluído): some para os clientes e não pode '
                            'ser pedido, mas você pode reativá-lo quando quiser '
                            'em Meus Serviços.'
                      : 'Você tem ${servicos.length} serviços nesta área. Eles '
                            'serão DESATIVADOS (não excluídos): somem para os '
                            'clientes e não podem ser pedidos, mas você pode '
                            'reativá-los quando quiser em Meus Serviços.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textGray, height: 1.4),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: servicos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = servicos[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child:
                                    (s.imagemUrl ?? '').trim().isNotEmpty
                                    ? ImagemApp(
                                        child: Image.network(
                                          s.imagemUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _iconeServico(s),
                                        ),
                                      )
                                    : _iconeServico(s),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.titulo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    s.valor <= 0
                                        ? 'Sob consulta'
                                        : 'R\$ ${s.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: const TextStyle(
                                      color: _blue,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: CorOriginal(
                    interface: true,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        trocar
                            ? 'Trocar e desativar os serviços'
                            : 'Remover e desativar os serviços',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: _textGray, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconeServico(ServicoProfissional s) => Container(
    color: _cardBlueBg,
    alignment: Alignment.center,
    child: IconeOficio.imagemPorFuncao(s.funcao, tamanho: 26),
  );

  /// Grava só a diferença entre o banco e a escolha atual (chamado pelo
  /// salvamento automático; erros aparecem no indicador).
  Future<void> _salvarAlteracoes() async {
    if (_idProfissional == null) {
      throw Exception('perfil profissional não encontrado.');
    }
    if (_oficiosSelecionados.isEmpty) {
      throw Exception('escolha pelo menos uma área de atuação.');
    }
    // Grava todas as funções dos ofícios escolhidos.
    await AreasAtuacaoService.salvarProfissional(
      _idProfissional!,
      _oficiosSelecionados,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _blue, size: 20),
          ),
          const Expanded(
            child: Text(
              'Áreas de Atuação',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          BotaoAjuda(
            cor: _blue,
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui ficam as suas áreas de atuação.',
              conteudo: [
                'Escolha até 3 ofícios em que você trabalha. Ao criar um serviço, você escolhe qualquer função desses ofícios, e recebe pedidos do Radar de todas elas.',
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoEscolha() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Escolha suas áreas',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Até 3',
                style: TextStyle(
                  color: _textGray,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (index) {
              final oficio = index < _oficiosSelecionados.length
                  ? _oficiosSelecionados[index]
                  : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => _abrirSeletorOficio(index),
                    child: oficio != null
                        ? _buildCardOficioSelecionado(oficio)
                        : _buildCardVazio(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCardOficioSelecionado(Map<String, dynamic> oficio) {
    final nome = oficio['funcao']?.toString() ?? '';

    return Container(
      height: 136,
      decoration: BoxDecoration(
        color: const Color(0xFFBEEBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _blue, width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: CorOriginal(interface: true, child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            )),
          ),
          // Ocupa o card inteiro: ícone e nome ficam no centro.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: IconeOficio.imagemPorFuncaoAzul(nome, tamanho: 56),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nome,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

  Widget _buildCardVazio() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: Colors.grey.shade300,
        strokeWidth: 1.8,
        radius: 22,
      ),
      child: Container(
        height: 136,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade400, size: 34),
            const SizedBox(height: 8),
            Text(
              'Vazio',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalhesAreas() {
    if (_oficiosSelecionados.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 28, 11, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhes das Áreas Selecionadas',
            style: TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 360,
            child: PageView.builder(
              controller: _detalhesController,
              itemCount: _oficiosSelecionados.length,
              onPageChanged: (index) => setState(() => _detalheAtual = index),
              itemBuilder: (context, index) {
                final oficio = _oficiosSelecionados[index];
                final nome = oficio['funcao']?.toString() ?? '';
                final descricao = oficio['descricao']?.toString().trim() ?? '';
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F5),
                    border: Border.all(color: const Color(0xFFE0DEDE)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                            child: _imagemDetalheOficio(oficio),
                          ),
                          if (index > 0)
                            Positioned(
                              left: 8,
                              top: 78,
                              child: _buildSetaDetalhe(Icons.chevron_left, () {
                                _detalhesController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }),
                            ),
                          if (index < _oficiosSelecionados.length - 1)
                            Positioned(
                              right: 8,
                              top: 78,
                              child: _buildSetaDetalhe(Icons.chevron_right, () {
                                _detalhesController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Text(
                          nome,
                          style: const TextStyle(
                            color: Color(0xFF005477),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          descricao,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF50515A),
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _oficiosSelecionados.length,
                          (dotIndex) => CorOriginal(interface: true, ativo: dotIndex == _detalheAtual, child: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: dotIndex == _detalheAtual
                                  ? _blue
                                  : const Color(0xFFC5C9D5),
                              shape: BoxShape.circle,
                            ),
                          )),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetaDetalhe(IconData icone, VoidCallback onPressed) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Icon(icone, color: _textDark, size: 24),
      ),
    );
  }

  Widget _buildBannerSuporte() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entre em contato pelo menu "Fale Conosco".'),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardBlueBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            Icon(Icons.headset_mic_outlined, color: _blue, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Não encontrou sua área de atuação? Nos contate!',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// No lugar do antigo botão "Salvar": estado do salvamento automático.
  Widget _buildBotaoSalvar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Center(child: IndicadorSalvamento(controle: _autosave)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _carregando
            ? const SkeletonPage(layout: SkeletonLayout.grid)
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSecaoEscolha(),
                          _buildDetalhesAreas(),
                          _buildBannerSuporte(),
                        ],
                      ),
                    ),
                  ),
                  _buildBotaoSalvar(),
                ],
              ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
