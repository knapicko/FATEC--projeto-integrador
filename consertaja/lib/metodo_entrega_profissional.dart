import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/metodo_entrega.dart';
import 'utils/bottom_navigation_bar_profissional.dart';

class MetodoEntregaProfissionalPage extends StatefulWidget {
  const MetodoEntregaProfissionalPage({super.key});

  @override
  State<MetodoEntregaProfissionalPage> createState() =>
      _MetodoEntregaProfissionalPageState();
}

class _MetodoEntregaProfissionalPageState
    extends State<MetodoEntregaProfissionalPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _textMuted = Color(0xFF7D8595);
  static const Color _cardBorder = Color(0xFFE7EBF0);
  static const Color _cardFill = Color(0xFFF5F8FB);

  final Set<String> _selecionadas = <String>{};
  bool _carregando = true;
  bool _salvando = false;

  // Conta ativa (mesma flag da home): false = profissional (CNPJ),
  // true = empresa. Empresa lê/salva em grupo_empresa.metodo_entrega_empresa;
  // profissional lê/salva em dados_profissionais.metodo_entrega.
  static const String _prefContaAtivaKey = 'consertaja_conta_empresa_ativa';
  bool _contaEmpresaAtiva = false;
  int? _idGrupoEmpresa;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

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

  Future<int?> _buscarIdGrupoEmpresa(int usuarioId) async {
    try {
      final supabase = Supabase.instance.client;
      final dados = await supabase
          .from('dados_profissionais')
          .select('fk_grupo_empresa')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      return (dados?['fk_grupo_empresa'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _carregarPreferencias() async {
    _selecionadas.clear();
    if (mounted) setState(() => _carregando = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        _selecionadas.add('Leva e Traz');
        if (mounted) {
          setState(() {
            _contaEmpresaAtiva = false;
            _idGrupoEmpresa = null;
            _carregando = false;
          });
        }
        return;
      }

      final contaEmpresa = await _lerContaEmpresaAtiva();

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      final usuarioId = (usuario?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) {
        _selecionadas.add('Leva e Traz');
        if (mounted) {
          setState(() {
            _contaEmpresaAtiva = contaEmpresa;
            _idGrupoEmpresa = null;
            _carregando = false;
          });
        }
        return;
      }

      String? raw;
      int? idGrupo;
      if (contaEmpresa) {
        idGrupo = await _buscarIdGrupoEmpresa(usuarioId);
        if (idGrupo != null) {
          try {
            final grupo = await supabase
                .from('grupo_empresa')
                .select('metodo_entrega_empresa')
                .eq('id_grupo_empresa', idGrupo)
                .maybeSingle();
            raw = grupo?['metodo_entrega_empresa'] as String?;
          } catch (_) {
            // Banco ainda sem a migration: cai para o profissional.
            raw = null;
          }
        }
        // Sem grupo vinculado, não há onde salvar o da empresa:
        // mostra o default e salva só quando houver grupo.
        if (raw == null && idGrupo == null) {
          raw = null;
        }
      } else {
        final dados = await supabase
            .from('dados_profissionais')
            .select('metodo_entrega')
            .eq('fk_usuario', usuarioId)
            .maybeSingle();
        raw = dados?['metodo_entrega'] as String?;
      }

      final itensSalvos = _parseMetodoEntrega(raw);
      if (itensSalvos.isEmpty) {
        _selecionadas.add('Leva e Traz');
      } else {
        _selecionadas.addAll(itensSalvos);
      }
      if (mounted) {
        setState(() {
          _contaEmpresaAtiva = contaEmpresa;
          _idGrupoEmpresa = idGrupo;
          _carregando = false;
        });
      }
    } catch (_) {
      _selecionadas.add('Leva e Traz');
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

      if (_contaEmpresaAtiva) {
        // Conta empresa: salva em grupo_empresa.metodo_entrega_empresa
        // (igual ao profissional, mas na tabela da empresa).
        var idGrupo = _idGrupoEmpresa ?? await _buscarIdGrupoEmpresa(usuarioId);
        if (idGrupo == null) {
          throw Exception(
            'Nenhuma empresa vinculada a este perfil para salvar.',
          );
        }
        try {
          await supabase
              .from('grupo_empresa')
              .update({'metodo_entrega_empresa': valorFinal})
              .eq('id_grupo_empresa', idGrupo);
        } catch (_) {
          throw Exception(
            'Banco sem a coluna metodo_entrega_empresa. Rode docs/sql/migration_metodo_entrega_empresa.sql no Supabase.',
          );
        }
        if (mounted) {
          setState(() => _idGrupoEmpresa = idGrupo);
        }
      } else {
        await supabase
            .from('dados_profissionais')
            .update({'metodo_entrega': valorFinal})
            .eq('fk_usuario', usuarioId);
      }

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

  Widget _buildOpcaoEntrega(MetodoEntregaOpcao opcao) {
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
        title: Text(
          _contaEmpresaAtiva
              ? 'Métodos de Entrega da Empresa'
              : 'Métodos de Entrega',
          style: const TextStyle(
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
                          Text(
                            _contaEmpresaAtiva
                                ? 'Como os clientes podem enviar ou receber os serviços com a empresa?'
                                : 'Como os clientes podem enviar ou receber os serviços com você?',
                            style: const TextStyle(
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
                          ...metodosEntregaOpcoes
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
                              metodosEntregaOpcoes.firstWhere(
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
