import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/icone_oficio.dart';

class ConfiguracoesEmpresaPage extends StatefulWidget {
  const ConfiguracoesEmpresaPage({super.key});

  @override
  State<ConfiguracoesEmpresaPage> createState() =>
      _ConfiguracoesEmpresaPageState();
}

class _ConfiguracoesEmpresaPageState extends State<ConfiguracoesEmpresaPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _titleDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  // Paleta de cores para destaque da tag
  static const List<Color> _coresPreset = [
    Color(0xFF003D7A), // Azul Marinho Escuro
    Color(0xFF0FB3FF), // Azul Claro ConsertaJá
    Color(0xFF10B981), // Verde Esmeralda
    Color(0xFFF59E0B), // Âmbar / Laranja
    Color(0xFFDC2626), // Vermelho
    Color(0xFF7C3AED), // Roxo
    Color(0xFF334155), // Grafite / Slate
  ];

  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  Color _corTag = const Color(0xFF003D7A);
  bool _compartilharFuncionarios = false;

  bool _carregando = true;
  Timer? _debounceNome;
  Timer? _debounceTag;

  int? _idUsuario;
  int? _idProfissional;
  int? _idPerfil;
  int? _idGrupoEmpresa;

  List<Map<String, dynamic>> _oficiosDisponiveis = [];
  final List<Map<String, dynamic>> _oficiosSelecionados = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _debounceNome?.cancel();
    _debounceTag?.cancel();
    _nomeController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Color _corFromHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return const Color(0xFF003D7A);
    var value = hex.trim().replaceAll('#', '');
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFF003D7A);
    return Color(parsed);
  }

  String _corParaHex(Color color) {
    return '0xFF${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Color _corContraste(Color c) {
    final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return lum > 0.55 ? Colors.black : Colors.white;
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // 1. Carrega usuário e tipo de pessoa para buscar pessoa jurídica se necessário
      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario, nome, fk_tipo_pessoa')
          .eq('auth_id', user.id)
          .maybeSingle();

      String? nomeFantasiaPj;
      if (usuario != null) {
        _idUsuario = (usuario['id_usuario'] as num?)?.toInt();
        final fkTipoPessoa = usuario['fk_tipo_pessoa'];

        if (fkTipoPessoa != null) {
          final assTipo = await _supabase
              .from('ass_tipo_pessoa')
              .select('fk_pessoa_juridica')
              .eq('id_tipo_pessoa', fkTipoPessoa)
              .maybeSingle();

          final fkPj = assTipo?['fk_pessoa_juridica'];
          if (fkPj != null) {
            final pj = await _supabase
                .from('pessoa_juridica')
                .select('nome_fantasia, razao_social')
                .eq('id_pessoa_juridica', fkPj)
                .maybeSingle();
            nomeFantasiaPj = pj?['nome_fantasia']?.toString().trim();
            if (nomeFantasiaPj == null || nomeFantasiaPj.isEmpty) {
              nomeFantasiaPj = pj?['razao_social']?.toString().trim();
            }
          }
        }
      }

      // 2. Carrega dados profissionais
      if (_idUsuario != null) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_perfil, fk_grupo_empresa')
            .eq('fk_usuario', _idUsuario!)
            .maybeSingle();

        if (dadosProf != null) {
          _idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
          _idPerfil = (dadosProf['fk_perfil'] as num?)?.toInt();
          _idGrupoEmpresa = (dadosProf['fk_grupo_empresa'] as num?)?.toInt();
        }
      }

      // 3. Carrega grupo_empresa
      Map<String, dynamic>? grupo;
      if (_idGrupoEmpresa != null) {
        grupo = await _supabase
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, compartilhar_funcionarios',
            )
            .eq('id_grupo_empresa', _idGrupoEmpresa!)
            .maybeSingle();
      } else if (_idPerfil != null) {
        grupo = await _supabase
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, compartilhar_funcionarios',
            )
            .eq('fk_perfil', _idPerfil!)
            .maybeSingle();

        if (grupo != null) {
          _idGrupoEmpresa = (grupo['id_grupo_empresa'] as num?)?.toInt();
          if (_idGrupoEmpresa != null && _idProfissional != null) {
            await _supabase
                .from('dados_profissionais')
                .update({'fk_grupo_empresa': _idGrupoEmpresa})
                .eq('id_profissional', _idProfissional!);
          }
        }
      }

      String nomeCarregado = '';
      String tagCarregada = 'TAG';

      if (grupo != null) {
        final nome = grupo['nome_empresa']?.toString().trim() ?? '';
        final tag = grupo['tag_empresa']?.toString().trim() ?? '';
        final cor = grupo['cor_tag_empresa']?.toString();
        final comp = grupo['compartilhar_funcionarios'];

        if (nome.isNotEmpty) {
          nomeCarregado = nome;
        } else if (nomeFantasiaPj != null && nomeFantasiaPj.isNotEmpty) {
          nomeCarregado = nomeFantasiaPj;
          // Deixa salvo como nome_empresa o nome_fantasia na tabela grupo_empresa
          if (_idGrupoEmpresa != null) {
            await _supabase
                .from('grupo_empresa')
                .update({'nome_empresa': nomeFantasiaPj})
                .eq('id_grupo_empresa', _idGrupoEmpresa!);
          }
        }

        if (tag.isNotEmpty) {
          tagCarregada = tag.toUpperCase();
        } else {
          tagCarregada = 'TAG';
        }

        if (cor != null && cor.isNotEmpty) {
          _corTag = _corFromHex(cor);
        }
        if (comp is bool) {
          _compartilharFuncionarios = comp;
        }
      } else {
        if (nomeFantasiaPj != null && nomeFantasiaPj.isNotEmpty) {
          nomeCarregado = nomeFantasiaPj;
        }
        tagCarregada = 'TAG';
        _corTag = const Color(0xFF003D7A);
        _compartilharFuncionarios = false;
      }

      _nomeController.text = nomeCarregado;
      _tagController.text = tagCarregada;

      // 4. Carrega ofícios disponíveis
      final oficiosResponse = await _supabase
          .from('oficios')
          .select('id_oficio, funcao, categoria, descricao')
          .order('funcao');

      _oficiosDisponiveis = List<Map<String, dynamic>>.from(oficiosResponse);

      // 5. Carrega ofícios associados ao profissional
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
          if (oficio.isNotEmpty && _oficiosSelecionados.length < 3) {
            _oficiosSelecionados.add(oficio);
          }
        }
      }

      if (mounted) setState(() => _carregando = false);
    } catch (e) {
      debugPrint('Erro ao carregar configurações da empresa: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _garantirGrupoEmpresa() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_idUsuario == null) {
      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      _idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
    }

    if (_idProfissional == null || _idPerfil == null) {
      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_perfil, fk_grupo_empresa')
          .eq('fk_usuario', _idUsuario!)
          .maybeSingle();

      _idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
      _idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
      _idGrupoEmpresa ??= (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();
    }

    if (_idPerfil == null && _idProfissional != null) {
      final novoPerfil = await _supabase
          .from('perfil')
          .insert({'tipo_perfil': 'Loja'})
          .select('id_perfil')
          .single();

      _idPerfil = (novoPerfil['id_perfil'] as num?)?.toInt();
      if (_idPerfil != null) {
        await _supabase
            .from('dados_profissionais')
            .update({'fk_perfil': _idPerfil})
            .eq('id_profissional', _idProfissional!);
      }
    }
  }

  Future<void> _salvarCampoEmpresa(Map<String, dynamic> campos) async {
    try {
      await _garantirGrupoEmpresa();

      if (_idGrupoEmpresa != null) {
        await _supabase
            .from('grupo_empresa')
            .update(campos)
            .eq('id_grupo_empresa', _idGrupoEmpresa!);
      } else if (_idPerfil != null) {
        final existente = await _supabase
            .from('grupo_empresa')
            .select('id_grupo_empresa')
            .eq('fk_perfil', _idPerfil!)
            .maybeSingle();

        if (existente != null) {
          _idGrupoEmpresa = (existente['id_grupo_empresa'] as num?)?.toInt();
          await _supabase
              .from('grupo_empresa')
              .update(campos)
              .eq('id_grupo_empresa', _idGrupoEmpresa!);
        } else {
          final novoGrupo = await _supabase
              .from('grupo_empresa')
              .insert({'fk_perfil': _idPerfil!, ...campos})
              .select('id_grupo_empresa')
              .single();

          _idGrupoEmpresa = (novoGrupo['id_grupo_empresa'] as num?)?.toInt();
        }

        if (_idProfissional != null && _idGrupoEmpresa != null) {
          await _supabase
              .from('dados_profissionais')
              .update({'fk_grupo_empresa': _idGrupoEmpresa})
              .eq('id_profissional', _idProfissional!);
        }
      }
    } catch (e) {
      debugPrint('Erro ao salvar alteração no banco: $e');
    }
  }

  Future<void> _salvarOficios() async {
    try {
      await _garantirGrupoEmpresa();
      if (_idProfissional != null) {
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
      }
    } catch (e) {
      debugPrint('Erro ao salvar ofícios no banco: $e');
    }
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handyman_outlined, color: _primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      slotIndex < _oficiosSelecionados.length
                          ? 'Trocar ${slotIndex + 1}º Ofício'
                          : 'Adicionar ${slotIndex + 1}º Ofício',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _titleDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _cardBorder),
              if (opcoes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhum ofício adicional disponível.',
                    style: TextStyle(color: _textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: opcoes.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: _cardBorder),
                    itemBuilder: (context, index) {
                      final oficio = opcoes[index];
                      final nome = oficio['funcao']?.toString() ?? '';
                      return ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconeOficio.imagemPorFuncaoAzul(
                            nome,
                            tamanho: 24,
                          ),
                        ),
                        title: Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _titleDark,
                          ),
                        ),
                        subtitle: oficio['categoria'] != null
                            ? Text(
                                oficio['categoria'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textMuted,
                                ),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            if (slotIndex < _oficiosSelecionados.length) {
                              _oficiosSelecionados[slotIndex] = oficio;
                            } else {
                              _oficiosSelecionados.add(oficio);
                            }
                          });
                          _salvarOficios();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              if (slotIndex < _oficiosSelecionados.length) ...[
                const Divider(height: 1, color: _cardBorder),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Remover este ofício',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _oficiosSelecionados.removeAt(slotIndex);
                    });
                    _salvarOficios();
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconeOficio(String nome) {
    final nomeLower = nome.toLowerCase();
    if (nomeLower.contains('eletric') || nomeLower.contains('elétrica')) {
      return const Icon(Icons.bolt_rounded, color: _primaryBlue, size: 26);
    }
    return IconeOficio.imagemPorFuncaoAzul(nome, tamanho: 26);
  }

  Widget _buildCardSlot(int index) {
    final preenchido = index < _oficiosSelecionados.length;
    if (preenchido) {
      final oficio = _oficiosSelecionados[index];
      final nome = oficio['funcao']?.toString() ?? '';
      final subtitulo = index == 0 ? 'Principal' : '${index + 1}º Ofício';

      return Container(
        height: 148,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
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
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: _primaryBlue, size: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: _buildIconeOficio(nome)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _abrirSeletorOficio(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Trocar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final label = '${index + 1}º Ofício';
      return InkWell(
        onTap: () => _abrirSeletorOficio(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 148,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _titleDark,
                ),
              ),
              const Text(
                'Adicionar',
                style: TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomeExibicao = _nomeController.text.trim().isEmpty
        ? 'Nome da Empresa'
        : _nomeController.text.trim();
    final tagExibicao = _tagController.text.trim().isEmpty
        ? 'TAG'
        : _tagController.text.trim().toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryBlue),
          onPressed: () => Navigator.pop(context, true),
        ),
        titleSpacing: 0,
        title: const Text(
          'Configurações da Empresa',
          style: TextStyle(
            color: _primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= CARD DE RESUMO SUPERIOR =================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: _primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nomeExibicao,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: _titleDark,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Identificador Ativo: #$tagExibicao',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _primaryBlue,
                                  width: 1.2,
                                ),
                              ),
                              child: const Text(
                                'Em operação',
                                style: TextStyle(
                                  color: _primaryBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ================= IDENTIFICAÇÃO DA EMPRESA =================
                      Row(
                        children: const [
                          Icon(
                            Icons.storefront_outlined,
                            color: _primaryBlue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Identificação da Empresa',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: _titleDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Atualize os dados institucionais que aparecem nos orçamentos e relatórios técnicos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Nome da Empresa',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _titleDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: Nome da sua empresa',
                          filled: true,
                          fillColor: _cardBg,
                          suffixIcon: const Icon(
                            Icons.edit_outlined,
                            color: _titleDark,
                            size: 19,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _primaryBlue,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {});
                          _debounceNome?.cancel();
                          _debounceNome = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              final texto = _nomeController.text.trim();
                              if (texto.isNotEmpty) {
                                _salvarCampoEmpresa({'nome_empresa': texto});
                              }
                            },
                          );
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o nome da empresa.';
                          }
                          if (value.trim().length < 2) {
                            return 'Mínimo de 2 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 1.5),
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: _textMuted,
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Este é o nome comercial exibido para todos os clientes e prestadores.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ================= TAG PERSONALIZADA DA EMPRESA =================
                      Row(
                        children: const [
                          Icon(
                            Icons.local_offer_outlined,
                            color: _primaryBlue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tag Personalizada da Empresa',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: _titleDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Crie uma tag exclusiva para identificar sua empresa nas buscas e orçamentos (máx. 5 caracteres).',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Identificador da Tag',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 14, right: 6),
                              child: Text(
                                '#',
                                style: TextStyle(
                                  color: _primaryBlue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _tagController,
                                maxLength: 5,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9]'),
                                  ),
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: _titleDark,
                                  letterSpacing: 1,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'TAG',
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (v) {
                                  final upper = v.toUpperCase();
                                  if (upper != v) {
                                    _tagController.value = _tagController.value
                                        .copyWith(
                                          text: upper,
                                          selection: TextSelection.collapsed(
                                            offset: upper.length,
                                          ),
                                        );
                                  }
                                  setState(() {});
                                  _debounceTag?.cancel();
                                  _debounceTag = Timer(
                                    const Duration(milliseconds: 500),
                                    () {
                                      final texto = _tagController.text.trim();
                                      if (texto.isNotEmpty) {
                                        _salvarCampoEmpresa({
                                          'tag_empresa': texto.toUpperCase(),
                                        });
                                      }
                                    },
                                  );
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe a tag da empresa.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Text(
                                '${_tagController.text.length}/5',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Cor de Destaque da Tag',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ..._coresPreset.map((cor) {
                            final selecionada =
                                _corTag.toARGB32() == cor.toARGB32();
                            return GestureDetector(
                              onTap: () {
                                setState(() => _corTag = cor);
                                _salvarCampoEmpresa({
                                  'cor_tag_empresa': _corParaHex(cor),
                                });
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: cor,
                                  shape: BoxShape.circle,
                                ),
                                child: selecionada
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            );
                          }),
                          // Botão seletor de cor customizada
                          GestureDetector(
                            onTap: () async {
                              final cor = await showDialog<Color>(
                                context: context,
                                builder: (context) =>
                                    _ColorPickerDialog(corInicial: _corTag),
                              );
                              if (cor != null) {
                                setState(() => _corTag = cor);
                                _salvarCampoEmpresa({
                                  'cor_tag_empresa': _corParaHex(cor),
                                });
                              }
                            },
                            child: Container(
                              width: 34,
                              height: 34,
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
                                child: Icon(
                                  Icons.colorize_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ================= CARD PRÉVIA EM TEMPO REAL =================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRÉVIA EM TEMPO REAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _corTag,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#$tagExibicao',
                                      style: TextStyle(
                                        color: _corContraste(_corTag),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nomeExibicao,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: _titleDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: const [
                                            Icon(
                                              Icons.check_circle,
                                              color: _primaryBlue,
                                              size: 13,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Empresa Verificada',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: _textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ================= OFÍCIOS DE ATUAÇÃO =================
                      Row(
                        children: [
                          const Icon(
                            Icons.handyman_outlined,
                            color: _primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ofícios de Atuação',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: _titleDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_oficiosSelecionados.length}/3 ativos',
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Defina até 3 principais especialidades atendidas pela empresa para direcionamento de chamados.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildCardSlot(0)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCardSlot(1)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCardSlot(2)),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ================= PRIVACIDADE E EXIBIÇÃO =================
                      Row(
                        children: const [
                          Icon(
                            Icons.shield_outlined,
                            color: _primaryBlue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Privacidade e Exibição',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: _titleDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.badge_outlined,
                                color: _primaryBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Exibir funcionários para os clientes',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: _titleDark,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Quando ativo, os clientes poderão ver os membros da equipe no perfil da empresa associada e saber qual profissional executará o serviço contratado.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: _textMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _compartilharFuncionarios,
                              activeThumbColor: _primaryBlue,
                              activeTrackColor: const Color(0xFFBAE6FD),
                              onChanged: (val) {
                                setState(() {
                                  _compartilharFuncionarios = val;
                                });
                                _salvarCampoEmpresa({
                                  'compartilhar_funcionarios': val,
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Diálogo de seleção de cor da Tag (Color Picker igual ao anterior)
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Escolher cor da Tag',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
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
                  borderRadius: BorderRadius.circular(12),
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
              Text(
                'HEX: #${_cor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _cor),
          style: ElevatedButton.styleFrom(
            backgroundColor: _cor,
            foregroundColor: _cor.computeLuminance() > 0.55
                ? Colors.black
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Selecionar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ColorizSliderHue extends StatelessWidget {
  final Color cor;
  final ValueChanged<Color> onChanged;

  const _ColorizSliderHue({required this.cor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(cor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MATIZ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.6,
          ),
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
                onChanged(
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

class _ColorizSliderSaturacao extends StatelessWidget {
  final Color cor;
  final ValueChanged<Color> onChanged;

  const _ColorizSliderSaturacao({required this.cor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(cor);
    final base = HSLColor.fromAHSL(hsl.alpha, hsl.hue, 1.0, hsl.lightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SATURAÇÃO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.6,
          ),
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
                onChanged(
                  HSLColor.fromAHSL(
                    hsl.alpha,
                    hsl.hue,
                    v,
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

class _ColorizSliderBrilho extends StatelessWidget {
  final Color cor;
  final ValueChanged<Color> onChanged;

  const _ColorizSliderBrilho({required this.cor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(cor);
    final corHsl = HSLColor.fromAHSL(hsl.alpha, hsl.hue, hsl.saturation, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BRILHO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [Colors.black, corHsl.toColor(), Colors.white],
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
              value: hsl.lightness.clamp(0.0, 1.0),
              onChanged: (v) {
                onChanged(
                  HSLColor.fromAHSL(
                    hsl.alpha,
                    hsl.hue,
                    hsl.saturation,
                    v,
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
