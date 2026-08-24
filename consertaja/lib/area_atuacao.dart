import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _tagController = TextEditingController();

  static const List<Color> _coresPreset = [
    Color(0xFF1A3A5C),
    Color(0xFF0FB3FF),
    Color(0xFF6D4C41),
    Color(0xFF424242),
  ];

  bool _carregando = true;
  bool _salvando = false;
  List<Map<String, dynamic>> _oficiosDisponiveis = [];
  final List<Map<String, dynamic>> _oficiosSelecionados = [];
  int? _idProfissional;
  int? _idPerfil;
  bool _ehLoja = false;
  Color _corTagSelecionada = _coresPreset.first;

  @override
  void initState() {
    super.initState();
    _tagController.addListener(() => setState(() {}));
    _carregarDados();
  }

  @override
  void dispose() {
    _tagController.dispose();
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

  Color _corFromHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return _coresPreset.first;
    var value = hex.trim().replaceAll('#', '');
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return _coresPreset.first;
    return Color(parsed);
  }

  String _corParaHex(Color color) {
    return '0xFF${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Color _corContraste(Color c) {
    final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return lum > 0.55 ? Colors.black : Colors.white;
  }

  Color get _corTextoTag => _corContraste(_corTagSelecionada);

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final oficiosResponse = await _supabase
          .from('oficios')
          .select('id_oficio, funcao')
          .order('funcao');

      _oficiosDisponiveis = List<Map<String, dynamic>>.from(oficiosResponse);

      final usuarioId = await _buscarIdUsuario(user.id);
      if (usuarioId == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      Map<String, dynamic>? dadosProf;
      try {
        dadosProf = await _supabase
            .from('dados_profissionais')
            .select(
              'id_profissional, fk_perfil, tag_personalizada, cor_tag',
            )
            .eq('fk_usuario', usuarioId)
            .maybeSingle();
      } catch (_) {
        try {
          dadosProf = await _supabase
              .from('dados_profissionais')
              .select('id_profissional, fk_perfil, tag_loja')
              .eq('fk_usuario', usuarioId)
              .maybeSingle();
        } catch (_) {
          dadosProf = await _supabase
              .from('dados_profissionais')
              .select('id_profissional, fk_perfil')
              .eq('fk_usuario', usuarioId)
              .maybeSingle();
        }
      }

      if (dadosProf != null) {
        _idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
        _idPerfil = (dadosProf['fk_perfil'] as num?)?.toInt();
        final tag = dadosProf['tag_personalizada']?.toString() ?? dadosProf['tag_loja']?.toString() ?? '';
        if (tag.isNotEmpty && tag != 'null') {
          _tagController.text = tag.toUpperCase();
        }
        final corTag = dadosProf['cor_tag']?.toString();
        if (corTag != null && corTag.isNotEmpty && corTag != 'null') {
          _corTagSelecionada = _corFromHex(corTag);
        }
      }

      if (_idPerfil != null) {
        try {
          final perfil = await _supabase
              .from('perfil')
              .select('tipo_perfil, tag_loja, cor_tag')
              .eq('id_perfil', _idPerfil!)
              .maybeSingle();
          if (perfil != null) {
            _ehLoja = perfil['tipo_perfil']?.toString() == 'Loja';
            if (_tagController.text.isEmpty) {
              final tagPerfil = perfil['tag_loja']?.toString() ?? '';
              if (tagPerfil.isNotEmpty && tagPerfil != 'null') {
                _tagController.text = tagPerfil.toUpperCase();
              }
            }
            final corPerfil = perfil['cor_tag']?.toString();
            if (corPerfil != null && corPerfil.isNotEmpty && corPerfil != 'null') {
              _corTagSelecionada = _corFromHex(corPerfil);
            }
          }
        } catch (_) {
          // Colunas tag_loja/cor_tag podem não existir ainda.
          try {
            final perfil = await _supabase
                .from('perfil')
                .select('tipo_perfil')
                .eq('id_perfil', _idPerfil!)
                .maybeSingle();
            _ehLoja = perfil?['tipo_perfil']?.toString() == 'Loja';
          } catch (_) {}
        }
      }

      if (_idProfissional != null) {
        final associacoes = await _supabase
            .from('ass_oficio_profissional')
            .select('fk_oficio')
            .eq('fk_profissional', _idProfissional!);

        final idsOficios = associacoes
            .map((e) => (e['fk_oficio'] as num?)?.toInt())
            .whereType<int>()
            .toList();

        _oficiosSelecionados.clear();
        for (final id in idsOficios) {
          final oficio = _oficiosDisponiveis.firstWhere(
            (o) => (o['id_oficio'] as num?)?.toInt() == id,
            orElse: () => <String, dynamic>{},
          );
          if (oficio.isNotEmpty) _oficiosSelecionados.add(oficio);
        }
      }

      if (mounted) setState(() => _carregando = false);
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  IconData _iconeParaOficio(String funcao) {
    final f = funcao.toLowerCase();
    if (f.contains('elétric') || f.contains('eletric')) {
      return Icons.bolt;
    }
    if (f.contains('hidrául') || f.contains('hidraul')) {
      return Icons.plumbing;
    }
    if (f.contains('pint')) return Icons.format_paint_outlined;
    if (f.contains('marcen') || f.contains('madeir')) {
      return Icons.carpenter_outlined;
    }
    if (f.contains('chave')) return Icons.vpn_key_outlined;
    if (f.contains('inform') || f.contains('ti')) {
      return Icons.computer_outlined;
    }
    return Icons.handyman_outlined;
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
        final atual =
            (_oficiosSelecionados[slotIndex]['id_oficio'] as num?)?.toInt();
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
                  'Selecione uma área',
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
                        leading: Icon(
                          _iconeParaOficio(nome),
                          color: _blue,
                        ),
                        title: Text(nome),
                        onTap: () {
                          setState(() {
                            if (slotIndex < _oficiosSelecionados.length) {
                              _oficiosSelecionados[slotIndex] = oficio;
                            } else {
                              _oficiosSelecionados.add(oficio);
                            }
                          });
                          Navigator.pop(context);
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
                    setState(() => _oficiosSelecionados.removeAt(slotIndex));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirSeletorCorCustomizada() async {
    final corEscolhida = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        corInicial: _corTagSelecionada,
      ),
    );

    if (corEscolhida != null) {
      setState(() => _corTagSelecionada = corEscolhida);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (_idProfissional == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil profissional não encontrado.'),
        ),
      );
      return;
    }

    if (_oficiosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma área de atuação.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      await _supabase
          .from('ass_oficio_profissional')
          .delete()
          .eq('fk_profissional', _idProfissional!);

      for (final oficio in _oficiosSelecionados) {
        final idOficio = (oficio['id_oficio'] as num?)?.toInt();
        if (idOficio == null) continue;
        await _supabase.from('ass_oficio_profissional').insert({
          'fk_profissional': _idProfissional,
          'fk_oficio': idOficio,
        });
      }

      final tag = _tagController.text.trim().toUpperCase();
      // Salva a tag e cor na tabela perfil (colunas tag_loja e cor_tag)
      if (_ehLoja && _idPerfil != null) {
        try {
          await _supabase.from('perfil').update({
            'tag_loja': tag.isEmpty ? null : tag,
            'cor_tag': _corParaHex(_corTagSelecionada),
          }).eq('id_perfil', _idPerfil!);
        } catch (_) {
          // Colunas tag_loja/cor_tag podem não existir ainda.
        }
      }
      // Mantém compatibilidade com a coluna antiga em dados_profissionais
      try {
        await _supabase.from('dados_profissionais').update({
          'tag_personalizada': tag.isEmpty ? null : tag,
          'cor_tag': _corParaHex(_corTagSelecionada),
        }).eq('id_profissional', _idProfissional!);
      } catch (_) {
        // Campos de tag podem não existir ainda no banco.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String get _textoTagPreview {
    final texto = _tagController.text.trim().toUpperCase();
    return texto.isEmpty ? 'EXEMP' : texto;
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
          const SizedBox(width: 48),
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
              final temOficio = index < _oficiosSelecionados.length;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => _abrirSeletorOficio(index),
                    child: temOficio
                        ? _buildCardOficioSelecionado(
                            _oficiosSelecionados[index]['funcao']
                                    ?.toString() ??
                                '',
                          )
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

  Widget _buildCardOficioSelecionado(String nome) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: _cardBlueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue, width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 13),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconeParaOficio(nome), color: _blue, size: 30),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardVazio() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: Colors.grey.shade300,
        strokeWidth: 1.5,
        radius: 12,
      ),
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade400, size: 28),
            const SizedBox(height: 8),
            Text(
              'Vazio',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTagPersonalizada() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sua Tag Personalizada',
            style: TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crie uma tag curta para facilitar que clientes te encontrem. Máximo 5 letras.',
            style: TextStyle(
              color: _textGray,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, right: 4),
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: _textGray,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    maxLength: 5,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'EXEMP',
                      hintStyle: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      final upper = value.toUpperCase();
                      if (upper != value) {
                        _tagController.value = _tagController.value.copyWith(
                          text: upper,
                          selection: TextSelection.collapsed(
                            offset: upper.length,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'COR DA TAG',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._coresPreset.map((cor) => _buildSwatchCor(cor)),
              _buildSwatchCustomizada(),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VISUALIZAÇÃO',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _corTagSelecionada,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#$_textoTagPreview',
                    style: TextStyle(
                      color: _corTextoTag,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildSwatchCor(Color cor) {
    final selecionada = _corTagSelecionada.toARGB32() == cor.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _corTagSelecionada = cor),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: selecionada
              ? Border.all(color: _textDark, width: 2)
              : Border.all(color: Colors.grey.shade300),
        ),
        child: selecionada
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildSwatchCustomizada() {
    return GestureDetector(
      onTap: _abrirSeletorCorCustomizada,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.white, size: 18),
        ),
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

  Widget _buildBotaoSalvar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _salvando ? null : _salvarAlteracoes,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            disabledBackgroundColor: _blue.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Salvar Alterações',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: _blue,
                        size: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  bool get _mostrarTagPersonalizada => _ehLoja;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSecaoEscolha(),
                          if (_mostrarTagPersonalizada)
                            _buildCardTagPersonalizada(),
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

class _ColorPickerDialog extends StatefulWidget {
  final Color corInicial;

  const _ColorPickerDialog({required this.corInicial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _cor;

  @override
  void initState() {
    super.initState();
    _cor = widget.corInicial;
  }

  void _atualizarCor(Color nova) {
    setState(() => _cor = nova);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escolher cor'),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _cor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 16),
              _ColorizSliderHue(cor: _cor, onChanged: _atualizarCor),
              const SizedBox(height: 12),
              _ColorizSliderSaturacao(cor: _cor, onChanged: _atualizarCor),
              const SizedBox(height: 12),
              _ColorizSliderBrilho(cor: _cor, onChanged: _atualizarCor),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'HEX: #${_cor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _cor),
          style: ElevatedButton.styleFrom(
            backgroundColor: _cor,
            foregroundColor: _cor.computeLuminance() > 0.55
                ? Colors.black
                : Colors.white,
          ),
          child: const Text('Selecionar'),
        ),
      ],
    );
  }
}

class _ColorizSliderHue extends StatefulWidget {
  final Color cor;
  final ValueChanged<Color> onChanged;

  const _ColorizSliderHue({required this.cor, required this.onChanged});

  @override
  State<_ColorizSliderHue> createState() => _ColorizSliderHueState();
}

class _ColorizSliderHueState extends State<_ColorizSliderHue> {
  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.cor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MATIZ',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.6),
        ),
        const SizedBox(height: 4),
        Container(
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 22,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: (hsl.hue / 360).clamp(0.0, 1.0),
              onChanged: (v) {
                widget.onChanged(
                  HSLColor.fromAHSL(
                    1.0,
                    v * 360,
                    hsl.saturation,
                    hsl.lightness,
                  ).toColor(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorizSliderSaturacao extends StatefulWidget {
  final Color cor;
  final ValueChanged<Color> onChanged;

  const _ColorizSliderSaturacao({required this.cor, required this.onChanged});

  @override
  State<_ColorizSliderSaturacao> createState() => _ColorizSliderSaturacaoState();
}

class _ColorizSliderSaturacaoState extends State<_ColorizSliderSaturacao> {
  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.cor);
    final base = HSLColor.fromAHSL(hsl.alpha, hsl.hue, 1.0, hsl.lightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SATURAÇÃO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.6),
        ),
        const SizedBox(height: 4),
        Container(
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [Colors.grey.shade300, base.toColor()],
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 22,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: hsl.saturation.clamp(0.0, 1.0),
              onChanged: (v) {
                widget.onChanged(
                  HSLColor.fromAHSL(hsl.alpha, hsl.hue, v, hsl.lightness).toColor(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorizSliderBrilho extends StatefulWidget {
  final Color cor;
  final ValueChanged<Color> onChanged;

  const _ColorizSliderBrilho({required this.cor, required this.onChanged});

  @override
  State<_ColorizSliderBrilho> createState() => _ColorizSliderBrilhoState();
}

class _ColorizSliderBrilhoState extends State<_ColorizSliderBrilho> {
  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.cor);
    final corHsl = HSLColor.fromAHSL(hsl.alpha, hsl.hue, hsl.saturation, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BRILHO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.6),
        ),
        const SizedBox(height: 4),
        Container(
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(colors: [Colors.black, corHsl.toColor(), Colors.white]),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 22,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: hsl.lightness.clamp(0.0, 1.0),
              onChanged: (v) {
                widget.onChanged(
                  HSLColor.fromAHSL(hsl.alpha, hsl.hue, hsl.saturation, v).toColor(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
