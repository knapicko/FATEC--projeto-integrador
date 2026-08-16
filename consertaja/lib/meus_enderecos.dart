import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'tela_meu_perfil_profissional.dart';

class _EnderecoItem {
  final String titulo;
  final IconData icone;
  final String linha1;
  final String? linha2;
  final String? linha3;
  final String? cep;
  final bool exibirMapa;

  const _EnderecoItem({
    required this.titulo,
    required this.icone,
    required this.linha1,
    this.linha2,
    this.linha3,
    this.cep,
    this.exibirMapa = false,
  });
}

class MeusEnderecosPage extends StatefulWidget {
  final bool isVisitante;
  final bool isProfissional;

  const MeusEnderecosPage({
    super.key,
    this.isVisitante = false,
    this.isProfissional = false,
  });

  @override
  State<MeusEnderecosPage> createState() => _MeusEnderecosPageState();
}

class _MeusEnderecosPageState extends State<MeusEnderecosPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _iconGray = Color(0xFF878B8D);
  static const Color _iconCircleGray = Color(0xFFF0F0F0);

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  static const _EnderecoItem _enderecoPrincipal = _EnderecoItem(
    titulo: 'CASA',
    icone: Icons.home_rounded,
    linha1: 'Rua das Flores, 123',
    linha2: 'Apto 45 - Bloco B',
    linha3: 'Jardim Botânico, São Paulo - SP',
    cep: '01234-567',
    exibirMapa: true,
  );

  static const List<_EnderecoItem> _outrosEnderecos = [
    _EnderecoItem(
      titulo: 'TRABALHO',
      icone: Icons.work_outline_rounded,
      linha1: 'Av. Paulista, 1000',
      linha2: 'Conjunto 101',
      linha3: 'Bela Vista, São Paulo - SP',
    ),
    _EnderecoItem(
      titulo: 'CASA DE PRAIA',
      icone: Icons.location_on_outlined,
      linha1: 'Av. Beira Mar, 500',
      linha3: 'Guarujá - SP',
    ),
  ];

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  PageRouteBuilder<T> _rotaSemAnimacao<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  bool _correspondeBusca(_EnderecoItem endereco) {
    if (_termoBusca.trim().isEmpty) return true;
    final termo = _termoBusca.toLowerCase();
    final campos = [
      endereco.titulo,
      endereco.linha1,
      endereco.linha2 ?? '',
      endereco.linha3 ?? '',
      endereco.cep ?? '',
    ];
    return campos.any((campo) => campo.toLowerCase().contains(termo));
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      backgroundColor: _blue,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
      ),
      title: const Text(
        'Meus Endereços',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBarraPesquisa() {
    return Container(
      color: _background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _buscaController,
          onChanged: (value) => setState(() => _termoBusca = value),
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: InputDecoration(
            hintText: 'Buscar endereço',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Text(
        titulo,
        style: const TextStyle(
          color: _textDark,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIconeEndereco({
    required IconData icone,
    required bool principal,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _iconCircleGray,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icone,
        color: principal ? _blue : _iconGray,
        size: 22,
      ),
    );
  }

  Widget _buildLinhasEndereco(_EnderecoItem endereco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          endereco.linha1,
          style: const TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        if (endereco.linha2 != null)
          Text(
            endereco.linha2!,
            style: const TextStyle(
              color: _textGray,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        if (endereco.linha3 != null)
          Text(
            endereco.linha3!,
            style: const TextStyle(
              color: _textGray,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        if (endereco.cep != null)
          Text(
            endereco.cep!,
            style: const TextStyle(
              color: _textGray,
              fontSize: 14,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  Widget _buildMapaMiniatura() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _MapaPlaceholderPainter(),
              child: Container(
                color: const Color(0xFFE8EDE8),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined, color: _blue, size: 18),
                SizedBox(width: 6),
                Text(
                  'Ver no mapa',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardPrincipal(_EnderecoItem endereco) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconeEndereco(icone: endereco.icone, principal: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  endereco.titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.edit_outlined, color: Colors.grey.shade500, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLinhasEndereco(endereco),
          if (endereco.exibirMapa) ...[
            const SizedBox(height: 14),
            _buildMapaMiniatura(),
          ],
        ],
      ),
    );
  }

  Widget _buildCardOutroEndereco(_EnderecoItem endereco) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconeEndereco(icone: endereco.icone, principal: false),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  endereco.titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLinhasEndereco(endereco),
        ],
      ),
    );
  }

  Widget _buildBotaoAdicionar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: CustomPaint(
        painter: _BordaTracejadaPainter(color: _blue.withValues(alpha: 0.5)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdicionarEnderecoPage(
                  isVisitante: widget.isVisitante,
                  isProfissional: widget.isProfissional,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: _blue,
                      size: 36,
                    ),
                    Positioned(
                      top: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: _blue,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adicionar Novo Endereço',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerfilIcon() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _blue.withValues(alpha: 0.12),
      ),
      child: Icon(
        widget.isProfissional ? Icons.person : Icons.account_circle,
        color: _blue,
        size: 22,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: _blue,
        unselectedItemColor: const Color(0xFF8F8F8F),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 4,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).pushReplacement(
                _rotaSemAnimacao(
                  widget.isProfissional
                      ? TelaHomeProfissional(isVisitante: widget.isVisitante)
                      : TelaHome(isVisitante: widget.isVisitante),
                ),
              );
              break;
            case 4:
              Navigator.of(context).pushReplacement(
                _rotaSemAnimacao(
                  widget.isProfissional
                      ? TelaMeuPerfilProfissionalPage(
                          isVisitante: widget.isVisitante,
                        )
                      : TelaMeuPerfilClientePage(
                          isVisitante: widget.isVisitante,
                        ),
                ),
              );
              break;
          }
        },
        items: widget.isProfissional
            ? [
                const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                const BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Radar'),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Mensagens',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.archive_outlined),
                  label: 'Pedidos',
                ),
                BottomNavigationBarItem(
                  icon: _buildPerfilIcon(),
                  label: 'Perfil',
                ),
              ]
            : [
                const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  label: 'Seguindo',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Mensagens',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: 'Pedidos',
                ),
                BottomNavigationBarItem(
                  icon: _buildPerfilIcon(),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exibirPrincipal = _correspondeBusca(_enderecoPrincipal);
    final outrosFiltrados =
        _outrosEnderecos.where(_correspondeBusca).toList();

    return Scaffold(
      backgroundColor: _background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(),
      ),
      body: Column(
        children: [
          _buildBarraPesquisa(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (exibirPrincipal) ...[
                  _buildTituloSecao('Endereço Principal'),
                  _buildCardPrincipal(_enderecoPrincipal),
                  const SizedBox(height: 20),
                ],
                if (outrosFiltrados.isNotEmpty) ...[
                  _buildTituloSecao('Outros Endereços'),
                  ...outrosFiltrados.map(_buildCardOutroEndereco),
                ],
                if (!exibirPrincipal && outrosFiltrados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nenhum endereço encontrado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    ),
                  ),
                _buildBotaoAdicionar(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class AdicionarEnderecoPage extends StatefulWidget {
  final bool isVisitante;
  final bool isProfissional;

  const AdicionarEnderecoPage({
    super.key,
    this.isVisitante = false,
    this.isProfissional = false,
  });

  @override
  State<AdicionarEnderecoPage> createState() => _AdicionarEnderecoPageState();
}

class _AdicionarEnderecoPageState extends State<AdicionarEnderecoPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _labelGray = Color(0xFF4A4A4A);
  static const Color _inputFill = Color(0xFFF5F5F5);

  static const List<String> _estados = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
    'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
    'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
  ];

  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _logradouroController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _complementoController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();

  String? _estadoSelecionado;
  String _tipoSalvar = 'Casa';

  @override
  void dispose() {
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  void _buscarCep() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Busca de CEP em desenvolvimento.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _salvarEndereco() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Endereço salvo com sucesso!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: _inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: _labelGray,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCampo({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(color: _textDark, fontSize: 14),
            decoration: _inputDecoration(hint),
          ),
        ],
      ),
    );
  }

  Widget _buildMapaPreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _MapaCidadePainter(),
                child: Container(color: const Color(0xFFE4EBE4)),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _blue,
                      size: 42,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'São Paulo',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Ajustar no mapa',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoCep() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('CEP'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cepController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CepInputFormatter()],
                  style: const TextStyle(color: _textDark, fontSize: 14),
                  decoration: _inputDecoration('00000-000'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _buscarCep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(
                    'Buscar',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoEstado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Estado'),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _estadoSelecionado,
              isExpanded: true,
              hint: Text(
                'UF',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
              style: const TextStyle(color: _textDark, fontSize: 14),
              items: _estados
                  .map(
                    (uf) => DropdownMenuItem<String>(
                      value: uf,
                      child: Text(uf),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _estadoSelecionado = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipTipo(String label) {
    final selecionado = _tipoSalvar == label;
    return GestureDetector(
      onTap: () => setState(() => _tipoSalvar = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selecionado ? _blue : Colors.grey.shade300,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? _blue : _labelGray,
            fontSize: 14,
            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCampoCep(),
          _buildCampo(
            label: 'Logradouro',
            controller: _logradouroController,
            hint: 'Ex: Rua das Flores',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildCampo(
                  label: 'Número',
                  controller: _numeroController,
                  hint: '123',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildCampo(
                  label: 'Complemento (Opcional)',
                  controller: _complementoController,
                  hint: 'Apto, Sala, Bloco...',
                ),
              ),
            ],
          ),
          _buildCampo(
            label: 'Bairro',
            controller: _bairroController,
            hint: 'Ex: Centro',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCampo(
                  label: 'Cidade',
                  controller: _cidadeController,
                  hint: 'Sua Cidade',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCampoEstado(),
                ),
              ),
            ],
          ),
          _buildLabel('Salvar como'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildChipTipo('Casa'),
              _buildChipTipo('Trabalho'),
              _buildChipTipo('Outro'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: _textDark),
        ),
        title: const Text(
          'Adicionar Endereço',
          style: TextStyle(
            color: _textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMapaPreview(),
                  _buildFormulario(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Container(
            color: _background,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _salvarEndereco,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Salvar Endereço',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _MapaCidadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = const Color(0xFFDCE3DC);
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const blockSize = 28.0;
    for (var x = 0.0; x < size.width; x += blockSize) {
      for (var y = 0.0; y < size.height; y += blockSize) {
        if ((x / blockSize + y / blockSize).toInt().isEven) {
          canvas.drawRect(
            Rect.fromLTWH(x + 1, y + 1, blockSize - 2, blockSize - 2),
            blockPaint,
          );
        }
      }
    }

    for (var x = 0.0; x <= size.width; x += blockSize * 2) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (var y = 0.0; y <= size.height; y += blockSize * 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }

    final avenuePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.35, size.height),
      avenuePaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.5),
      avenuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapaPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = const Color(0xFF0FB3FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPath = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.45);

    final routePath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.2,
        size.width * 0.85,
        size.height * 0.55,
      );

    canvas.drawPath(roadPath, roadPaint);
    canvas.drawPath(routePath, routePaint);

    final pinPaint = Paint()..color = const Color(0xFF0FB3FF);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.55), 6, pinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BordaTracejadaPainter extends CustomPainter {
  final Color color;

  _BordaTracejadaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordaTracejadaPainter oldDelegate) =>
      oldDelegate.color != color;
}
