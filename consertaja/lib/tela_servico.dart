import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lista_servicos.dart';
import 'models/servico_profissional.dart';
import 'meus_enderecos.dart';
import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'services/lista_servicos_service.dart';
import 'services/servicos_profissional_service.dart';
import 'tela_chat_profissional.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';

class TelaServico extends StatefulWidget {
  final int? idServico;
  final ServicoProfissional? servicoInicial;

  const TelaServico({
    super.key,
    this.idServico,
    this.servicoInicial,
  });

  @override
  State<TelaServico> createState() => _TelaServicoState();
}

class _TelaServicoState extends State<TelaServico> {
  static const Color _azul = Color(0xFF00A2FF);
  static const Color _azulEscuroPreco = Color(0xFF002B66);
  static const Color _texto = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _starYellow = Color(0xFFFBBF24);

  final PageController _pageController = PageController();
  int _paginaImagem = 0;
  DetalheServicoPublico? _detalhe;
  bool _carregando = true;

  // Estado da Sheet "Adicionar Serviço" (persistido durante o ciclo de vida da tela)
  int? _sheetIdUsuario;
  List<_EnderecoUsuarioItem> _sheetEnderecosCliente = [];
  _EnderecoUsuarioItem? _sheetEnderecoClienteSelecionado;
  List<String> _sheetMetodosDisponiveis = [];
  String? _sheetTipoExecucaoSelecionado;
  bool _sheetDropdownMetodosAberto = false;
  final TextEditingController _sheetDetalhesController = TextEditingController();
  DateTime? _sheetDataSelecionada;
  String? _sheetHorarioSelecionado;
  String? _sheetHoraAgendadaSql;
  List<Map<String, dynamic>> _sheetAgendasProfissional = [];
  List<Map<String, dynamic>> _sheetExcecoesProfissional = [];
  bool _sheetDadosCarregados = false;
  bool _sheetEnviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sheetDetalhesController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    DetalheServicoPublico? detalhe;
    if (widget.idServico != null) {
      detalhe = await ServicosProfissionalService.buscarDetalhePublico(
        widget.idServico!,
      );
    }
    if (detalhe == null && widget.servicoInicial != null) {
      final s = widget.servicoInicial!;
      detalhe = DetalheServicoPublico(
        servico: s,
        ehLoja: s.fkGrupoEmpresa != null,
        idGrupoEmpresa: s.fkGrupoEmpresa,
        idProfissional: s.fkProfissional,
        nomePrestador: s.fkGrupoEmpresa != null
            ? 'Loja Parceira'
            : 'Profissional',
        tagEmpresa: null,
        corTagEmpresa: s.cor,
        fotoPrestador: null,
        seguidores: 0,
        enderecoFormatado: 'Endereço a combinar',
        latitude: -23.5505,
        longitude: -46.6333,
        temCoordenadas: false,
      );
    }
    if (detalhe == null) {
      final sPadrao = ServicoProfissional(
        id: widget.idServico ?? 1,
        fkProfissional: 1,
        fkGrupoEmpresa: null,
        titulo: 'Serviço Profissional',
        descricao:
            'Serviço especializado com garantia de qualidade e suporte dedicado.',
        valor: 0.0,
        fkOficio: 1,
        funcao: 'Geral',
        ativo: true,
        dataCriacao: DateTime.now(),
      );
      detalhe = DetalheServicoPublico(
        servico: sPadrao,
        ehLoja: false,
        idGrupoEmpresa: null,
        idProfissional: 1,
        nomePrestador: 'Profissional',
        tagEmpresa: null,
        corTagEmpresa: null,
        fotoPrestador: null,
        seguidores: 0,
        enderecoFormatado: 'Endereço a combinar',
        latitude: -23.5505,
        longitude: -46.6333,
        temCoordenadas: false,
      );
    }
    if (!mounted) return;
    setState(() {
      _detalhe = detalhe;
      _carregando = false;
    });
    _carregarDadosSheet();
  }

  String _preco(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  bool _ehUrl(String? caminho) {
    if (caminho == null) return false;
    return caminho.startsWith('http://') || caminho.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final detalhe = _detalhe;
    final servico = detalhe?.servico;
    final titulo = servico?.titulo.trim().isNotEmpty == true
        ? servico!.titulo.trim()
        : 'Conserto de Cabo de Panela';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _carregando
            ? const Center(child: CircularProgressIndicator(color: _azul))
            : detalhe == null || servico == null
            ? _buildErro()
            : Column(
                children: [
                  _buildCabecalho(titulo),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildCarrossel(servico),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPrecoETags(detalhe),
                              const SizedBox(height: 12),
                              _buildFormasPagamento(),
                              const SizedBox(height: 12),
                              _buildPrazoEntrega(),
                              const SizedBox(height: 20),
                              _buildOferecidoPor(detalhe),
                              const SizedBox(height: 22),
                              _buildDetalhes(servico),
                              const SizedBox(height: 12),
                              _buildChecklistEstatico(),
                              const SizedBox(height: 22),
                              _buildEnderecoProfissional(detalhe),
                              const SizedBox(height: 12),
                              _buildDisponivelEnderecoEstatico(),
                              const SizedBox(height: 24),
                              _buildAvaliacoesEstaticas(),
                              const SizedBox(height: 24),
                              _buildServicosParecidosEstaticos(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBarraInferior(servico),
                ],
              ),
      ),
    );
  }

  Widget _buildErro() {
    return Column(
      children: [
        _buildCabecalho('Serviço'),
        const Expanded(
          child: Center(
            child: Text(
              'Não foi possível carregar este serviço.',
              style: TextStyle(color: _muted),
            ),
          ),
        ),
      ],
    );
  }

  // 1. Cabeçalho Superior
  Widget _buildCabecalho(String titulo) {
    return Container(
      color: _azul,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Carrossel de imagens (quantidade = nº de imagens anexadas; sem imagem = 1 placeholder)
  Widget _buildCarrossel(ServicoProfissional servico) {
    final urls = <String>[];
    if (servico.imagemUrl != null && _ehUrl(servico.imagemUrl!)) {
      urls.add(servico.imagemUrl!);
    }
    final total = urls.isEmpty ? 1 : urls.length;
    if (_paginaImagem >= total) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _paginaImagem = 0);
      });
    }

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _paginaImagem = i),
            itemBuilder: (_, index) {
              if (urls.isEmpty) return _placeholderImagem();
              final url = urls[index];
              return Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderImagem(),
              );
            },
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '4.7',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: _texto,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.star, color: _starYellow, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '(3.248)',
                        style: TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _azul,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_paginaImagem + 1}/$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImagem({double? height, double? iconSize}) {
    return Container(
      height: height,
      color: const Color(0xFFEAF4FB),
      child: Center(
        child: Icon(
          Icons.home_repair_service_rounded,
          color: const Color(0xFF0A6E9D),
          size: iconSize ?? 56,
        ),
      ),
    );
  }

  // 2. Preço e Tags
  Widget _buildPrecoETags(DetalheServicoPublico detalhe) {
    final tagEmpresa = detalhe.tagEmpresa?.trim();
    final categoria = detalhe.servico.funcao?.trim().isNotEmpty == true
        ? detalhe.servico.funcao!.trim()
        : null;

    final corBaseOficio = CorOficio.parse(detalhe.servico.cor);
    final corFundoOficio = CorOficio.corFundo(corBaseOficio);
    final corTextoOficio = CorOficio.corTexto(corBaseOficio);

    final corBaseEmpresa = CorOficio.parse(detalhe.corTagEmpresa);
    final corFundoEmpresa = CorOficio.corFundo(corBaseEmpresa);
    final corTextoEmpresa = CorOficio.corTexto(corBaseEmpresa);

    final temTagEmpresa =
        detalhe.ehLoja && tagEmpresa != null && tagEmpresa.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _preco(detalhe.servico.valor > 0 ? detalhe.servico.valor : 0),
          style: const TextStyle(
            color: _azulEscuroPreco,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        if (temTagEmpresa) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: corFundoEmpresa,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: corBaseEmpresa, width: 1.2),
            ),
            child: Text(
              tagEmpresa.startsWith('#') ? tagEmpresa : '#$tagEmpresa',
              style: TextStyle(
                color: corTextoEmpresa,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (categoria != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: corFundoOficio,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              categoria,
              style: TextStyle(
                color: corTextoOficio,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // Formas de Pagamento: Pix, Cartão, Boleto
  Widget _buildFormasPagamento() {
    return Row(
      children: [
        const Text(
          'Formas de Pagamento:',
          style: TextStyle(
            color: _azul,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        _pagamentoChip(
          iconeWidget: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF00BDAE),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.apps, size: 9, color: Colors.white),
            ),
          ),
          label: 'Pix',
        ),
        const SizedBox(width: 6),
        _pagamentoChip(
          iconeWidget: const Icon(
            Icons.credit_card_outlined,
            size: 14,
            color: Color(0xFF64748B),
          ),
          label: 'Cartão',
        ),
        const SizedBox(width: 6),
        _pagamentoChip(
          iconeWidget: const Icon(
            Icons.view_week_outlined,
            size: 14,
            color: Color(0xFF64748B),
          ),
          label: 'Boleto',
        ),
      ],
    );
  }

  Widget _pagamentoChip({required Widget iconeWidget, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconeWidget,
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // Prazo e Entrega
  Widget _buildPrazoEntrega() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Entregue em até 5 dias ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      fontSize: 12.5,
                    ),
                  ),
                  TextSpan(
                    text: '— Retirada ou Leva e Traz',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _azul,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.local_shipping, color: _azul, size: 18),
          const SizedBox(width: 8),
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'i',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'serif',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Perfil do Prestador ("Oferecido por Mundo das Louças")
  Widget _buildOferecidoPor(DetalheServicoPublico detalhe) {
    final nomePrestador = detalhe.nomePrestador.trim().isNotEmpty
        ? detalhe.nomePrestador.trim()
        : 'Prestador';

    final bool temTagEmpresa = detalhe.ehLoja &&
        detalhe.tagEmpresa != null &&
        detalhe.tagEmpresa!.trim().isNotEmpty;
    final String tagEmpresa = detalhe.tagEmpresa?.trim() ?? '';
    final corEmpresaBase = detalhe.corTagEmpresa != null &&
            detalhe.corTagEmpresa!.isNotEmpty
        ? CorOficio.parse(detalhe.corTagEmpresa!)
        : _azul;
    final Color corFundoEmpresa = CorOficio.corFundo(corEmpresaBase);
    final Color corTextoEmpresa = CorOficio.corTexto(corEmpresaBase);

    final String? categoria = detalhe.servico.funcao?.trim().isNotEmpty == true
        ? detalhe.servico.funcao!.trim()
        : null;
    final corOficioBase = detalhe.servico.cor != null &&
            detalhe.servico.cor!.isNotEmpty
        ? CorOficio.parse(detalhe.servico.cor!)
        : (categoria != null
            ? CorOficio.parse(categoria)
            : const Color(0xFF64748B));
    final Color corFundoOficio = CorOficio.corFundo(corOficioBase);
    final Color corTextoOficio = CorOficio.corTexto(corOficioBase);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Oferecido por $nomePrestador',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _texto,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logotipo da loja com selo de verificação
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildAvatarOuLogo(detalhe),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _azul,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomePrestador,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _texto,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (temTagEmpresa) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: corFundoEmpresa,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tagEmpresa.startsWith('#')
                                  ? tagEmpresa
                                  : '#$tagEmpresa',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: corTextoEmpresa,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (categoria != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: corFundoOficio,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              categoria,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: corTextoOficio,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${detalhe.seguidores} ${detalhe.seguidores == 1 ? 'Seguidor' : 'Seguidores'} • ${detalhe.ehLoja ? 'Loja Verificada' : 'Profissional Verificado'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TelaChatProfissional(
                              nomeProfissional: nomePrestador,
                              fotoProfissional: detalhe.fotoPrestador ?? '',
                              oficioPrincipal: categoria ?? '',
                              idProfissional: detalhe.idProfissional,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azul,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Conversar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (detalhe.ehLoja && detalhe.idGrupoEmpresa != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerfilLoja(
                              idGrupoEmpresa: detalhe.idGrupoEmpresa,
                              nomeEmpresa: nomePrestador,
                              fotoUrlEmpresa: detalhe.fotoPrestador,
                              tagEmpresa: tagEmpresa,
                              corTagEmpresa: detalhe.corTagEmpresa,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerfilProfissionalPage(
                              nomeInicial: nomePrestador,
                              imagemInicial: detalhe.fotoPrestador ?? '',
                              profissao: categoria ?? '',
                              idGrupoEmpresa: detalhe.idGrupoEmpresa,
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      detalhe.ehLoja ? 'Ver Loja' : 'Ver Perfil',
                      style: const TextStyle(
                        color: _azul,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarOuLogo(DetalheServicoPublico detalhe) {
    if (detalhe.fotoPrestador != null && _ehUrl(detalhe.fotoPrestador)) {
      return Image.network(
        detalhe.fotoPrestador!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIniciais(detalhe),
      );
    }
    return _fallbackIniciais(detalhe);
  }

  Widget _fallbackIniciais(DetalheServicoPublico detalhe) {
    final nome = detalhe.nomePrestador.trim().isNotEmpty
        ? detalhe.nomePrestador.trim()
        : (detalhe.ehLoja ? 'Loja' : 'Profissional');
    return Container(
      color: const Color(0xFFE1F5FE),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(nome),
        style: const TextStyle(
          color: _azul,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 4. Detalhes do Serviço
  Widget _buildDetalhes(ServicoProfissional servico) {
    final descricao = servico.descricao.trim().isNotEmpty
        ? servico.descricao.trim()
        : 'Conserto e reposição especializada de cabos, alças e pegadores de panelas comuns e de pressão. Instalação de peças em baquelite antitérmico com fixação reforçada em rebite industrial de alumínio, garantindo máxima segurança e firmeza no uso diário.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalhes do Serviço',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _texto,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          descricao,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // Checklist com 3 vantagens
  Widget _buildChecklistEstatico() {
    const itens = [
      'Material antitérmico baquelite de alta durabilidade e isolamento.',
      'Rebites duplos de alta pressão que não afrouxam com o calor.',
      'Garantia de 90 dias do serviço prestado pelo ConsertaJá.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: itens
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check,
                      color: Color(0xFF10B981),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // 5. Região de Atendimento / Endereço do Profissional
  Widget _buildEnderecoProfissional(DetalheServicoPublico detalhe) {
    final lat = detalhe.temCoordenadas ? detalhe.latitude : -23.5505;
    final lng = detalhe.temCoordenadas ? detalhe.longitude : -46.6333;
    final ruaNumero = _resumirRuaNumero(detalhe.enderecoFormatado);

    return Column(
      children: [
        const Row(
          children: [
            Text(
              'Endereço do Profissional',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _texto,
              ),
            ),
            Spacer(),
            Text(
              'Raio de até 12 km',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 170,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'br.com.consertaja',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(lat, lng),
                          radius: 2400,
                          useRadiusInMeter: true,
                          color: _azul.withValues(alpha: 0.22),
                          borderColor: _azul,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFF00A2FF),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      ruaNumero,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mostra só "Rua, Número" (sem bairro/cidade/CEP inteiros).
  String _resumirRuaNumero(String enderecoFormatado) {
    final limpo = enderecoFormatado.trim();
    if (limpo.isEmpty ||
        limpo == 'Endereço a combinar' ||
        limpo == 'Endereço não cadastrado') {
      return 'Endereço a combinar';
    }
    final partes = limpo.split(',').map((p) => p.trim()).toList();
    if (partes.isEmpty) return limpo;
    // O service monta "logradouro, numero, bairro, cidade, UF, CEP".
    if (partes.length >= 2 && RegExp(r'^\d').hasMatch(partes[1])) {
      return '${partes[0]}, ${partes[1]}';
    }
    return partes.first;
  }

  Widget _buildDisponivelEnderecoEstatico() {
    final endereco = _sheetEnderecoClienteSelecionado;
    final temEndereco = endereco != null;
    final tipoEnd = endereco?.tipoEndereco.isNotEmpty == true
        ? endereco!.tipoEndereco
        : 'Casa';
    final linha = endereco?.linhaFormatada.isNotEmpty == true
        ? endereco!.linhaFormatada
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'DISPONÍVEL NO SEU ENDEREÇO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (temEndereco)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tipoEnd,
                        style: const TextStyle(
                          color: _azul,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, color: _azul, size: 11),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (temEndereco)
            Text(
              linha,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF334155),
                height: 1.3,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sheetIdUsuario == null
                      ? 'Faça login para ver seu endereço principal.'
                      : 'Você ainda não cadastrou um endereço.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MeusEnderecosPage(
                            isVisitante: false,
                            isProfissional: false,
                          ),
                        ),
                      ).then((_) => _carregarDadosSheet());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text(
                      'Cadastrar meu endereço',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 6. Avaliações e Reputação
  Widget _buildAvaliacoesEstaticas() {
    Widget barra(int estrelas, double fracao, String quantidade) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              child: Text(
                '$estrelas',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.star, size: 11, color: _azul),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fracao,
                  minHeight: 7,
                  color: _azul,
                  backgroundColor: const Color(0xFFF1F5F9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(
                quantidade,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4.7',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: _texto,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: _starYellow, size: 16),
                    Icon(Icons.star, color: _starYellow, size: 16),
                    Icon(Icons.star, color: _starYellow, size: 16),
                    Icon(Icons.star, color: _starYellow, size: 16),
                    Icon(Icons.star, color: _starYellow, size: 16),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Média baseada em 3.248 avaliações',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  barra(5, 0.72, '2.342'),
                  barra(4, 0.20, '632'),
                  barra(3, 0.14, '473'),
                  barra(2, 0.07, '212'),
                  barra(1, 0.02, '50'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Text(
              'Principais Avaliações',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Spacer(),
            Text(
              'Ver todas (3.248)',
              style: TextStyle(
                color: _azul,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Card 1: Luiz F.
              _cardAvaliacaoLuiz(),
              // Card 2: Maria C. (MC)
              _cardAvaliacaoMC(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardAvaliacaoLuiz() {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/virar_camera_img.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF334155),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Luiz F.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _texto,
                      ),
                    ),
                    Text(
                      '25/05/2026',
                      style: TextStyle(fontSize: 10.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star_half, color: _starYellow, size: 13),
              SizedBox(width: 4),
              Text(
                '4.5',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '"Muito bom serviço, o profissional realmente sabe fazer muito bem aquilo que ele prometeu! O cabo ficou super firme e sem folgas."',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF334155)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: Color(0xFF0A6E9D),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Foto anexada pelo cliente',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAvaliacaoMC() {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFC7F9CC),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'MC',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF22577A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maria C.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _texto,
                      ),
                    ),
                    Text(
                      '18/05/2026',
                      style: TextStyle(fontSize: 10.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              Icon(Icons.star, color: _starYellow, size: 13),
              SizedBox(width: 4),
              Text(
                '5.0',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '"Atendimento excelente, me salvou de ter que jogar minha panela fora! Colocou o cabo novo e ficou melhor que de loja."',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF334155)),
          ),
          const Spacer(),
          const Row(
            children: [
              Icon(Icons.check, color: Color(0xFF10B981), size: 15),
              SizedBox(width: 4),
              Text(
                'Compra efetuada',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 7. Serviços Parecidos e Rodapé
  Widget _buildServicosParecidosEstaticos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Serviços Parecidos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _texto,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 225,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _cardServicoParecido(
                titulo: 'Troca de Válvula de Panela de Pressão',
                preco: 'R\$ 25,00',
                nota: '4.9 (1.420)',
              ),
              _cardServicoParecido(
                titulo: 'Conserto de Tampa e Alça Lateral',
                preco: 'R\$ 15,90',
                nota: '4.8 (890)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardServicoParecido({
    required String titulo,
    required String preco,
    required String nota,
  }) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: _placeholderImagem(height: 110, iconSize: 36),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.25,
                    color: _texto,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: _starYellow, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      nota,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      preco,
                      style: const TextStyle(
                        color: _azulEscuroPreco,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.add, color: _azul, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Barra de Ação Inferior (Fixa)
  Widget _buildBarraInferior(ServicoProfissional servico) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _preco(servico.valor > 0 ? servico.valor : 18.99),
                  style: const TextStyle(
                    color: _azul,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const Text(
                  'Entregue em até 5 dias',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _abrirSheetAdicionarServico();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Adicionar Serviço',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FLUXO DE ADIÇÃO / SOLICITAÇÃO DE SERVIÇO (BOTTOM SHEET EXTENSÍVEL)
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _carregarDadosSheet() async {
    final detalhe = _detalhe;
    final servico = detalhe?.servico;
    if (servico == null) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final usuario = await supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', user.id)
            .maybeSingle();
        _sheetIdUsuario = (usuario?['id_usuario'] as num?)?.toInt();

        if (_sheetIdUsuario != null) {
          final vinculos = await supabase
              .from('ass_usuario_endereco')
              .select('fk_endereco, apelido_endereco, tipo_endereco, endereco_ativo')
              .eq('fk_usuario', _sheetIdUsuario!);

          final enderecosCarregados = <_EnderecoUsuarioItem>[];
          for (final v in vinculos) {
            final idEnd = (v['fk_endereco'] as num?)?.toInt();
            if (idEnd == null) continue;
            final end = await supabase
                .from('enderecos')
                .select('logradouro, numero, complemento, bairro, cep, fk_cidade')
                .eq('id_endereco', idEnd)
                .maybeSingle();
            if (end == null) continue;
            final idCid = (end['fk_cidade'] as num?)?.toInt();
            Map<String, dynamic>? cid;
            Map<String, dynamic>? est;
            if (idCid != null) {
              cid = await supabase
                  .from('cidades')
                  .select('nome_cidade, fk_estado')
                  .eq('id_cidade', idCid)
                  .maybeSingle();
              final idEst = (cid?['fk_estado'] as num?)?.toInt();
              if (idEst != null) {
                est = await supabase
                    .from('estados')
                    .select('sigla_estado')
                    .eq('id_estado', idEst)
                    .maybeSingle();
              }
            }
            final logr = end['logradouro']?.toString().trim() ?? '';
            final numStr = end['numero']?.toString().trim() ?? '';
            final bairro = end['bairro']?.toString().trim() ?? '';
            final cidNome = cid?['nome_cidade']?.toString().trim() ?? '';
            final sigla = est?['sigla_estado']?.toString().trim() ?? '';

            final partes = [
              if (logr.isNotEmpty) (numStr.isNotEmpty ? '$logr, $numStr' : logr),
              if (bairro.isNotEmpty) bairro,
              if (cidNome.isNotEmpty) (sigla.isNotEmpty ? '$cidNome - $sigla' : cidNome),
            ];
            final linha = partes.join(', ');
            final tipo = v['tipo_endereco']?.toString().trim().isNotEmpty == true
                ? v['tipo_endereco'].toString().trim()
                : (v['apelido_endereco']?.toString().trim().isNotEmpty == true
                    ? v['apelido_endereco'].toString().trim()
                    : 'Casa');

            enderecosCarregados.add(
              _EnderecoUsuarioItem(
                id: idEnd,
                tipoEndereco: tipo,
                apelido: v['apelido_endereco']?.toString().trim() ?? '',
                linhaFormatada: linha.isNotEmpty ? linha : 'Endereço cadastrado',
                principal: v['endereco_ativo'] == true,
              ),
            );
          }

          if (mounted) {
            setState(() {
              _sheetEnderecosCliente = enderecosCarregados;
              if (_sheetEnderecoClienteSelecionado == null && enderecosCarregados.isNotEmpty) {
                _sheetEnderecoClienteSelecionado = enderecosCarregados.firstWhere(
                  (e) => e.principal,
                  orElse: () => enderecosCarregados.first,
                );
              }
            });
          }
        }
      }

      // 2. Só o tipo_execucao do serviço (passo 2). Sem metodo_entrega
      // (nem metodo_entrega_empresa): a coluna oficial é
      // servicos_profissional.tipo_execucao.
      final metodos = <String>[];
      if (servico.tipoExecucao.isNotEmpty &&
          servico.tipoExecucao != 'Execução' &&
          servico.tipoExecucao != 'Geral') {
        for (final m in servico.tipoExecucao.split(',')) {
          final limpo = m.trim();
          if (limpo.isNotEmpty && !metodos.contains(limpo)) {
            metodos.add(limpo);
          }
        }
      }

      if (metodos.isEmpty) {
        metodos.addAll(['Leva e Traz', 'Retirado no Local', 'Receba em Casa', 'Atendimento em Domicílio']);
      }

      // 3. Agenda e Exceções
      try {
        final agendas = await supabase
            .from('agenda_profissional')
            .select('dias_semana, hora_ini, hora_fim')
            .eq('fk_profissional', servico.fkProfissional);
        _sheetAgendasProfissional = List<Map<String, dynamic>>.from(agendas);
      } catch (_) {}

      try {
        final hoje = DateTime.now();
        final dataInicio = DateTime(hoje.year, hoje.month, 1);
        final dataFim = DateTime(hoje.year, hoje.month + 4, 0);
        final excecoes = await supabase
            .from('grade_horario_excecao')
            .select('dia_semana, hora_ini, hora_fim, observacao')
            .eq('fk_profissional', servico.fkProfissional)
            .gte('dia_semana', _formatarDataSql(dataInicio))
            .lte('dia_semana', _formatarDataSql(dataFim));
        _sheetExcecoesProfissional = List<Map<String, dynamic>>.from(excecoes);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _sheetMetodosDisponiveis = metodos;
          if (_sheetTipoExecucaoSelecionado == null ||
              !_sheetMetodosDisponiveis.contains(_sheetTipoExecucaoSelecionado)) {
            _sheetTipoExecucaoSelecionado = _sheetMetodosDisponiveis.first;
          }
          _sheetDadosCarregados = true;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados da sheet: $e');
    }
  }

  void _abrirSheetAdicionarServico() {
    if (!_sheetDadosCarregados) {
      _carregarDadosSheet();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _buildSheetConteudo(setSheetState);
          },
        );
      },
    );
  }

  Widget _buildSheetConteudo(StateSetter setSheetState) {
    final detalhe = _detalhe;
    final servico = detalhe?.servico;
    if (servico == null) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator(color: _azul)),
      );
    }

    final tipoExecucao = _sheetTipoExecucaoSelecionado ?? 'Leva e Traz';
    final bool ehRecebaEmCasa = tipoExecucao == 'Receba em Casa';
    final bool ehRetiradoNoLocal = tipoExecucao == 'Retirado no Local' || tipoExecucao == 'Retirada no Local';
    // Leva e Traz ou Atendimento em Domicílio
    final bool ehApenasCliente = !ehRecebaEmCasa && !ehRetiradoNoLocal;

    final int passoDetalhesNum = ehRecebaEmCasa ? 5 : 4;
    final int passoAgendaNum = ehRecebaEmCasa ? 6 : 5;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildCabecalhoSheet(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  // Passo 1: O Serviço
                  _buildRotuloPasso('PASSO 1: O SERVIÇO'),
                  _buildPasso1Servico(servico),
                  const SizedBox(height: 18),

                  // Passo 2: Execução do Serviço
                  _buildRotuloPasso('PASSO 2: EXECUÇÃO DO SERVIÇO'),
                  _buildPasso2Execucao(setSheetState),
                  const SizedBox(height: 18),

                  // Passos de Endereço (condicionais conforme tipo de execução)
                  if (ehRecebaEmCasa) ...[
                    _buildRotuloPasso('PASSO 3: LOCALIZAÇÃO DO SERVIÇO'),
                    _buildCardEnderecoProfissional(),
                    const SizedBox(height: 18),
                    _buildRotuloPasso('PASSO 4: ENTREGA DO SERVIÇO'),
                    _buildCardEnderecoCliente(setSheetState),
                    const SizedBox(height: 18),
                  ] else if (ehRetiradoNoLocal) ...[
                    _buildRotuloPasso('PASSO 3: LOCALIZAÇÃO DO SERVIÇO'),
                    _buildCardEnderecoProfissional(),
                    const SizedBox(height: 18),
                  ] else if (ehApenasCliente) ...[
                    _buildRotuloPasso('PASSO 3: ENTREGA DO SERVIÇO'),
                    _buildCardEnderecoCliente(setSheetState),
                    const SizedBox(height: 18),
                  ],

                  // Passo de Detalhes
                  _buildPassoDetalhes(passoDetalhesNum, setSheetState),
                  const SizedBox(height: 18),

                  // Passo de Agendamento
                  _buildPassoAgendamento(passoAgendaNum, setSheetState),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            _buildBarraInferiorSheet(servico),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalhoSheet() {
    final titulo = _detalhe?.servico.titulo.trim().isNotEmpty == true
        ? _detalhe!.servico.titulo.trim()
        : 'Conserto de Cabo de Panela';

    return Container(
      color: _azul,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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

  Widget _buildRotuloPasso(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPasso1Servico(ServicoProfissional servico) {
    final corOficio = servico.cor != null && servico.cor!.isNotEmpty
        ? CorOficio.parse(servico.cor!)
        : (servico.funcao != null ? CorOficio.parse(servico.funcao!) : const Color(0xFF0FB3FF));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: corOficio,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: IconeOficio.imagemPorFuncao(
              servico.funcao,
              tamanho: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Serviço Selecionado',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  servico.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasso2Execucao(StateSetter setSheetState) {
    final metodo = _sheetTipoExecucaoSelecionado ?? 'Leva e Traz';
    final temMaisDeUm = _sheetMetodosDisponiveis.length > 1;
    final iconeMetodo = _obterIconeMetodo(metodo);

    return Column(
      children: [
        InkWell(
          onTap: temMaisDeUm
              ? () {
                  setSheetState(() {
                    _sheetDropdownMetodosAberto = !_sheetDropdownMetodosAberto;
                  });
                  setState(() {});
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _sheetDropdownMetodosAberto ? _azul : const Color(0xFFE2E8F0),
                width: _sheetDropdownMetodosAberto ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0FB3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconeMetodo, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de entrega',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metodo,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (temMaisDeUm)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      _sheetDropdownMetodosAberto
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _azul,
                      size: 26,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_sheetDropdownMetodosAberto && temMaisDeUm) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _sheetMetodosDisponiveis.map((m) {
                final sel = m == metodo;
                return InkWell(
                  onTap: () {
                    setSheetState(() {
                      _sheetTipoExecucaoSelecionado = m;
                      _sheetDropdownMetodosAberto = false;
                    });
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          _obterIconeMetodo(m),
                          color: sel ? _azul : const Color(0xFF64748B),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                              color: sel ? _azul : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (sel)
                          const Icon(Icons.check, color: _azul, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardEnderecoProfissional() {
    final endereco = _detalhe?.enderecoFormatado.isNotEmpty == true
        ? _detalhe!.enderecoFormatado
        : 'Endereço a combinar';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.location_on, color: Color(0xFF64748B), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Endereço do serviço',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  endereco,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.map_outlined, color: Color(0xFF1E293B), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCardEnderecoCliente(StateSetter setSheetState) {
    final endereco = _sheetEnderecoClienteSelecionado;
    final tipoEnd = endereco?.tipoEndereco.isNotEmpty == true
        ? endereco!.tipoEndereco
        : 'Casa';
    final linha = endereco?.linhaFormatada.isNotEmpty == true
        ? endereco!.linhaFormatada
        : (_sheetIdUsuario == null
            ? 'Faça login para selecionar seu endereço'
            : 'Nenhum endereço cadastrado');

    return InkWell(
      onTap: () => _mostrarModalSelecaoEnderecos(context, setSheetState),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.home, color: Color(0xFF64748B), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Endereço selecionado: $tipoEnd',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    linha,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassoDetalhes(int passoNum, StateSetter setSheetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRotuloPasso('PASSO $passoNum: DETALHES DO SERVIÇO  (Opcional)'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _sheetDetalhesController,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setSheetState(() {}),
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                  hintText: 'Descreva o seu serviço',
                  hintStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_sheetDetalhesController.text.length}/500',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassoAgendamento(int passoNum, StateSetter setSheetState) {
    final textoData = _sheetDataSelecionada != null
        ? _formatarDataVisual(_sheetDataSelecionada!)
        : 'Selecione uma data';
    final textoHorario = _sheetHorarioSelecionado != null &&
            _sheetHorarioSelecionado!.isNotEmpty
        ? _sheetHorarioSelecionado!
        : 'Selecione um horário';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRotuloPasso('PASSO $passoNum: AGENDAMENTO'),
        // Container 1: Data
        InkWell(
          onTap: () => _mostrarModalCalendario(context, setSheetState),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        textoData,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _sheetDataSelecionada != null
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Container 2: Horário
        InkWell(
          onTap: () => _mostrarModalHorarios(context, setSheetState),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Horário',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        textoHorario,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _sheetHorarioSelecionado != null
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarraInferiorSheet(ServicoProfissional servico) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _preco(servico.valor > 0 ? servico.valor : 18.99),
                  style: const TextStyle(
                    color: _azul,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const Text(
                  'Entregue em até 5 dias',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _sheetEnviando ? null : () => _confirmarSolicitacao(servico),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _sheetEnviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Adicionar Serviço',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarModalSelecaoEnderecos(BuildContext parentContext, StateSetter setSheetState) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seus Endereços',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              if (_sheetEnderecosCliente.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhum endereço cadastrado.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sheetEnderecosCliente.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, i) {
                      final item = _sheetEnderecosCliente[i];
                      final selecionado = _sheetEnderecoClienteSelecionado?.id == item.id;
                      final icone = item.tipoEndereco.toLowerCase().contains('trabalho')
                          ? Icons.work_outline
                          : Icons.home_outlined;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: selecionado ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icone, color: selecionado ? _azul : const Color(0xFF64748B), size: 22),
                        ),
                        title: Text(
                          item.tipoEndereco,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          item.linhaFormatada,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        trailing: selecionado
                            ? const Icon(Icons.check_circle, color: _azul)
                            : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1)),
                        onTap: () {
                          setSheetState(() {
                            _sheetEnderecoClienteSelecionado = item;
                          });
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarModalCalendario(BuildContext parentContext, StateSetter setSheetState) {
    DateTime mesAtual = DateTime(
      _sheetDataSelecionada?.year ?? DateTime.now().year,
      _sheetDataSelecionada?.month ?? DateTime.now().month,
    );

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final primeiroDia = DateTime(mesAtual.year, mesAtual.month, 1);
            final ultimoDia = DateTime(mesAtual.year, mesAtual.month + 1, 0);
            final diaInicioSemana = primeiroDia.weekday % 7;
            final totalCelulas = ((diaInicioSemana + ultimoDia.day) / 7).ceil() * 7;
            final hoje = DateTime.now();
            final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

            const meses = [
              'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
              'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
            ];
            const diasSemanaCabecalho = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Mês / Ano e controles de navegação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${meses[mesAtual.month - 1]} ${mesAtual.year}',
                        style: const TextStyle(
                          color: _azul,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Color(0xFF64748B)),
                            onPressed: () {
                              setModalState(() {
                                mesAtual = DateTime(mesAtual.year, mesAtual.month - 1);
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                            onPressed: () {
                              setModalState(() {
                                mesAtual = DateTime(mesAtual.year, mesAtual.month + 1);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dias da semana
                  Row(
                    children: diasSemanaCabecalho.map((d) {
                      return Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _azul,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Grid de dias
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: totalCelulas,
                    itemBuilder: (context, index) {
                      final ehAntes = index < diaInicioSemana;
                      final diaNumero = index - diaInicioSemana + 1;
                      final ehDepois = diaNumero > ultimoDia.day;

                      if (ehAntes || ehDepois) {
                        return const SizedBox.shrink();
                      }

                      final dataDia = DateTime(mesAtual.year, mesAtual.month, diaNumero);
                      final dataSemHora = DateTime(dataDia.year, dataDia.month, dataDia.day);
                      final isPassado = dataSemHora.isBefore(hojeSemHora);
                      final isDisponivelAgenda = _isDiaDisponivelNaAgenda(dataDia);

                      final exc = _buscarExcecaoData(dataDia);
                      final bool temExcecao = exc != null;
                      final bool isExcecaoDiaInteiro = temExcecao && _isExcecaoDiaInteiro(exc);

                      final bool selecionado = _sheetDataSelecionada != null &&
                          _sheetDataSelecionada!.year == dataDia.year &&
                          _sheetDataSelecionada!.month == dataDia.month &&
                          _sheetDataSelecionada!.day == dataDia.day;

                      // 1. Exceção de dia inteiro (bloqueado em vermelho)
                      if (!isPassado && temExcecao && isExcecaoDiaInteiro) {
                        return InkWell(
                          onTap: () {
                            final obs = exc['observacao']?.toString();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  obs != null && obs.isNotEmpty
                                      ? 'Indisponível nesta data: $obs'
                                      : 'O profissional não atenderá nesta data.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCE4257)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$diaNumero',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B2335),
                              ),
                            ),
                          ),
                        );
                      }

                      // 2. Data disponível (agenda do profissional ou exceção parcial)
                      final bool isEscolhavel = !isPassado && (isDisponivelAgenda || (temExcecao && !isExcecaoDiaInteiro));

                      if (isEscolhavel) {
                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              _sheetDataSelecionada = dataDia;
                              _sheetHorarioSelecionado = null;
                              _sheetHoraAgendadaSql = null;
                            });
                            setState(() {});
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selecionado ? const Color(0xFF0FB3FF) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF0FB3FF),
                                width: selecionado ? 2 : 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$diaNumero',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: selecionado ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        );
                      }

                      // 3. Dias não disponíveis ou passados (cinza)
                      return Center(
                        child: Text(
                          '$diaNumero',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarModalHorarios(BuildContext parentContext, StateSetter setSheetState) {
    if (_sheetDataSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma data primeiro para escolher o horário.'),
        ),
      );
      return;
    }

    final exc = _buscarExcecaoData(_sheetDataSelecionada!);
    final bool temExcecaoParcial = exc != null && !_isExcecaoDiaInteiro(exc);
    final TimeOfDay? excIni = temExcecaoParcial ? _parseTimeOfDay(exc['hora_ini']) : null;
    final TimeOfDay? excFim = temExcecaoParcial ? _parseTimeOfDay(exc['hora_fim']) : null;

    final todosSlots = [
      _OpcaoHorarioItem(
        label: '08:00 - 10:00 (Manhã)',
        horaSql: '08:00:00',
        inicio: const TimeOfDay(hour: 8, minute: 0),
        fim: const TimeOfDay(hour: 10, minute: 0),
      ),
      _OpcaoHorarioItem(
        label: '09:00 - 12:00 (Manhã)',
        horaSql: '09:00:00',
        inicio: const TimeOfDay(hour: 9, minute: 0),
        fim: const TimeOfDay(hour: 12, minute: 0),
      ),
      _OpcaoHorarioItem(
        label: '10:00 - 12:00 (Manhã)',
        horaSql: '10:00:00',
        inicio: const TimeOfDay(hour: 10, minute: 0),
        fim: const TimeOfDay(hour: 12, minute: 0),
      ),
      _OpcaoHorarioItem(
        label: '13:00 - 15:00 (Tarde)',
        horaSql: '13:00:00',
        inicio: const TimeOfDay(hour: 13, minute: 0),
        fim: const TimeOfDay(hour: 15, minute: 0),
      ),
      _OpcaoHorarioItem(
        label: '14:00 - 17:00 (Tarde)',
        horaSql: '14:00:00',
        inicio: const TimeOfDay(hour: 14, minute: 0),
        fim: const TimeOfDay(hour: 17, minute: 0),
      ),
      _OpcaoHorarioItem(
        label: '15:00 - 18:00 (Tarde)',
        horaSql: '15:00:00',
        inicio: const TimeOfDay(hour: 15, minute: 0),
        fim: const TimeOfDay(hour: 18, minute: 0),
      ),
    ];

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Horários Disponíveis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: todosSlots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, i) {
                    final slot = todosSlots[i];
                    final bloqueado = excIni != null &&
                        excFim != null &&
                        _intervalosColidem(slot.inicio, slot.fim, excIni, excFim);
                    final selecionado = _sheetHorarioSelecionado == slot.label;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      enabled: !bloqueado,
                      leading: Icon(
                        Icons.access_time,
                        color: bloqueado
                            ? const Color(0xFFCBD5E1)
                            : (selecionado ? _azul : const Color(0xFF64748B)),
                      ),
                      title: Text(
                        slot.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                          color: bloqueado
                              ? const Color(0xFF94A3B8)
                              : (selecionado ? _azul : const Color(0xFF1E293B)),
                          decoration: bloqueado ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: bloqueado
                          ? const Text(
                              'Indisponível neste horário por exceção do profissional',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFFCE4257)),
                            )
                          : null,
                      trailing: selecionado
                          ? const Icon(Icons.check_circle, color: _azul)
                          : (bloqueado
                              ? const Icon(Icons.block, color: Color(0xFFCBD5E1), size: 18)
                              : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1))),
                      onTap: bloqueado
                          ? null
                          : () {
                              setSheetState(() {
                                _sheetHorarioSelecionado = slot.label;
                                _sheetHoraAgendadaSql = slot.horaSql;
                              });
                              setState(() {});
                              Navigator.pop(ctx);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarSolicitacao(ServicoProfissional servico) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Faça login para adicionar um serviço.')),
      );
      return;
    }

    if (_sheetIdUsuario == null) {
      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      _sheetIdUsuario = (usuario?['id_usuario'] as num?)?.toInt();
    }

    if (_sheetIdUsuario == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível identificar o usuário.')),
      );
      return;
    }

    final tipoExecucao = _sheetTipoExecucaoSelecionado ?? 'Leva e Traz';
    final precisaEnderecoCliente = tipoExecucao != 'Retirado no Local' && tipoExecucao != 'Retirada no Local';

    if (precisaEnderecoCliente && _sheetEnderecoClienteSelecionado == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione um endereço para o atendimento.')),
      );
      return;
    }

    if (_sheetDataSelecionada == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione uma data para o agendamento.')),
      );
      return;
    }

    if (_sheetHorarioSelecionado == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione um horário para o agendamento.')),
      );
      return;
    }

    setState(() => _sheetEnviando = true);

    try {
      final valorFinal = servico.valor > 0 ? servico.valor : 18.99;
      final dataAgendadaSql = _formatarDataSql(_sheetDataSelecionada!);
      final horaAgendadaSql = _sheetHoraAgendadaSql ?? '09:00:00';
      final detalhesTexto = _sheetDetalhesController.text.trim().isEmpty
          ? null
          : _sheetDetalhesController.text.trim();

      // 1. Garante a lista_servicos do usuário cliente
      int? idLista;
      final listaExistente = await supabase
          .from('lista_servicos')
          .select('id_lista')
          .eq('fk_usuario', _sheetIdUsuario!)
          .order('id_lista', ascending: false)
          .limit(1)
          .maybeSingle();

      if (listaExistente != null && listaExistente['id_lista'] != null) {
        idLista = (listaExistente['id_lista'] as num).toInt();
      } else {
        final novaLista = await supabase
            .from('lista_servicos')
            .insert({'fk_usuario': _sheetIdUsuario})
            .select('id_lista')
            .single();
        idLista = (novaLista['id_lista'] as num).toInt();
      }

      // 2. Insere/atualiza o serviço em ass_servicos_lista
      final dadosAss = <String, dynamic>{
        'fk_lista': idLista,
        'fk_servico_prof': servico.id,
        'valor_final': valorFinal,
        'tipo_execucao_escolhido': tipoExecucao,
        'fk_endereco_escolhido': _sheetEnderecoClienteSelecionado?.id,
        'detalhes': detalhesTexto,
        'data_agendada': dataAgendadaSql,
        'hora_agendada': horaAgendadaSql,
      };
      await supabase.from('ass_servicos_lista').upsert(dadosAss);

      // 3. Busca o id_status correspondente ao enum 'Serviço' na tabela status
      int idStatus = 1;
      try {
        final statusRow = await supabase
            .from('status')
            .select('id_status')
            .eq('tipo_status', 'Serviço')
            .limit(1)
            .maybeSingle();
        if (statusRow != null && statusRow['id_status'] != null) {
          idStatus = (statusRow['id_status'] as num).toInt();
        }
      } catch (e) {
        debugPrint('Aviso: erro ao buscar status de Serviço: $e');
      }

      // 4. Cria a solicitação na tabela 'solicitacoes'
      final dadosSolicitacao = <String, dynamic>{
        'data_solicitacao': DateTime.now().toUtc().toIso8601String(),
        'data_aceite': null,
        'valor_final': valorFinal,
        'fk_usuario': _sheetIdUsuario,
        'fk_profissional': servico.fkProfissional,
        'fk_status': idStatus,
        'fk_grupo_empresa': servico.fkGrupoEmpresa,
      };

      try {
        await supabase.from('solicitacoes').insert(dadosSolicitacao);
      } catch (e) {
        debugPrint('Erro ao inserir em solicitacoes (tentando com campos de compatibilidade): $e');
        if (e is PostgrestException) {
          // Fallback caso a tabela solicitacoes ainda possua colunas obrigatórias legadas
          final dadosLegados = Map<String, dynamic>.from(dadosSolicitacao)
            ..addAll({
              'fk_servico_prof': servico.id,
              'fk_endereco': _sheetEnderecoClienteSelecionado?.id,
              'tipo_execucao': tipoExecucao,
              'tipo_entrega': tipoExecucao,
              'detalhes': detalhesTexto,
              'data_agendada': dataAgendadaSql,
              'hora_agendada': horaAgendadaSql,
            });
          await supabase.from('solicitacoes').insert(dadosLegados);
        } else {
          rethrow;
        }
      }

      nav.pop(); // Fecha o bottom sheet

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Serviço adicionado à sua lista com sucesso!'),
          backgroundColor: Color(0xFF0FB3FF),
        ),
      );

      // Atualiza a barra flutuante de serviços
      ListaServicosService.instance.atualizar();

      // Redireciona o cliente para a tela ListaServicos
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListaServicos(idUsuario: _sheetIdUsuario),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao adicionar serviço: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sheetEnviando = false);
      }
    }
  }

  IconData _obterIconeMetodo(String tipo) {
    final limpo = tipo.trim().toLowerCase();
    if (limpo.contains('leva') || limpo.contains('traz')) {
      return Icons.two_wheeler_rounded;
    } else if (limpo.contains('retirad') || limpo.contains('local')) {
      return Icons.storefront_outlined;
    } else if (limpo.contains('receba') || limpo.contains('casa')) {
      return Icons.home_outlined;
    } else if (limpo.contains('domic')) {
      return Icons.home_repair_service_outlined;
    }
    return Icons.local_shipping_outlined;
  }

  bool _isDiaDisponivelNaAgenda(DateTime data) {
    if (_sheetAgendasProfissional.isEmpty) {
      return data.weekday >= 1 && data.weekday <= 5;
    }
    const nomes = [
      'segunda',
      'terca',
      'quarta',
      'quinta',
      'sexta',
      'sabado',
      'domingo',
    ];
    final nomeDia = nomes[data.weekday - 1];
    for (final agenda in _sheetAgendasProfissional) {
      final texto = _removerAcentos(agenda['dias_semana']?.toString() ?? '').toLowerCase();
      if (texto.contains(nomeDia)) return true;
    }
    return false;
  }

  String _removerAcentos(String valor) {
    return valor
        .replaceAll('á', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  Map<String, dynamic>? _buscarExcecaoData(DateTime data) {
    final chave = _formatarDataSql(data);
    for (final exc in _sheetExcecoesProfissional) {
      final dia = exc['dia_semana']?.toString();
      if (dia != null && dia.startsWith(chave)) {
        return exc;
      }
    }
    return null;
  }

  bool _isExcecaoDiaInteiro(Map<String, dynamic> exc) {
    final horaIni = exc['hora_ini']?.toString().trim();
    final horaFim = exc['hora_fim']?.toString().trim();
    return horaIni == null ||
        horaFim == null ||
        horaIni.isEmpty ||
        horaFim.isEmpty ||
        horaIni == 'null' ||
        horaFim == 'null';
  }

  String _formatarDataSql(DateTime data) {
    final yyyy = data.year.toString().padLeft(4, '0');
    final mm = data.month.toString().padLeft(2, '0');
    final dd = data.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _formatarDataVisual(DateTime data) {
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    final yyyy = data.year.toString();
    return '$dd/$mm/$yyyy';
  }

  TimeOfDay? _parseTimeOfDay(dynamic raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.toString().trim());
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  int _horaParaMinutos(TimeOfDay time) => time.hour * 60 + time.minute;

  bool _intervalosColidem(TimeOfDay ini1, TimeOfDay fim1, TimeOfDay ini2, TimeOfDay fim2) {
    final mIni1 = _horaParaMinutos(ini1);
    final mFim1 = _horaParaMinutos(fim1);
    final mIni2 = _horaParaMinutos(ini2);
    final mFim2 = _horaParaMinutos(fim2);
    return mIni1 < mFim2 && mFim1 > mIni2;
  }
}

class _EnderecoUsuarioItem {
  final int id;
  final String tipoEndereco;
  final String apelido;
  final String linhaFormatada;
  final bool principal;

  const _EnderecoUsuarioItem({
    required this.id,
    required this.tipoEndereco,
    required this.apelido,
    required this.linhaFormatada,
    this.principal = false,
  });
}

class _OpcaoHorarioItem {
  final String label;
  final String horaSql;
  final TimeOfDay inicio;
  final TimeOfDay fim;

  const _OpcaoHorarioItem({
    required this.label,
    required this.horaSql,
    required this.inicio,
    required this.fim,
  });
}

