import 'package:flutter/material.dart';

class _FaqItem {
  final String pergunta;
  final String resposta;

  const _FaqItem({required this.pergunta, required this.resposta});
}

class _FaqCategoria {
  final String nome;
  final List<_FaqItem> itens;

  const _FaqCategoria({required this.nome, required this.itens});
}

class PerguntasFrequentesPage extends StatefulWidget {
  const PerguntasFrequentesPage({super.key});

  @override
  State<PerguntasFrequentesPage> createState() =>
      _PerguntasFrequentesPageState();
}

class _PerguntasFrequentesPageState extends State<PerguntasFrequentesPage> {
  static const Color _blue = Color(0xFF0A6E9D);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _chipActiveBg = Color(0xFFE8EEF5);
  static const Color _chipBorder = Color(0xFFE0E0E0);

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';
  int _categoriaSelecionada = 0;
  int? _itemExpandido;

  static const List<_FaqCategoria> _categorias = [
    _FaqCategoria(
      nome: 'Dúvidas Comuns',
      itens: [
        _FaqItem(
          pergunta: 'Como contratar um profissional?',
          resposta:
              'Basta navegar ou pesquisar pelo serviço que você precisa. '
              'Assim que encontrar um profissional adequado, veja o perfil dele, '
              'verifique a disponibilidade e clique no botão "Agendar Agora" '
              'para marcar um horário.',
        ),
        _FaqItem(
          pergunta: 'Como pago pelo serviço?',
          resposta:
              'O pagamento é realizado de forma segura pela plataforma. '
              'Você pode escolher entre cartão de crédito, débito ou PIX '
              'no momento da confirmação do agendamento.',
        ),
        _FaqItem(
          pergunta: 'É seguro usar a plataforma?',
          resposta:
              'Sim! Todos os profissionais passam por verificação de documentos '
              'e avaliações de outros clientes. Seus dados e pagamentos são '
              'protegidos com criptografia de ponta a ponta.',
        ),
        _FaqItem(
          pergunta: 'Como me tornar um prestador de serviços?',
          resposta:
              'Acesse a tela de cadastro de profissional, preencha seus dados, '
              'envie os documentos necessários e aguarde a validação. '
              'Após validado, você já pode acessar sua conta de profissional.',
        ),
      ],
    ),
    _FaqCategoria(
      nome: 'Para Profissionais',
      itens: [
        _FaqItem(
          pergunta: 'Como recebo pelos serviços realizados?',
          resposta:
              'Os valores são transferidos para a conta cadastrada em até 3 dias úteis '
              'após a conclusão e confirmação do serviço pelo cliente.',
        ),
        _FaqItem(
          pergunta: 'Como ajusto minha disponibilidade?',
          resposta:
              'No seu perfil, acesse "Ajustar Disponibilidade" e defina os dias '
              'e horários em que você está disponível para atender.',
        ),
        _FaqItem(
          pergunta: 'Como funciona a avaliação do meu perfil?',
          resposta:
              'Após cada serviço concluído, o cliente pode avaliar seu atendimento. '
              'Boas avaliações aumentam sua visibilidade na plataforma.',
        ),
      ],
    ),
    _FaqCategoria(
      nome: 'Pagamentos',
      itens: [
        _FaqItem(
          pergunta: 'Quais formas de pagamento são aceitas?',
          resposta:
              'Aceitamos cartão de crédito, cartão de débito e PIX. '
              'Todas as transações são processadas de forma segura.',
        ),
        _FaqItem(
          pergunta: 'Posso cancelar e receber reembolso?',
          resposta:
              'Sim. Cancelamentos feitos com mais de 24 horas de antecedência '
              'geram reembolso integral. Consulte nossos Termos de Uso para '
              'mais detalhes.',
        ),
        _FaqItem(
          pergunta: 'O pagamento é feito antes ou depois do serviço?',
          resposta:
              'O pagamento é autorizado no momento do agendamento e cobrado '
              'apenas após a confirmação de conclusão do serviço.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _itemExpandido = 0;
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _itensFiltrados {
    final itens = _categorias[_categoriaSelecionada].itens;
    if (_termoBusca.trim().isEmpty) return itens;
    final termo = _termoBusca.toLowerCase();
    return itens
        .where(
          (item) =>
              item.pergunta.toLowerCase().contains(termo) ||
              item.resposta.toLowerCase().contains(termo),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itensFiltrados;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildTituloBoasVindas(),
                  const SizedBox(height: 20),
                  _buildBarraPesquisa(),
                  const SizedBox(height: 20),
                  _buildChipsCategorias(),
                  const SizedBox(height: 20),
                  ...List.generate(itens.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildFaqCard(
                        item: itens[index],
                        expandido: _itemExpandido == index,
                        onTap: () {
                          setState(() {
                            _itemExpandido =
                                _itemExpandido == index ? null : index;
                          });
                        },
                      ),
                    );
                  }),
                  if (itens.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Nenhum artigo encontrado.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _buildBannerSuporte(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: _blue, size: 24),
          ),
          const Text(
            'Central de Ajuda',
            style: TextStyle(
              color: _blue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTituloBoasVindas() {
    return const Text(
      'Como podemos ajudar?',
      style: TextStyle(
        color: _blue,
        fontSize: 26,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
    );
  }

  Widget _buildBarraPesquisa() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _buscaController,
        onChanged: (value) => setState(() {
          _termoBusca = value;
          _itemExpandido = null;
        }),
        style: const TextStyle(fontSize: 15, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Pesquisar artigos...',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade400,
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildChipsCategorias() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categorias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final ativo = index == _categoriaSelecionada;
          return GestureDetector(
            onTap: () {
              setState(() {
                _categoriaSelecionada = index;
                _itemExpandido = 0;
                _termoBusca = '';
                _buscaController.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: ativo ? _chipActiveBg : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: ativo
                    ? null
                    : Border.all(color: _chipBorder, width: 1),
              ),
              child: Text(
                _categorias[index].nome,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFaqCard({
    required _FaqItem item,
    required bool expandido,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.pergunta,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      expandido
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                  ],
                ),
                if (expandido) ...[
                  const SizedBox(height: 12),
                  Text(
                    item.resposta,
                    style: const TextStyle(
                      color: _textGray,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSuporte() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D7AAF),
            Color(0xFF0A6E9D),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headset_mic_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ainda precisa de ajuda?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nossa equipe de suporte está disponível 24h para ajudar com qualquer dúvida.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Em breve você poderá contatar o suporte.'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _blue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Contatar Suporte',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
