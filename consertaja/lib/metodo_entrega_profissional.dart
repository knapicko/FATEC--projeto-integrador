import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MetodoEntregaProfissionalPage extends StatefulWidget {
  const MetodoEntregaProfissionalPage({super.key});

  @override
  State<MetodoEntregaProfissionalPage> createState() =>
      _MetodoEntregaProfissionalPageState();
}

class _OpcaoEntrega {
  const _OpcaoEntrega({
    required this.valor,
    required this.titulo,
    required this.descricao,
    required this.icone,
  });

  final String valor;
  final String titulo;
  final String descricao;
  final IconData icone;
}

class _MetodoEntregaProfissionalPageState
    extends State<MetodoEntregaProfissionalPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _textMuted = Color(0xFF7D8595);
  static const Color _cardBorder = Color(0xFFE7EBF0);
  static const Color _cardFill = Color(0xFFF5F8FB);

  static const List<_OpcaoEntrega> _opcoesEntrega = [
    _OpcaoEntrega(
      valor: 'Leva e Traz',
      titulo: 'Leva e Traz',
      descricao: 'Busco no cliente e entrego de volta.',
      icone: Icons.local_shipping_outlined,
    ),
    _OpcaoEntrega(
      valor: 'Retirado no Local',
      titulo: 'Retirada no Local',
      descricao: 'O cliente traz o item até mim e vem buscar depois.',
      icone: Icons.storefront_outlined,
    ),
    _OpcaoEntrega(
      valor: 'Receba em Casa',
      titulo: 'Receba em Casa',
      descricao: 'O cliente traz o item até mim, mas eu faço a entrega final.',
      icone: Icons.home_outlined,
    ),
    _OpcaoEntrega(
      valor: 'Atendimento em Domicílio',
      titulo: 'Atendimento em Domicílio',
      descricao: 'Vou até o endereço do cliente para realizar o serviço.',
      icone: Icons.home_repair_service_outlined,
    ),
  ];

  final Set<String> _selecionadas = <String>{};
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  Future<void> _carregarPreferencias() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        _selecionadas.add('Leva e Traz');
        if (mounted) {
          setState(() => _carregando = false);
        }
        return;
      }

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      final usuarioId = (usuario?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) {
        _selecionadas.add('Leva e Traz');
        if (mounted) {
          setState(() => _carregando = false);
        }
        return;
      }

      final dados = await supabase
          .from('dados_profissionais')
          .select('metodo_entrega')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      final itensSalvos = _parseMetodoEntrega(dados?['metodo_entrega'] as String?);
      if (itensSalvos.isEmpty) {
        _selecionadas.add('Leva e Traz');
      } else {
        _selecionadas.addAll(itensSalvos);
      }
    } catch (_) {
      _selecionadas.add('Leva e Traz');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  List<String> _parseMetodoEntrega(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String>[];

    final itens = raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return itens;
  }

  void _toggleOpcao(String valor) {
    setState(() {
      if (_selecionadas.contains(valor)) {
        _selecionadas.remove(valor);
      } else {
        _selecionadas.add(valor);
      }

      if (_selecionadas.isEmpty) {
        _selecionadas.add('Leva e Traz');
      }
    });
  }

  Future<void> _salvarPreferencias() async {
    if (_salvando) return;

    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      final usuarioId = (usuario?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) {
        throw Exception('Não foi possível localizar o profissional.');
      }

      final itens = _selecionadas.toList()
        ..sort((a, b) => _ordemValor(a).compareTo(_ordemValor(b)));

      final valorFinal = itens.join(', ');

      await supabase
          .from('dados_profissionais')
          .update({'metodo_entrega': valorFinal})
          .eq('fk_usuario', usuarioId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferências de entrega salvas com sucesso.')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  int _ordemValor(String valor) {
    final ordem = {
      'Leva e Traz': 1,
      'Retirado no Local': 2,
      'Receba em Casa': 3,
      'Atendimento em Domicílio': 4,
    };
    return ordem[valor] ?? 99;
  }

  Widget _buildCheckBox(bool marcado) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: marcado ? _primaryBlue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: marcado ? _primaryBlue : const Color(0xFFB8C1CC),
          width: 1.5,
        ),
      ),
      child: marcado
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildOpcaoEntrega(_OpcaoEntrega opcao) {
    final selecionada = _selecionadas.contains(opcao.valor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleOpcao(opcao.valor),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selecionada ? const Color(0xFFEAF8FF) : _cardFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionada ? _primaryBlue.withValues(alpha: 0.6) : _cardBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _buildCheckBox(selecionada),
              ),
              const SizedBox(width: 12),
              Icon(
                opcao.icone,
                color: _primaryBlue,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opcao.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: _titleDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opcao.descricao,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryBlue),
          splashRadius: 20,
        ),
        centerTitle: true,
        title: const Text(
          'Métodos de Entrega',
          style: TextStyle(
            color: _primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Configurações de Atendimento\ne Entrega',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _titleDark,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Como os clientes podem enviar ou receber os serviços com você?',
                            style: TextStyle(
                              fontSize: 18,
                              color: _textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '(Nota: Você pode selecionar mais de uma opção)',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ..._opcoesEntrega
                              .where((opcao) => opcao.valor != 'Atendimento em Domicílio')
                              .map((opcao) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildOpcaoEntrega(opcao),
                                  )),
                          const SizedBox(height: 12),
                          const Text(
                            '(Nota: Marque esta opção se o seu trabalho exige ir até o cliente)',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOpcaoEntrega(
                              _opcoesEntrega.firstWhere(
                                (opcao) => opcao.valor == 'Atendimento em Domicílio',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20, top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _salvando ? null : _salvarPreferencias,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.save_alt_rounded, size: 20),
                              label: const Text(
                                'Salvar Preferências',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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
