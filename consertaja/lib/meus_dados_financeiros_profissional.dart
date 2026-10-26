import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gestao_equipe.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/bottom_navigation_bar_profissional.dart';

class MeusDadosFinanceirosProfissionalPage extends StatefulWidget {
  const MeusDadosFinanceirosProfissionalPage({super.key});

  @override
  State<MeusDadosFinanceirosProfissionalPage> createState() =>
      _MeusDadosFinanceirosProfissionalPageState();
}

class _MeusDadosFinanceirosProfissionalPageState
    extends State<MeusDadosFinanceirosProfissionalPage>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBg = Colors.white;
  static const Color _borderLight = Color(0xFFF1F5F9);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _salvando = false;

  int? _idProfissional;
  int? _idGrupoEmpresa;
  bool _contaEmpresaAtiva = false;
  String _nomeProfissional = '';
  String? _fotoPerfilUrl;
  String? _stripeConnectedAccountId;

  // Chaves do profissional carregadas do cadastro
  String? _cpfCnpjCadastrado;
  String? _telefoneCadastrado;
  String? _emailCadastrado;

  // Estados das formas de pagamento
  bool _aceitaPix = true;
  bool _aceitaCartaoCredito = true;
  bool _aceitaCartaoDebito = true;
  bool _aceitaBoleto = false;

  String? _chavePix;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  bool _destacarChavePix = false;
  String _condicoesParcela = 'Até 6x sem juros (Taxa absorvida)';

  static const List<String> _opcoesParcelamento = [
    'Somente à vista (1x)',
    'Até 2x sem juros (Taxa absorvida)',
    'Até 3x sem juros (Taxa absorvida)',
    'Até 4x sem juros (Taxa absorvida)',
    'Até 5x sem juros (Taxa absorvida)',
    'Até 6x sem juros (Taxa absorvida)',
    'Até 10x sem juros (Taxa absorvida)',
    'Até 12x sem juros (Taxa absorvida)',
    'Até 12x com juros (Repassado ao cliente)',
  ];

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 1),
    ]).animate(_shakeController);
    _carregarDados();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // 1. Carrega dados do usuário
      final usuario = await _supabase
          .from('usuarios')
          .select(
            'id_usuario, nome, foto_perfil_url, fk_email, fk_telefone, fk_tipo_pessoa',
          )
          .eq('auth_id', user.id)
          .maybeSingle();

      if (usuario == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      _contaEmpresaAtiva =
          prefs.getBool(
            '${BottomNavigationBarProfissional.prefContaAtivaKey}_${user.id}',
          ) ??
          false;

      final idUsuario = (usuario['id_usuario'] as num?)?.toInt();
      _nomeProfissional = usuario['nome']?.toString().trim() ?? '';
      _fotoPerfilUrl = usuario['foto_perfil_url']?.toString();

      // 2. Busca e-mail
      final fkEmail = usuario['fk_email'];
      if (fkEmail != null) {
        try {
          final emailRes = await _supabase
              .from('emails')
              .select('endereco_email')
              .eq('id_email', fkEmail)
              .maybeSingle();
          _emailCadastrado =
              emailRes?['endereco_email']?.toString() ?? user.email;
        } catch (_) {
          _emailCadastrado = user.email;
        }
      } else {
        _emailCadastrado = user.email;
      }

      // 3. Busca telefone
      final fkTelefone = usuario['fk_telefone'];
      if (fkTelefone != null) {
        try {
          final telRes = await _supabase
              .from('telefones')
              .select('ddd, numero')
              .eq('id_telefone', fkTelefone)
              .maybeSingle();
          if (telRes != null) {
            final ddd = telRes['ddd']?.toString() ?? '';
            final num = telRes['numero']?.toString() ?? '';
            if (ddd.isNotEmpty && num.isNotEmpty) {
              if (num.length == 9) {
                _telefoneCadastrado =
                    '($ddd) ${num.substring(0, 5)}-${num.substring(5)}';
              } else if (num.length == 8) {
                _telefoneCadastrado =
                    '($ddd) ${num.substring(0, 4)}-${num.substring(4)}';
              } else {
                _telefoneCadastrado = '($ddd) $num';
              }
            }
          }
        } catch (_) {}
      }

      // 4. Busca CPF ou CNPJ
      final fkTipoPessoa = usuario['fk_tipo_pessoa'];
      if (fkTipoPessoa != null) {
        try {
          final ass = await _supabase
              .from('ass_tipo_pessoa')
              .select('fk_pessoa_fisica, fk_pessoa_juridica')
              .eq('id_tipo_pessoa', fkTipoPessoa)
              .maybeSingle();

          final fkPf = ass?['fk_pessoa_fisica'];
          final fkPj = ass?['fk_pessoa_juridica'];

          if (fkPf != null) {
            final pf = await _supabase
                .from('pessoa_fisica')
                .select('cpf')
                .eq('id_pessoa_fisica', fkPf)
                .maybeSingle();
            final cpfRaw =
                pf?['cpf']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
            if (cpfRaw.length == 11) {
              _cpfCnpjCadastrado =
                  '${cpfRaw.substring(0, 3)}.${cpfRaw.substring(3, 6)}.${cpfRaw.substring(6, 9)}-${cpfRaw.substring(9, 11)}';
            } else if (cpfRaw.isNotEmpty) {
              _cpfCnpjCadastrado = cpfRaw;
            }
          } else if (fkPj != null) {
            final pj = await _supabase
                .from('pessoa_juridica')
                .select('cnpj')
                .eq('id_pessoa_juridica', fkPj)
                .maybeSingle();
            final cnpjRaw =
                pj?['cnpj']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
            if (cnpjRaw.length == 14) {
              _cpfCnpjCadastrado =
                  '${cnpjRaw.substring(0, 2)}.${cnpjRaw.substring(2, 5)}.${cnpjRaw.substring(5, 8)}/${cnpjRaw.substring(8, 12)}-${cnpjRaw.substring(12, 14)}';
            } else if (cnpjRaw.isNotEmpty) {
              _cpfCnpjCadastrado = cnpjRaw;
            }
          }
        } catch (_) {}
      }

      // 5. Busca dados_profissionais
      if (idUsuario != null) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select(
              'id_profissional, fk_grupo_empresa, pagamento_aceito, chave_pix, condicoes_parcela, stripe_connected_account_id',
            )
            .eq('fk_usuario', idUsuario)
            .maybeSingle();

        if (dadosProf != null) {
          _idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
          _idGrupoEmpresa = (dadosProf['fk_grupo_empresa'] as num?)?.toInt();

          final Map<String, dynamic>? dadosFinanceiros =
              _contaEmpresaAtiva && _idGrupoEmpresa != null
              ? await _supabase
                    .from('grupo_empresa')
                    .select(
                      'pagamento_aceito, chave_pix, condicoes_parcela, nome_empresa, foto_url_empresa, stripe_connected_account_id',
                    )
                    .eq('id_grupo_empresa', _idGrupoEmpresa!)
                    .maybeSingle()
              : dadosProf;

          final pagamentos = dadosFinanceiros?['pagamento_aceito']?.toString();
          if (pagamentos != null && pagamentos.isNotEmpty) {
            final lista = pagamentos
                .split(',')
                .map((e) => e.trim().toLowerCase())
                .toSet();
            _aceitaPix = lista.contains('pix');
            _aceitaCartaoCredito =
                lista.contains('cartão de crédito') ||
                lista.contains('cartao de credito');
            _aceitaCartaoDebito =
                lista.contains('cartão de débito') ||
                lista.contains('cartao de debito');
            _aceitaBoleto =
                lista.contains('boleto bancário') ||
                lista.contains('boleto bancario') ||
                lista.contains('boleto');
          } else {
            // Default: apenas Pix ligado
            _aceitaPix = true;
            _aceitaCartaoCredito = false;
            _aceitaCartaoDebito = false;
            _aceitaBoleto = false;
          }

          _chavePix = dadosFinanceiros?['chave_pix']?.toString();
          _stripeConnectedAccountId =
              dadosFinanceiros?['stripe_connected_account_id']
                  ?.toString()
                  .trim();
          if (_contaEmpresaAtiva && _idGrupoEmpresa != null) {
            _nomeProfissional =
                dadosFinanceiros?['nome_empresa']?.toString().trim() ??
                _nomeProfissional;
            _fotoPerfilUrl = dadosFinanceiros?['foto_url_empresa']
                ?.toString()
                .trim();
          }
          final parcelaSalva = dadosFinanceiros?['condicoes_parcela']
              ?.toString();
          if (parcelaSalva != null && parcelaSalva.isNotEmpty) {
            _condicoesParcela = parcelaSalva;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados financeiros: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  int get _formasAtivasCount {
    int count = 0;
    if (_aceitaPix) count++;
    if (_aceitaCartaoCredito) count++;
    if (_aceitaCartaoDebito) count++;
    if (_aceitaBoleto) count++;
    return count;
  }

  Future<void> _salvarNoBanco() async {
    if (_idProfissional == null) return;
    setState(() => _salvando = true);

    try {
      final List<String> modalidades = [];
      if (_aceitaPix) modalidades.add('Pix');
      if (_aceitaCartaoCredito) modalidades.add('Cartão de Crédito');
      if (_aceitaCartaoDebito) modalidades.add('Cartão de Débito');
      if (_aceitaBoleto) modalidades.add('Boleto Bancário');

      final pagamentoAceito = modalidades.isEmpty
          ? 'Pix'
          : modalidades.join(', ');

      final dados = {
        'pagamento_aceito': pagamentoAceito,
        'chave_pix': _aceitaPix ? _chavePix : null,
        'condicoes_parcela': _aceitaCartaoCredito ? _condicoesParcela : null,
      };
      if (_contaEmpresaAtiva && _idGrupoEmpresa != null) {
        await _supabase
            .from('grupo_empresa')
            .update(dados)
            .eq('id_grupo_empresa', _idGrupoEmpresa!);
      } else {
        await _supabase
            .from('dados_profissionais')
            .update(dados)
            .eq('id_profissional', _idProfissional!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações financeiras salvas com sucesso!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar dados financeiros: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  bool get _pixSemChave =>
      _aceitaPix && (_chavePix == null || _chavePix!.trim().isEmpty);

  Future<void> _tentarSair() async {
    if (!_pixSemChave) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (mounted) setState(() => _destacarChavePix = true);
    _shakeController.forward(from: 0);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.key_rounded, color: Color(0xFFDC2626), size: 38),
              const SizedBox(height: 12),
              const Text(
                'Cadastre sua chave Pix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O Pix está ativo, mas nenhuma chave foi definida. Cadastre uma chave antes de sair desta página.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Future<void>.delayed(
                      Duration.zero,
                      _abrirBottomSheetChavePix,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text(
                    'Cadastrar chave Pix',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _destacarChavePix = false);
      });
    }
  }

  String _formatarTipoChave(String? chave) {
    if (chave == null || chave.isEmpty) return '';
    final chaveTrim = chave.trim();
    if (_cpfCnpjCadastrado != null && chaveTrim == _cpfCnpjCadastrado!.trim()) {
      return chaveTrim.length > 14 ? '$chaveTrim (CNPJ)' : '$chaveTrim (CPF)';
    }
    if (_telefoneCadastrado != null &&
        chaveTrim == _telefoneCadastrado!.trim()) {
      return '$chaveTrim (Telefone)';
    }
    if (_emailCadastrado != null &&
        chaveTrim.toLowerCase() == _emailCadastrado!.trim().toLowerCase()) {
      return '$chaveTrim (E-mail)';
    }
    if (chaveTrim.contains('@')) return '$chaveTrim (E-mail)';
    if (RegExp(r'^\d{2,3}\.?\d{3}\.?\d{3}-?\d{2}$').hasMatch(chaveTrim)) {
      return '$chaveTrim (CPF)';
    }
    if (RegExp(r'^\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}$').hasMatch(chaveTrim)) {
      return '$chaveTrim (CNPJ)';
    }
    if (RegExp(r'^\(?\d{2}\)?\s?\d{4,5}-?\d{4}$').hasMatch(chaveTrim)) {
      return '$chaveTrim (Telefone)';
    }
    return '$chaveTrim (Chave)';
  }

  void _abrirBottomSheetChavePix() {
    final controllerOutro = TextEditingController();
    bool mostrarInputOutro = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Escolha sua Chave PIX',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Selecione uma das opções abaixo para vincular à sua conta:',
                      style: TextStyle(fontSize: 13.5, color: _textMuted),
                    ),
                    const SizedBox(height: 20),

                    // Opção 1: CPF / CNPJ
                    _buildOpcaoChavePix(
                      icone: Icons.badge_outlined,
                      titulo:
                          _cpfCnpjCadastrado != null &&
                              _cpfCnpjCadastrado!.length > 14
                          ? 'CNPJ'
                          : 'CPF / CNPJ',
                      valor: _cpfCnpjCadastrado ?? 'Não informado no cadastro',
                      disponivel:
                          _cpfCnpjCadastrado != null &&
                          _cpfCnpjCadastrado!.isNotEmpty,
                      onTap: () {
                        if (_cpfCnpjCadastrado == null) return;
                        setState(() => _chavePix = _cpfCnpjCadastrado);
                        Navigator.of(ctx).pop();
                        _salvarNoBanco();
                      },
                    ),

                    // Opção 2: Telefone
                    _buildOpcaoChavePix(
                      icone: Icons.phone_android_outlined,
                      titulo: 'Telefone Celular',
                      valor: _telefoneCadastrado ?? 'Não informado no cadastro',
                      disponivel:
                          _telefoneCadastrado != null &&
                          _telefoneCadastrado!.isNotEmpty,
                      onTap: () {
                        if (_telefoneCadastrado == null) return;
                        setState(() => _chavePix = _telefoneCadastrado);
                        Navigator.of(ctx).pop();
                        _salvarNoBanco();
                      },
                    ),

                    // Opção 3: E-mail
                    _buildOpcaoChavePix(
                      icone: Icons.mail_outline_rounded,
                      titulo: 'E-mail',
                      valor: _emailCadastrado ?? 'Não informado no cadastro',
                      disponivel:
                          _emailCadastrado != null &&
                          _emailCadastrado!.isNotEmpty,
                      onTap: () {
                        if (_emailCadastrado == null) return;
                        setState(() => _chavePix = _emailCadastrado);
                        Navigator.of(ctx).pop();
                        _salvarNoBanco();
                      },
                    ),

                    // Opção 4: Outro
                    _buildOpcaoChavePix(
                      icone: Icons.vpn_key_outlined,
                      titulo: 'Outro',
                      valor: 'Chave Aleatória (EVP) ou personalizada',
                      disponivel: true,
                      onTap: () {
                        setSheetState(() {
                          mostrarInputOutro = !mostrarInputOutro;
                        });
                      },
                    ),

                    if (mostrarInputOutro) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: controllerOutro,
                              decoration: const InputDecoration(
                                hintText: 'Cole ou digite sua chave PIX aqui',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13.5,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  final texto = controllerOutro.text.trim();
                                  if (texto.isEmpty) return;
                                  setState(() => _chavePix = texto);
                                  Navigator.of(ctx).pop();
                                  _salvarNoBanco();
                                },
                                child: const Text(
                                  'Salvar Chave',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOpcaoChavePix({
    required IconData icone,
    required String titulo,
    required String valor,
    required bool disponivel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disponivel ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: disponivel
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icone,
                    color: disponivel ? _primaryBlue : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: disponivel
                              ? _textDark
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valor,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: disponivel
                              ? _textMuted
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: disponivel ? _primaryBlue : const Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirBottomSheetParcelamento() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 24,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Condições de Parcelamento',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Defina como o parcelamento no cartão será exibido ao cliente:',
                  style: TextStyle(fontSize: 13.5, color: _textMuted),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _opcoesParcelamento.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final opcao = _opcoesParcelamento[index];
                      final selecionado = opcao == _condicoesParcela;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          opcao,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: selecionado
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selecionado ? _primaryBlue : _textDark,
                          ),
                        ),
                        trailing: selecionado
                            ? const Icon(Icons.check, color: _primaryBlue)
                            : null,
                        onTap: () {
                          setState(() => _condicoesParcela = opcao);
                          Navigator.of(ctx).pop();
                          _salvarNoBanco();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _tentarSair();
      },
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryBlue),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    if (_salvando)
                      const LinearProgressIndicator(
                        minHeight: 2.5,
                        color: _primaryBlue,
                        backgroundColor: Colors.transparent,
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPillsStatus(),
                            const SizedBox(height: 16),
                            _buildTituloPrincipal(),
                            const SizedBox(height: 20),
                            _buildCardPix(),
                            const SizedBox(height: 14),
                            _buildCardCredito(),
                            const SizedBox(height: 14),
                            _buildCardDebito(),
                            const SizedBox(height: 14),
                            _buildCardBoleto(),
                            const SizedBox(height: 20),
                            _buildCardStripe(),
                            const SizedBox(height: 14),
                            _buildRodapeInformativo(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1E293B),
              size: 24,
            ),
            onPressed: _tentarSair,
          ),
          const Expanded(
            child: Text(
              'Dados Financeiros',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              color: Color(0xFF475569),
              size: 22,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Configure as formas de pagamento que estarão visíveis no seu checkout oficial e orçamentos.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _contaEmpresaAtiva
                      ? const GestaoEquipePage()
                      : const TelaMeuPerfilProfissionalPage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: _primaryBlue,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _fotoPerfilUrl != null && _fotoPerfilUrl!.isNotEmpty
                    ? Image.network(
                        _fotoPerfilUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildPillsStatus() {
    final formas = _formasAtivasCount;
    return Row(
      children: [
        // Pílula 1: Configuração Comercial
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_outlined, size: 15, color: Color(0xFF475569)),
              SizedBox(width: 6),
              Text(
                'Configuração Comercial',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Pílula 2: 4 formas ativas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$formas ${formas == 1 ? 'forma ativa' : 'formas ativas'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTituloPrincipal() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quais formas de pagamento você aceita?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _textDark,
            height: 1.25,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Seus clientes visualizarão essas modalidades disponíveis durante a solicitação de orçamento e no checkout oficial do pedido.',
          style: TextStyle(fontSize: 13.5, color: _textMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildCardPix() {
    final temChave = _chavePix != null && _chavePix!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sync_alt,
                  color: _primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PIX Instantâneo',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '0% taxa',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Receba diretamente na sua conta bancária sem intermediários.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: _aceitaPix,
                activeTrackColor: _primaryBlue,
                onChanged: (val) {
                  setState(() => _aceitaPix = val);
                  _salvarNoBanco();
                },
              ),
            ],
          ),

          // Se PIX estiver ativo: exibe Chave Principal Cadastrada
          if (_aceitaPix) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chave Principal Cadastrada:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      if (temChave)
                        InkWell(
                          onTap: _abrirBottomSheetChavePix,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: _primaryBlue,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (temChave)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.badge_outlined,
                              color: _primaryBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatarTipoChave(_chavePix),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: _textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _nomeProfissional.isNotEmpty
                                      ? '$_nomeProfissional • Titular Verificado'
                                      : 'Titular Verificado',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: _primaryBlue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Ativa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: InkWell(
                        onTap: _abrirBottomSheetChavePix,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _destacarChavePix
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _destacarChavePix
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: _destacarChavePix
                                    ? const Color(0xFFDC2626)
                                    : _primaryBlue,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nenhuma chave cadastrada. Toque para cadastrar uma chave PIX.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _destacarChavePix
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: _destacarChavePix
                                    ? const Color(0xFFDC2626)
                                    : _primaryBlue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardCredito() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.credit_card_outlined,
                  color: Color(0xFF475569),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cartão de Crédito',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Maquininha presencial ou envio de link (Visa, Master, Elo, Hiper).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: _aceitaCartaoCredito,
                activeTrackColor: _primaryBlue,
                onChanged: (val) {
                  setState(() => _aceitaCartaoCredito = val);
                  _salvarNoBanco();
                },
              ),
            ],
          ),

          // Se Cartão de Crédito estiver ativo: Condições de parcelamento
          if (_aceitaCartaoCredito) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Condições de Parcelamento:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'Ajuste visível ao cliente',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _abrirBottomSheetParcelamento,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _condicoesParcela,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: _textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF64748B),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardDebito() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.contactless_outlined,
              color: Color(0xFF475569),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cartão de Débito',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Pagamento via maquininha física (Visa Débito, Maestro, Elo Débito).',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: _aceitaCartaoDebito,
            activeTrackColor: _primaryBlue,
            onChanged: (val) {
              setState(() => _aceitaCartaoDebito = val);
              _salvarNoBanco();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardBoleto() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFF475569),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Boleto Bancário',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'B2B / Faturado',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Recomendado para contratos corporativos ou compras de maior valor.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: _aceitaBoleto,
            activeTrackColor: _primaryBlue,
            onChanged: (val) {
              setState(() => _aceitaBoleto = val);
              _salvarNoBanco();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRodapeInformativo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Color(0xFF334155)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Suas configurações financeiras respeitam os Termos de Prestação de Serviços da ConsertaJá e as regras do Código de Defesa do Consumidor para pagamentos presenciais e digitais.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStripe() {
    final conectado =
        _stripeConnectedAccountId != null &&
        _stripeConnectedAccountId!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recebimentos Stripe',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  conectado
                      ? 'Conta Stripe conectada'
                      : 'Conta Stripe ainda não conectada',
                  style: const TextStyle(color: _textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(
            conectado ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: conectado ? Colors.green : _textMuted,
          ),
        ],
      ),
    );
  }
}
