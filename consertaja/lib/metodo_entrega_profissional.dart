import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/salvamento_automatico.dart';
import 'widgets/skeleton_loading.dart';

import 'models/metodo_entrega.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'widgets/aviso_obrigatorio.dart';
import 'services/requisitos_conta.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_da_tela.dart';

class MetodoEntregaProfissionalPage extends StatefulWidget {
  const MetodoEntregaProfissionalPage({super.key});

  @override
  State<MetodoEntregaProfissionalPage> createState() =>
      _MetodoEntregaProfissionalPageState();
}

class _MetodoEntregaProfissionalPageState
    extends State<MetodoEntregaProfissionalPage>
    with TutorialDaTela<MetodoEntregaProfissionalPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _textMuted = Color(0xFF7D8595);
  static const Color _cardBorder = Color(0xFFE7EBF0);
  static const Color _cardFill = Color(0xFFF5F8FB);

  final Set<String> _selecionadas = <String>{};

  /// Ainda não definiu os métodos (só o padrão do cadastro).
  bool _pendente = false;
  bool _carregando = true;

  /// Cada toque salva sozinho (sem botão "Salvar").
  late final SalvamentoAutomatico _autosave = SalvamentoAutomatico(
    _salvarPreferencias,
  );

  /// Como se locomove até o cliente (e a placa, se motorizado).
  String? _meio;
  final TextEditingController _placa = TextEditingController();
  bool _locomocaoPendente = false;

  @override
  void dispose() {
    _autosave.dispose();
    _placa.dispose();
    super.dispose();
  }

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
    RequisitosConta.pendenciasProfissional().then((p) {
      if (mounted) {
        setState(() {
          _pendente = p.contains(RequisitosConta.entrega);
          _locomocaoPendente = p.contains(RequisitosConta.locomocao);
        });
      }
    });
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

      // Locomoção e placa (v0_10_ajustes.sql).
      try {
        final loc = contaEmpresa
            ? (idGrupo == null
                  ? null
                  : await supabase
                        .from('grupo_empresa')
                        .select('meio_locomocao, placa_veiculo')
                        .eq('id_grupo_empresa', idGrupo)
                        .maybeSingle())
            : await supabase
                  .from('dados_profissionais')
                  .select('meio_locomocao, placa_veiculo')
                  .eq('fk_usuario', usuarioId)
                  .limit(1)
                  .maybeSingle();
        final meio = loc?['meio_locomocao']?.toString().trim() ?? '';
        _meio = RequisitosConta.meiosLocomocao.contains(meio) ? meio : null;
        _placa.text = loc?['placa_veiculo']?.toString().trim() ?? '';
      } catch (_) {}

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
    _autosave.agendar();
  }

  /// Grava no banco (chamado pelo salvamento automático; erros sobem para o
  /// indicador da tela).
  Future<void> _salvarPreferencias() async {
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
      // Conta empresa: salva em grupo_empresa.metodo_entrega_empresa.
      final idGrupo = _idGrupoEmpresa ?? await _buscarIdGrupoEmpresa(usuarioId);
      if (idGrupo == null) {
        throw Exception('Nenhuma empresa vinculada a este perfil.');
      }
      try {
        await supabase
            .from('grupo_empresa')
            .update({'metodo_entrega_empresa': valorFinal})
            .eq('id_grupo_empresa', idGrupo);
        await _marcarDefinido('grupo_empresa', 'id_grupo_empresa', idGrupo);
      } catch (_) {
        throw Exception(
          'banco sem a coluna metodo_entrega_empresa (rode '
          'docs/sql/migration_metodo_entrega_empresa.sql).',
        );
      }
      _idGrupoEmpresa = idGrupo;
    } else {
      await supabase
          .from('dados_profissionais')
          .update({'metodo_entrega': valorFinal})
          .eq('fk_usuario', usuarioId);
      await _marcarDefinido('dados_profissionais', 'fk_usuario', usuarioId);
    }
    await _salvarLocomocao(usuarioId);
    if (mounted) {
      setState(() {
        _pendente = false;
        _locomocaoPendente = _locomocaoIncompleta;
      });
    }
  }

  String get _placaNormalizada =>
      _placa.text.trim().toUpperCase().replaceAll(' ', '');

  bool get _locomocaoIncompleta =>
      _meio == null ||
      (RequisitosConta.exigePlaca(_meio) &&
          !RequisitosConta.placaValida(_placaNormalizada));

  Future<void> _salvarLocomocao(int usuarioId) async {
    if (_meio == null) return;
    final dados = {
      'meio_locomocao': _meio,
      'placa_veiculo': RequisitosConta.exigePlaca(_meio)
          ? _placaNormalizada
          : null,
    };
    try {
      final supabase = Supabase.instance.client;
      if (_contaEmpresaAtiva) {
        if (_idGrupoEmpresa == null) return;
        await supabase
            .from('grupo_empresa')
            .update(dados)
            .eq('id_grupo_empresa', _idGrupoEmpresa!);
      } else {
        await supabase
            .from('dados_profissionais')
            .update(dados)
            .eq('fk_usuario', usuarioId);
      }
    } catch (_) {
      throw Exception(
        'banco sem os campos de locomoção (rode docs/sql/v0_10_ajustes.sql).',
      );
    }
  }

  IconData _iconeMeio(String meio) => switch (meio) {
    'Carro' => Icons.directions_car_rounded,
    'Moto' => Icons.two_wheeler_rounded,
    'Bicicleta' => Icons.pedal_bike_rounded,
    'Transporte público' => Icons.directions_bus_rounded,
    _ => Icons.local_shipping_rounded,
  };

  Widget _buildLocomocao() {
    final exige = RequisitosConta.exigePlaca(_meio);
    final placaOk = RequisitosConta.placaValida(_placaNormalizada);
    final semPlaca = _placa.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_locomocaoPendente)
          const AvisoObrigatorio(
            titulo: 'Defina como você se locomove',
            texto:
                'Escolha o meio de locomoção (e a placa, se for carro, moto ou '
                'caminhão). Sem isso não é possível adicionar serviços nem '
                'usar o Radar.',
            margem: EdgeInsets.only(bottom: 14),
          ),
        Text(
          _contaEmpresaAtiva
              ? 'Como a empresa se locomove até o cliente?'
              : 'Como você se locomove até o cliente?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _titleDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'O cliente vê essa informação quando você for até ele.',
          style: TextStyle(fontSize: 14, color: _textMuted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in RequisitosConta.meiosLocomocao)
              ChoiceChip(
                selected: _meio == m,
                showCheckmark: false,
                avatar: Icon(
                  _iconeMeio(m),
                  size: 18,
                  color: _meio == m ? Colors.white : _primaryBlue,
                ),
                label: Text(m),
                labelStyle: TextStyle(
                  color: _meio == m ? Colors.white : _titleDark,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: _primaryBlue,
                backgroundColor: _cardFill,
                side: BorderSide(
                  color: _meio == m ? _primaryBlue : _cardBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (_) {
                  setState(() => _meio = m);
                  _autosave.agendar();
                },
              ),
          ],
        ),
        if (exige) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _placa,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            onChanged: (_) {
              setState(() {});
              if (RequisitosConta.placaValida(_placaNormalizada)) {
                _autosave.agendar();
              }
            },
            decoration: InputDecoration(
              labelText: 'Placa do veículo',
              hintText: 'ABC1D23 ou ABC-1234',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.pin_outlined, color: _primaryBlue),
              errorText: semPlaca || placaOk ? null : 'Placa inválida',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: semPlaca ? corObrigatorio : _cardBorder,
                  width: semPlaca ? 1.6 : 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// O profissional escolheu os métodos (não é mais o padrão do cadastro).
  Future<void> _marcarDefinido(String tabela, String coluna, Object id) async {
    try {
      await Supabase.instance.client
          .from(tabela)
          .update({'metodo_entrega_definido': true})
          .eq(coluna, id);
    } catch (_) {
      // Banco sem a coluna (docs/sql/v0_7_ajustes.sql ainda não rodado).
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
              color: selecionada
                  ? _primaryBlue.withValues(alpha: 0.6)
                  : _cardBorder,
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
              Icon(opcao.icone, color: _primaryBlue, size: 26),
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
    if (!_carregando) {
      tutorialDaTela(
        chave: 'metodo_entrega',
        passos: () => [
          PassoTutorial(
            'Marque como os clientes podem enviar ou receber os serviços. '
            'Dá para marcar mais de um!',
            alvo: chaveTut('titulo'),
            alvoRect: uniaoTut(['titulo', 'domicilio']),
          ),
          PassoTutorial(
            'Se o seu trabalho é ir até o cliente, marque "Atendimento em '
            'Domicílio".',
            alvo: chaveTut('domicilio'),
          ),
          PassoTutorial(
            'Aqui você diz como se locomove, e a placa se for carro, moto ou '
            'caminhão.',
            alvo: chaveTut('locomocao'),
            alinhamentoRolagem: 0.15,
          ),
          const PassoTutorial('Tudo é salvo sozinho, sem botão. Prontinho!'),
        ],
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryBlue,
          ),
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
          ? const SkeletonPage(layout: SkeletonLayout.cards)
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_pendente)
                            const AvisoObrigatorio(
                              titulo: 'Defina seus métodos de entrega',
                              texto:
                                  'Escolha e salve como você atende. Sem isso '
                                  'não é possível adicionar serviços.',
                              margem: EdgeInsets.only(top: 12),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            key: chaveTut('titulo'),
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
                            style: TextStyle(fontSize: 14, color: _textMuted),
                          ),
                          const SizedBox(height: 24),
                          ...metodosEntregaOpcoes
                              .where(
                                (opcao) =>
                                    opcao.valor != 'Atendimento em Domicílio',
                              )
                              .map(
                                (opcao) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildOpcaoEntrega(opcao),
                                ),
                              ),
                          const SizedBox(height: 12),
                          const Text(
                            '(Nota: Marque esta opção se o seu trabalho exige ir até o cliente)',
                            style: TextStyle(fontSize: 14, color: _textMuted),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            key: chaveTut('domicilio'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOpcaoEntrega(
                              metodosEntregaOpcoes.firstWhere(
                                (opcao) =>
                                    opcao.valor == 'Atendimento em Domicílio',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 22),
                          alvoTut('locomocao', _buildLocomocao()),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24, top: 8),
                          child: IndicadorSalvamento(controle: _autosave),
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
