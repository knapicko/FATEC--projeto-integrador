import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models/servico_profissional.dart';
import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'services/servicos_profissional_service.dart';
import 'solicitar_servico.dart';
import 'tela_chat_profissional.dart';
import 'utils/cor_oficio.dart';
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

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  // Carrossel de imagens (4 slides com suporte ao swiping)
  Widget _buildCarrossel(ServicoProfissional servico) {
    final List<String?> slides = [
      servico.imagemUrl,
      null,
      null,
      null,
    ];
    const total = 4;

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
              final url = slides[index];
              if (url != null && _ehUrl(url)) {
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderImagem(),
                );
              }
              return _placeholderImagem();
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
                    child: const Text(
                      'Área Central & Zona Norte / Sul',
                      style: TextStyle(
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

  Widget _buildDisponivelEnderecoEstatico() {
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Casa',
                      style: TextStyle(
                        color: _azul,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.edit, color: _azul, size: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Travessa Doutor Eduardo Maffei, 87, Casa 3, SP, São Paulo, 02557-121',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF334155),
              height: 1.3,
            ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SolicitarServicoPage(
                          idProfissional: servico.fkProfissional,
                          servicos: [servico],
                        ),
                      ),
                    );
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
}
