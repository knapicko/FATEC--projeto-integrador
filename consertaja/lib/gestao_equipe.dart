import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'configuracoes_empresa.dart';
import 'adicionar_servico_profissional.dart';
import 'meus_servicos_solicitados.dart';
import 'modificar_conta_profissional.dart';
import 'models/servico_profissional.dart';
import 'services/consulta_cadastro_service.dart';
import 'services/profissional_equipe_service.dart';
import 'services/servicos_profissional_service.dart';
import 'services/validacao_documento.dart';
import 'tela_home_profissional.dart';
import 'tela_mensagens.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/cor_oficio.dart';
import 'widgets/tag_oficio.dart';

class GestaoEquipePage extends StatefulWidget {
  const GestaoEquipePage({super.key});

  @override
  State<GestaoEquipePage> createState() => _GestaoEquipePageState();
}

class _DocumentoOuEmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text;
    // E-mail: mantém como digitado.
    if (texto.contains('@') || RegExp(r'[A-Za-z]').hasMatch(texto)) {
      return newValue;
    }
    final digitos = texto.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 14) return oldValue;
    final mascara =
        digitos.length <= 11 ? '###.###.###-##' : '##.###.###/####-##';
    var formatado = '';
    var indiceDigito = 0;
    for (var i = 0; i < mascara.length; i++) {
      if (indiceDigito >= digitos.length) break;
      if (mascara[i] == '#') {
        formatado += digitos[indiceDigito];
        indiceDigito++;
      } else {
        formatado += mascara[i];
      }
    }
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}

class _MembroEquipe {
  final String id;
  final int? idProfissional;
  final int? idConvite;
  final String nome;
  final String cargo;
  final String tagFuncao;
  final Color corTagBg;
  final Color corTagTexto;
  final bool isOnline;
  final bool isPendente;
  final String? fotoUrl;
  final String? iniciais;

  _MembroEquipe({
    required this.id,
    this.idProfissional,
    this.idConvite,
    required this.nome,
    required this.cargo,
    required this.tagFuncao,
    required this.corTagBg,
    required this.corTagTexto,
    this.isOnline = false,
    this.isPendente = false,
    this.fotoUrl,
    this.iniciais,
  });
}

class _GestaoEquipePageState extends State<GestaoEquipePage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _titleDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descricaoEmpresaController = TextEditingController();
  int _caracteresDescricao = 0;
  Timer? _debounceDescricao;
  bool _dadosSobreCarregados = false;
  int _anosMercadoNumero = 1;
  String? _pillAnosMercadoSelecionada;

  String _nomeEmpresa = '';
  String _tagEmpresa = 'TAG';
  Color _corTagEmpresa = const Color(0xFF0FB3FF);
  String? _fotoUrlEmpresa;
  String? _bannerUrlEmpresa;
  String? _fotoPerfilProprietario;
  String? _nomeProprietario;
  List<OficioInfo> _oficiosEquipe = [];
  List<ServicoProfissional> _servicosEmpresa = [];

  bool _carregandoEmpresa = false;
  bool _enviandoFotoEmpresa = false;
  bool _enviandoBannerEmpresa = false;

  int? _idUsuario;
  int? _idProfissional;
  int? _idPerfil;
  int? _idGrupoEmpresa;

  List<_MembroEquipe> _membros = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosEmpresa();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _debounceDescricao?.cancel();
    _descricaoEmpresaController.dispose();
    super.dispose();
  }

  Color _corFromHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return const Color(0xFF0FB3FF);
    var value = hex.trim().replaceAll('#', '');
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFF0FB3FF);
    return Color(parsed);
  }

  String _corParaHex(Color color) {
    return '0xFF${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Color _corContraste(Color c) {
    final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return lum > 0.55 ? Colors.black : Colors.white;
  }

  String _obterIniciaisEmpresa(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'EM';
    if (partes.length == 1) {
      return partes.first
          .substring(0, math.min(2, partes.first.length))
          .toUpperCase();
    }
    return '${partes.first[0]}${partes[1][0]}'.toUpperCase();
  }

  Future<void> _carregarDadosEmpresa() async {
    setState(() => _carregandoEmpresa = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregandoEmpresa = false);
        return;
      }

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url, fk_tipo_pessoa')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (usuario == null) {
        if (mounted) setState(() => _carregandoEmpresa = false);
        return;
      }

      _idUsuario = (usuario['id_usuario'] as num?)?.toInt();
      final nomeUsuario = usuario['nome']?.toString().trim();
      final fotoUsuario = usuario['foto_perfil_url']?.toString();
      _nomeProprietario = nomeUsuario;
      _fotoPerfilProprietario = fotoUsuario;
      final fkTipoPessoa = usuario['fk_tipo_pessoa'];

      String? nomeFantasiaPj;
      if (fkTipoPessoa != null) {
        final assTipo = await supabase
            .from('ass_tipo_pessoa')
            .select('fk_pessoa_juridica')
            .eq('id_tipo_pessoa', fkTipoPessoa)
            .maybeSingle();

        final fkPj = assTipo?['fk_pessoa_juridica'];
        if (fkPj != null) {
          final pj = await supabase
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

      if (_idUsuario != null) {
        final dadosProf = await supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_perfil, fk_grupo_empresa')
            .eq('fk_usuario', _idUsuario!)
            .maybeSingle();

        _idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
        _idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
        _idGrupoEmpresa = (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();

        // 1. Tenta buscar pelo fk_grupo_empresa vinculado diretamente
        if (_idGrupoEmpresa != null) {
          Map<String, dynamic>? grupo;
          try {
            grupo = await supabase
                .from('grupo_empresa')
                .select(
                  'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, descricao_empresa, anos_mercado',
                )
                .eq('id_grupo_empresa', _idGrupoEmpresa!)
                .maybeSingle();
          } catch (_) {
            grupo = await supabase
                .from('grupo_empresa')
                .select(
                  'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa',
                )
                .eq('id_grupo_empresa', _idGrupoEmpresa!)
                .maybeSingle();
          }

          if (grupo != null) {
            final nomeGrupo = grupo['nome_empresa']?.toString().trim();
            final tagGrupo = grupo['tag_empresa']?.toString().trim();
            final corGrupo = grupo['cor_tag_empresa']?.toString();
            final fotoGrupo = grupo['foto_url_empresa']?.toString();
            final bannerGrupo = grupo['banner_url_empresa']?.toString();
            _aplicarSobreEmpresa(grupo);

            if (mounted) {
              setState(() {
                if (nomeGrupo != null && nomeGrupo.isNotEmpty) {
                  _nomeEmpresa = nomeGrupo;
                } else if (nomeFantasiaPj != null && nomeFantasiaPj.isNotEmpty) {
                  _nomeEmpresa = nomeFantasiaPj;
                  if (_idGrupoEmpresa != null) {
                    supabase
                        .from('grupo_empresa')
                        .update({'nome_empresa': nomeFantasiaPj})
                        .eq('id_grupo_empresa', _idGrupoEmpresa!);
                  }
                } else if (nomeUsuario != null && nomeUsuario.isNotEmpty) {
                  _nomeEmpresa = nomeUsuario;
                }

                if (tagGrupo != null && tagGrupo.isNotEmpty) {
                  _tagEmpresa = tagGrupo.toUpperCase();
                } else {
                  _tagEmpresa = 'TAG';
                }

                if (corGrupo != null && corGrupo.isNotEmpty)
                  _corTagEmpresa = _corFromHex(corGrupo);
                _fotoUrlEmpresa = fotoGrupo;
                _bannerUrlEmpresa = bannerGrupo;
                _carregandoEmpresa = false;
              });
            }
            await _carregarMembrosEConvites();
            return;
          }
        }

        // 2. Se fk_grupo_empresa for nulo mas temos fk_perfil, busca em grupo_empresa por fk_perfil
        if (_idPerfil != null) {
          Map<String, dynamic>? grupo;
          try {
            grupo = await supabase
                .from('grupo_empresa')
                .select(
                  'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, descricao_empresa, anos_mercado',
                )
                .eq('fk_perfil', _idPerfil!)
                .maybeSingle();
          } catch (_) {
            grupo = await supabase
                .from('grupo_empresa')
                .select(
                  'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa',
                )
                .eq('fk_perfil', _idPerfil!)
                .maybeSingle();
          }

          if (grupo != null) {
            _idGrupoEmpresa = (grupo['id_grupo_empresa'] as num?)?.toInt();
            final nomeGrupo = grupo['nome_empresa']?.toString().trim();
            final tagGrupo = grupo['tag_empresa']?.toString().trim();
            final corGrupo = grupo['cor_tag_empresa']?.toString();
            final fotoGrupo = grupo['foto_url_empresa']?.toString();
            final bannerGrupo = grupo['banner_url_empresa']?.toString();
            _aplicarSobreEmpresa(grupo);

            if (_idGrupoEmpresa != null && _idProfissional != null) {
              await supabase
                  .from('dados_profissionais')
                  .update({'fk_grupo_empresa': _idGrupoEmpresa})
                  .eq('id_profissional', _idProfissional!);
            }

            if (mounted) {
              setState(() {
                if (nomeGrupo != null && nomeGrupo.isNotEmpty) {
                  _nomeEmpresa = nomeGrupo;
                } else if (nomeFantasiaPj != null && nomeFantasiaPj.isNotEmpty) {
                  _nomeEmpresa = nomeFantasiaPj;
                  if (_idGrupoEmpresa != null) {
                    supabase
                        .from('grupo_empresa')
                        .update({'nome_empresa': nomeFantasiaPj})
                        .eq('id_grupo_empresa', _idGrupoEmpresa!);
                  }
                } else if (nomeUsuario != null && nomeUsuario.isNotEmpty) {
                  _nomeEmpresa = nomeUsuario;
                }

                if (tagGrupo != null && tagGrupo.isNotEmpty) {
                  _tagEmpresa = tagGrupo.toUpperCase();
                } else {
                  _tagEmpresa = 'TAG';
                }

                if (corGrupo != null && corGrupo.isNotEmpty)
                  _corTagEmpresa = _corFromHex(corGrupo);
                _fotoUrlEmpresa = fotoGrupo;
                _bannerUrlEmpresa = bannerGrupo;
                _carregandoEmpresa = false;
              });
            }
            await _carregarMembrosEConvites();
            return;
          }
        }
      }

      // 3. Fallback se ainda não configurado na tabela grupo_empresa
      if (mounted) {
        setState(() {
          if (nomeFantasiaPj != null && nomeFantasiaPj.isNotEmpty) {
            _nomeEmpresa = nomeFantasiaPj;
          } else if (nomeUsuario != null && nomeUsuario.isNotEmpty) {
            _nomeEmpresa = nomeUsuario;
          }
          _carregandoEmpresa = false;
        });
      }
      await _carregarMembrosEConvites();
    } catch (e) {
      debugPrint('Erro ao carregar dados da empresa: $e');
      if (mounted) setState(() => _carregandoEmpresa = false);
    }
  }

  Future<void> _carregarMembrosEConvites() async {
    try {
      final supabase = Supabase.instance.client;
      final List<_MembroEquipe> lista = [];

      // Garante foto do profissional proprietário a partir da tabela 'usuarios'
      if (_fotoPerfilProprietario == null) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final u = await supabase
              .from('usuarios')
              .select('foto_perfil_url, nome')
              .eq('auth_id', user.id)
              .maybeSingle();
          _fotoPerfilProprietario = u?['foto_perfil_url']?.toString();
          if (u?['nome'] != null) {
            _nomeProprietario = u!['nome'].toString().trim();
          }
        }
      }

      // 1. Membro proprietário / nós mesmos (usa a foto do profissional da tabela 'usuarios')
      final meuNome = _nomeProprietario ?? _nomeEmpresa;
      lista.add(
        _MembroEquipe(
          id: 'prop_${_idProfissional ?? 0}',
          idProfissional: _idProfissional,
          nome: 'Você (Proprietário)',
          cargo: 'Administrador da Empresa',
          tagFuncao: 'Proprietário',
          corTagBg: const Color(0xFFEFF6FF),
          corTagTexto: const Color(0xFF0284C7),
          isOnline: true,
          isPendente: false,
          fotoUrl: _fotoPerfilProprietario,
          iniciais: _obterIniciaisEmpresa(meuNome),
        ),
      );

      if (_idGrupoEmpresa != null) {
        // 2. Membros ativos da equipe (dados_profissionais com fk_grupo_empresa)
        try {
          final membrosAtivos = await supabase
              .from('dados_profissionais')
              .select(
                'id_profissional, fk_usuario, usuarios(nome, foto_perfil_url)',
              )
              .eq('fk_grupo_empresa', _idGrupoEmpresa!);

          for (final m in membrosAtivos) {
            final idProf = (m['id_profissional'] as num?)?.toInt();
            if (idProf == _idProfissional) continue;

            final u = m['usuarios'] as Map<String, dynamic>?;
            final nome = u?['nome']?.toString().trim() ?? 'Colaborador';
            final foto = u?['foto_perfil_url']?.toString();

            lista.add(
              _MembroEquipe(
                id: 'prof_$idProf',
                idProfissional: idProf,
                nome: nome,
                cargo: 'Profissional da Equipe',
                tagFuncao: 'Funcionário',
                corTagBg: const Color(0xFFF1F5F9),
                corTagTexto: const Color(0xFF64748B),
                isOnline: true,
                isPendente: false,
                fotoUrl: foto,
                iniciais: _obterIniciaisEmpresa(nome),
              ),
            );
          }
        } catch (e) {
          debugPrint('Erro ao buscar membros ativos: $e');
        }

        // 3. Convites pendentes (convites_empresa com fk_grupo_empresa)
        try {
          List<dynamic>? convites;
          try {
            convites = await supabase
                .from('convites_empresa')
                .select(
                  '*, dados_profissionais(id_profissional, fk_usuario, usuarios(nome, foto_perfil_url))',
                )
                .eq('fk_grupo_empresa', _idGrupoEmpresa!);
          } catch (_) {
            convites = await supabase
                .from('convites_empresa')
                .select('*')
                .eq('fk_grupo_empresa', _idGrupoEmpresa!);
          }

          if (convites != null) {
            for (final c in convites) {
              final idConvite =
                  (c['id_convite_empresa'] ??
                          c['id_convite'] ??
                          c['id'] as num?)
                      ?.toInt();
              final idProf =
                  (c['fk_dados_profissionais'] ??
                          c['fk_dados_profissionais'] as num?)
                      ?.toInt();
              String nome = 'Profissional Convidado';
              String? foto;

              final dp = c['dados_profissionais'] as Map<String, dynamic>?;
              if (dp != null) {
                final u = dp['usuarios'] as Map<String, dynamic>?;
                if (u != null && u['nome'] != null) {
                  nome = u['nome'].toString().trim();
                  foto = u['foto_perfil_url']?.toString();
                }
              } else if (idProf != null) {
                try {
                  final p = await supabase
                      .from('dados_profissionais')
                      .select('usuarios(nome, foto_perfil_url)')
                      .eq('id_profissional', idProf)
                      .maybeSingle();
                  final u = p?['usuarios'] as Map<String, dynamic>?;
                  if (u != null && u['nome'] != null) {
                    nome = u['nome'].toString().trim();
                    foto = u['foto_perfil_url']?.toString();
                  }
                } catch (_) {}
              }

              lista.add(
                _MembroEquipe(
                  id: 'conv_${idConvite ?? idProf}',
                  idConvite: idConvite,
                  idProfissional: idProf,
                  nome: nome,
                  cargo: 'Aguardando confirmação',
                  tagFuncao: 'Convite Pendente',
                  corTagBg: const Color(0xFFFEF3C7),
                  corTagTexto: const Color(0xFFD97706),
                  isOnline: false,
                  isPendente: true,
                  fotoUrl: foto,
                  iniciais: _obterIniciaisEmpresa(nome),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Erro ao buscar convites pendentes: $e');
        }
      }

      // 4. Carregar somente os ofícios definidos para a empresa.
      List<OficioInfo> oficiosEquipe = [];
      if (_idGrupoEmpresa != null) {
        try {
          final idsOficios = await supabase
              .from('ass_oficio_grupo_empresa')
              .select('fk_oficio')
              .eq('fk_grupo_empresa', _idGrupoEmpresa!);
          final ids = idsOficios
              .map((row) => (row['fk_oficio'] as num?)?.toInt())
              .whereType<int>()
              .toList();
          if (ids.isNotEmpty) {
            final oficiosData = await supabase
                .from('oficios')
                .select('funcao, categoria, cor')
                .inFilter('id_oficio', ids);
            oficiosEquipe = oficiosData
                .map<OficioInfo>(OficioInfo.fromMap)
                .where((oficio) => oficio.funcao.isNotEmpty)
                .toList();
          }
        } catch (e) {
          debugPrint('Erro ao carregar ofícios da empresa: $e');
        }
      }

      final servicosEmpresa = _idGrupoEmpresa == null
          ? <ServicoProfissional>[]
          : (await ServicosProfissionalService.buscarServicosEmpresa(
              _idGrupoEmpresa!,
            ))
              // Gestão da empresa: mostra SÓ serviços da empresa
              // (fk_grupo_empresa == grupo). Nunca os individuais (CNPJ).
              .where(
                (s) =>
                    s.fkGrupoEmpresa != null &&
                    s.fkGrupoEmpresa == _idGrupoEmpresa,
              )
              .toList();

      if (mounted) {
        setState(() {
          _membros = lista;
          _oficiosEquipe = oficiosEquipe;
          _servicosEmpresa = servicosEmpresa;
        });
      }
    } catch (e) {
      debugPrint('Erro geral ao carregar membros e convites: $e');
    }
  }

  Future<int?> _obterOuCriarGrupoEmpresa() async {
    if (_idGrupoEmpresa != null) return _idGrupoEmpresa;
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      if (_idUsuario == null) {
        final usuario = await supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', user.id)
            .maybeSingle();
        _idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      }
      if (_idUsuario == null) return null;

      if (_idProfissional == null || _idPerfil == null) {
        final dadosProf = await supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_perfil, fk_grupo_empresa')
            .eq('fk_usuario', _idUsuario!)
            .maybeSingle();

        _idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
        _idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
        _idGrupoEmpresa = (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();
      }

      if (_idPerfil == null && _idProfissional != null) {
        final novoPerfil = await supabase
            .from('perfil')
            .insert({'tipo_perfil': 'Loja'})
            .select('id_perfil')
            .single();
        _idPerfil = (novoPerfil['id_perfil'] as num?)?.toInt();
        if (_idPerfil != null) {
          await supabase
              .from('dados_profissionais')
              .update({'fk_perfil': _idPerfil})
              .eq('id_profissional', _idProfissional!);
        }
      }

      if (_idPerfil == null) return null;
      if (_idGrupoEmpresa != null) return _idGrupoEmpresa;

      final existente = await supabase
          .from('grupo_empresa')
          .select('id_grupo_empresa')
          .eq('fk_perfil', _idPerfil!)
          .maybeSingle();

      if (existente != null) {
        _idGrupoEmpresa = (existente['id_grupo_empresa'] as num?)?.toInt();
      } else {
        final novoGrupo = await supabase
            .from('grupo_empresa')
            .insert({
              'fk_perfil': _idPerfil!,
              'nome_empresa': _nomeEmpresa,
              'tag_empresa': _tagEmpresa,
              'cor_tag_empresa': _corParaHex(_corTagEmpresa),
            })
            .select('id_grupo_empresa')
            .single();

        _idGrupoEmpresa = (novoGrupo['id_grupo_empresa'] as num?)?.toInt();
      }

      if (_idProfissional != null && _idGrupoEmpresa != null) {
        await supabase
            .from('dados_profissionais')
            .update({'fk_grupo_empresa': _idGrupoEmpresa})
            .eq('id_profissional', _idProfissional!);
      }

      return _idGrupoEmpresa;
    } catch (e) {
      debugPrint('Erro ao obter/criar grupo_empresa: $e');
      return null;
    }
  }

  Future<void> _escolherOuRemoverFotoEmpresa() async {
    if (_fotoUrlEmpresa != null && _fotoUrlEmpresa!.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _primaryBlue,
                ),
                title: const Text('Alterar foto da empresa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _escolherFotoEmpresa();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Remover foto da empresa',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removerFotoEmpresa();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _escolherFotoEmpresa();
    }
  }

  Future<void> _escolherFotoEmpresa() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _enviandoFotoEmpresa = true);

      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null)
        throw Exception('Não foi possível identificar a empresa.');

      final supabase = Supabase.instance.client;
      final fileName =
          'empresa_foto_${idGrupo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const bucketName = 'Foto Perfil';

      if (kIsWeb) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        await supabase.storage
            .from(bucketName)
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      } else {
        final file = File(pickedFile.path);
        await supabase.storage
            .from(bucketName)
            .upload(
              fileName,
              file,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      }

      final publicUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      await supabase
          .from('grupo_empresa')
          .update({'foto_url_empresa': publicUrl})
          .eq('id_grupo_empresa', idGrupo);

      if (mounted) {
        setState(() {
          _fotoUrlEmpresa = publicUrl;
          _enviandoFotoEmpresa = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto da empresa atualizada com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar foto da empresa: $e');
      if (mounted) {
        setState(() => _enviandoFotoEmpresa = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removerFotoEmpresa() async {
    try {
      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null) return;

      final supabase = Supabase.instance.client;
      await supabase
          .from('grupo_empresa')
          .update({'foto_url_empresa': null})
          .eq('id_grupo_empresa', idGrupo);

      if (mounted) {
        setState(() {
          _fotoUrlEmpresa = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto da empresa removida com sucesso!'),
            backgroundColor: _titleDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao remover foto da empresa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _escolherOuRemoverBannerEmpresa() async {
    if (_bannerUrlEmpresa != null && _bannerUrlEmpresa!.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _primaryBlue,
                ),
                title: const Text('Alterar banner da empresa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _escolherBannerEmpresa();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Remover banner da empresa',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removerBannerEmpresa();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _escolherBannerEmpresa();
    }
  }

  Future<void> _escolherBannerEmpresa() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _enviandoBannerEmpresa = true);

      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null)
        throw Exception('Não foi possível identificar a empresa.');

      final supabase = Supabase.instance.client;
      final fileName =
          'empresa_banner_${idGrupo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const bucketName = 'Foto Perfil';

      if (kIsWeb) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        await supabase.storage
            .from(bucketName)
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      } else {
        final file = File(pickedFile.path);
        await supabase.storage
            .from(bucketName)
            .upload(
              fileName,
              file,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      }

      final publicUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      await supabase
          .from('grupo_empresa')
          .update({'banner_url_empresa': publicUrl})
          .eq('id_grupo_empresa', idGrupo);

      if (mounted) {
        setState(() {
          _bannerUrlEmpresa = publicUrl;
          _enviandoBannerEmpresa = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner da empresa atualizado com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar banner da empresa: $e');
      if (mounted) {
        setState(() => _enviandoBannerEmpresa = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar banner: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removerBannerEmpresa() async {
    try {
      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null) return;

      final supabase = Supabase.instance.client;
      await supabase
          .from('grupo_empresa')
          .update({'banner_url_empresa': null})
          .eq('id_grupo_empresa', idGrupo);

      if (mounted) {
        setState(() {
          _bannerUrlEmpresa = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner da empresa removido com sucesso!'),
            backgroundColor: _titleDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao remover banner da empresa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover banner: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFBAE6FD), Color(0xFF0FB3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.apartment_rounded,
          color: Colors.white.withValues(alpha: 0.35),
          size: 44,
        ),
      ),
    );
  }

  Widget _buildPerfilEmpresarialCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner + Avatar Stack
          SizedBox(
            width: double.infinity,
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Banner
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child:
                      _bannerUrlEmpresa != null && _bannerUrlEmpresa!.isNotEmpty
                      ? Image.network(
                          _bannerUrlEmpresa!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildBannerFallback(),
                        )
                      : _buildBannerFallback(),
                ),
                if (_enviandoBannerEmpresa)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                // 2. Botão de editar/adicionar banner
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _enviandoBannerEmpresa
                          ? null
                          : _escolherOuRemoverBannerEmpresa,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _bannerUrlEmpresa != null
                                  ? Icons.edit_outlined
                                  : Icons.add_photo_alternate_outlined,
                              size: 16,
                              color: _primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _bannerUrlEmpresa != null
                                  ? 'Banner'
                                  : 'Adicionar Banner',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _titleDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 3. Avatar da Empresa (Totalmente dentro dos limites de toque do Stack)
                Positioned(
                  left: 16,
                  top: 80,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _enviandoFotoEmpresa
                        ? null
                        : _escolherOuRemoverFotoEmpresa,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            backgroundImage:
                                _fotoUrlEmpresa != null &&
                                    _fotoUrlEmpresa!.isNotEmpty
                                ? NetworkImage(_fotoUrlEmpresa!)
                                : null,
                            child:
                                _fotoUrlEmpresa == null ||
                                    _fotoUrlEmpresa!.isEmpty
                                ? Text(
                                    _obterIniciaisEmpresa(_nomeEmpresa),
                                    style: const TextStyle(
                                      color: _primaryBlue,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _enviandoFotoEmpresa
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _fotoUrlEmpresa != null
                                        ? Icons.edit
                                        : Icons.camera_alt,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Informações da Empresa + Botão Editar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _carregandoEmpresa
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryBlue,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Carregando...',
                              style: TextStyle(fontSize: 14, color: _textMuted),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nomeEmpresa.isNotEmpty
                                  ? _nomeEmpresa
                                  : 'Nome da Empresa',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _titleDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _corTagEmpresa,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#$_tagEmpresa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _corContraste(_corTagEmpresa),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                ..._oficiosEquipe.map(
                                  (oficio) => TagOficio(
                                    oficio: oficio,
                                    fontSize: 11,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    borderRadius: 6,
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
    );
  }

  void _aplicarSobreEmpresa(Map<String, dynamic> grupo) {
    final desc = grupo['descricao_empresa']?.toString() ?? '';
    final anos = grupo['anos_mercado']?.toString().trim();

    if (!_dadosSobreCarregados) {
      _descricaoEmpresaController.text = desc;
      _caracteresDescricao = desc.length;
      _dadosSobreCarregados = true;
    }

    if (anos != null && anos.isNotEmpty) {
      const pillValores = [
        '<1 ano',
        '2 a 5 anos',
        '6 a 10 anos',
        '11 a 15 anos',
        '15+ anos',
      ];
      if (pillValores.contains(anos)) {
        _pillAnosMercadoSelecionada = anos;
        _anosMercadoNumero = 1;
      } else {
        _pillAnosMercadoSelecionada = null;
        final parsed = int.tryParse(anos);
        _anosMercadoNumero = (parsed != null && parsed >= 1) ? parsed : 1;
      }
    } else {
      _pillAnosMercadoSelecionada = null;
      _anosMercadoNumero = 1;
    }
  }

  void _onDescricaoChanged(String text) {
    setState(() {
      _caracteresDescricao = text.length;
    });
    _debounceDescricao?.cancel();
    _debounceDescricao = Timer(const Duration(milliseconds: 600), () {
      _salvarDescricaoEmpresa(text);
    });
  }

  Future<void> _salvarDescricaoEmpresa(String texto) async {
    try {
      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null) return;
      final supabase = Supabase.instance.client;
      await supabase
          .from('grupo_empresa')
          .update({'descricao_empresa': texto})
          .eq('id_grupo_empresa', idGrupo);
    } catch (e) {
      debugPrint('Erro ao salvar descricao_empresa: $e');
    }
  }

  Future<void> _salvarAnosMercado(String valor) async {
    try {
      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null) return;
      final supabase = Supabase.instance.client;
      await supabase
          .from('grupo_empresa')
          .update({'anos_mercado': valor})
          .eq('id_grupo_empresa', idGrupo);
    } catch (e) {
      debugPrint('Erro ao salvar anos_mercado: $e');
    }
  }

  Widget _buildSecaoSobreEmpresa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.apartment_rounded,
              color: _primaryBlue,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Sobre a Empresa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _titleDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cabeçalho Descrição da Empresa + Contador
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Descrição da Empresa',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                  Text(
                    '$_caracteresDescricao/500',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Textarea com borda arredondada
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: TextField(
                  controller: _descricaoEmpresaController,
                  maxLength: 500,
                  minLines: 4,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Conte um pouco sobre sua empresa, especialidades e diferenciais...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onDescricaoChanged,
                ),
              ),
              const SizedBox(height: 8),

              // Legenda explicativa
              const Text(
                'Esta descrição fica visível no perfil público da empresa para novos clientes.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _textMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),

              // Divisor
              const Divider(
                color: Color(0xFFF1F5F9),
                height: 1,
                thickness: 1,
              ),
              const SizedBox(height: 18),

              // 3. Cabeçalho Anos de Experiência no Mercado
              const Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: _titleDark,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Anos de Experiência no Mercado',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stepper card cinza
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Círculo azul com medalha/fita
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00B0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_anosMercadoNumero ${_anosMercadoNumero == 1 ? 'Ano' : 'Anos'}',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: _titleDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Atuação comprovada',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Controles de decremento, número e incremento
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              if (_anosMercadoNumero > 1) {
                                setState(() {
                                  _anosMercadoNumero--;
                                  _pillAnosMercadoSelecionada = null;
                                });
                                _salvarAnosMercado('$_anosMercadoNumero');
                              } else if (_pillAnosMercadoSelecionada != null) {
                                setState(() {
                                  _pillAnosMercadoSelecionada = null;
                                });
                                _salvarAnosMercado('$_anosMercadoNumero');
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: _titleDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_anosMercadoNumero',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _titleDark,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              setState(() {
                                _anosMercadoNumero++;
                                _pillAnosMercadoSelecionada = null;
                              });
                              _salvarAnosMercado('$_anosMercadoNumero');
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 18,
                                  color: _titleDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Pills de seleção de faixa
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  {'label': 'Menos de 1 ano', 'valor': '<1 ano'},
                  {'label': '2 a 5 anos', 'valor': '2 a 5 anos'},
                  {'label': '6 a 10 anos', 'valor': '6 a 10 anos'},
                  {'label': '11 a 15 anos', 'valor': '11 a 15 anos'},
                  {'label': '15+ anos', 'valor': '15+ anos'},
                ].map((pill) {
                  final isSelected =
                      _pillAnosMercadoSelecionada == pill['valor'];
                  return Material(
                    color: isSelected ? const Color(0xFF00B0FF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _pillAnosMercadoSelecionada = null;
                            _salvarAnosMercado('$_anosMercadoNumero');
                          } else {
                            _pillAnosMercadoSelecionada = pill['valor'];
                            _salvarAnosMercado(pill['valor']!);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00B0FF)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          pill['label']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Divider(
                color: Color(0xFFF1F5F9),
                height: 1,
                thickness: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _convidarFuncionario() async {
    final input = _emailController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, informe o e-mail, CPF ou CNPJ do profissional.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _carregandoEmpresa = true);

    try {
      final supabase = Supabase.instance.client;
      final idGrupo = await _obterOuCriarGrupoEmpresa();
      if (idGrupo == null)
        throw Exception('Não foi possível identificar a empresa.');

      int? idProfissionalAlvo;
      String? nomeAlvo;
      var convitePorCnpj = false;

      if (input.contains('@')) {
        // 1. Busca por e-mail na tabela emails
        final emailReg = await supabase
            .from('emails')
            .select('id_email')
            .ilike('endereco_email', input)
            .maybeSingle();

        int? idEmail = (emailReg?['id_email'] as num?)?.toInt();

        // Busca usuário pelo fk_email ou email
        Map<String, dynamic>? usuario;
        if (idEmail != null) {
          usuario = await supabase
              .from('usuarios')
              .select('id_usuario, nome')
              .eq('fk_email', idEmail)
              .maybeSingle();
        }

        if (usuario == null) {
          try {
            usuario = await supabase
                .from('usuarios')
                .select('id_usuario, nome')
                .ilike('email', input)
                .maybeSingle();
          } catch (_) {}
        }

        if (usuario != null) {
          final idUser = (usuario['id_usuario'] as num?)?.toInt();
          nomeAlvo = usuario['nome']?.toString();
          if (idUser != null) {
            final dp = await supabase
                .from('dados_profissionais')
                .select('id_profissional, fk_grupo_empresa')
                .eq('fk_usuario', idUser)
                .maybeSingle();
            idProfissionalAlvo = (dp?['id_profissional'] as num?)?.toInt();
          }
        }
      } else {
        final documentoDigits = input.replaceAll(RegExp(r'\D'), '');
        convitePorCnpj = documentoDigits.length == 14;

        // Valida o CPF/CNPJ com a mesma verificação usada no cadastro
        // (ConsultaCadastroService.validarDocumento). Evita prosseguir com
        // um documento inválido no fluxo de convite/criação de conta.
        if (documentoDigits.length == 11 || documentoDigits.length == 14) {
          bool documentoValido = false;
          try {
            final validacao = await ConsultaCadastroService()
                .validarDocumento(documentoDigits);
            documentoValido = validacao.valido;
          } catch (_) {
            // Fallback offline: valida apenas os dígitos verificadores.
            documentoValido = documentoDigits.length == 11
                ? validarCpf(documentoDigits)
                : validarCnpj(documentoDigits);
          }
          if (!documentoValido) {
            if (mounted) {
              setState(() => _carregandoEmpresa = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'CPF/CNPJ inválido. Verifique os números digitados.',
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }

        if (convitePorCnpj) {
          // Busca o usuário empresarial por CNPJ.
          final pj = await supabase
              .from('pessoa_juridica')
              .select('id_pessoa_juridica')
              .eq('cnpj', documentoDigits)
              .maybeSingle();
          final pjId = (pj?['id_pessoa_juridica'] as num?)?.toInt();

          if (pjId != null) {
            final ass = await supabase
                .from('ass_tipo_pessoa')
                .select('id_tipo_pessoa')
                .eq('fk_pessoa_juridica', pjId)
                .maybeSingle();
            final idTipo = (ass?['id_tipo_pessoa'] as num?)?.toInt();

            if (idTipo != null) {
              final usuario = await supabase
                  .from('usuarios')
                  .select('id_usuario, nome')
                  .eq('fk_tipo_pessoa', idTipo)
                  .maybeSingle();
              final idUser = (usuario?['id_usuario'] as num?)?.toInt();
              nomeAlvo = usuario?['nome']?.toString();

              if (idUser != null) {
                final dp = await supabase
                    .from('dados_profissionais')
                    .select('id_profissional, fk_grupo_empresa, fk_perfil')
                    .eq('fk_usuario', idUser)
                    .maybeSingle();
                idProfissionalAlvo = (dp?['id_profissional'] as num?)?.toInt();
              }
            }
          }
        } else {
          // Busca por CPF.
          final cpfDigits = documentoDigits;
          if (cpfDigits.length != 11) {
            if (mounted) {
              setState(() => _carregandoEmpresa = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Documento inválido. Digite um CPF (11 dígitos), CNPJ (14 dígitos) ou e-mail válido.',
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }

          final pf = await supabase
              .from('pessoa_fisica')
              .select('id_pessoa_fisica')
              .eq('cpf', cpfDigits)
              .maybeSingle();

          final pfId = (pf?['id_pessoa_fisica'] as num?)?.toInt();
          if (pfId != null) {
            final ass = await supabase
                .from('ass_tipo_pessoa')
                .select('id_tipo_pessoa')
                .eq('fk_pessoa_fisica', pfId)
                .maybeSingle();

            final idTipo = (ass?['id_tipo_pessoa'] as num?)?.toInt();
            if (idTipo != null) {
              final usuario = await supabase
                  .from('usuarios')
                  .select('id_usuario, nome')
                  .eq('fk_tipo_pessoa', idTipo)
                  .maybeSingle();

              if (usuario != null) {
                final idUser = (usuario['id_usuario'] as num?)?.toInt();
                nomeAlvo = usuario['nome']?.toString();
                if (idUser != null) {
                  final dp = await supabase
                      .from('dados_profissionais')
                      .select('id_profissional, fk_grupo_empresa')
                      .eq('fk_usuario', idUser)
                      .maybeSingle();
                  idProfissionalAlvo = (dp?['id_profissional'] as num?)
                      ?.toInt();
                }
              }
            }
          } else {
            final dadosCriacao = await _abrirPopoverCriarProfissional(
              cpf: cpfDigits,
              idGrupo: idGrupo,
            );
            if (dadosCriacao) {
              _emailController.clear();
              await _carregarMembrosEConvites();
              if (mounted) {
                setState(() => _carregandoEmpresa = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conta criada e associada à sua empresa.'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
            if (mounted) setState(() => _carregandoEmpresa = false);
            return;
          }
        }
      }

      if (idProfissionalAlvo == null) {
        if (mounted) {
          setState(() => _carregandoEmpresa = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nenhum profissional cadastrado encontrado com este e-mail ou CPF.',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (idProfissionalAlvo == _idProfissional) {
        if (mounted) {
          setState(() => _carregandoEmpresa = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você não pode enviar um convite para si mesmo.'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (convitePorCnpj) {
        final dadosProfissional = await supabase
            .from('dados_profissionais')
            .select('fk_perfil')
            .eq('id_profissional', idProfissionalAlvo)
            .maybeSingle();
        final fkPerfil = (dadosProfissional?['fk_perfil'] as num?)?.toInt();
        final perfil = fkPerfil == null
            ? null
            : await supabase
                  .from('perfil')
                  .select('tipo_perfil')
                  .eq('id_perfil', fkPerfil)
                  .maybeSingle();
        final tipoPerfil = perfil?['tipo_perfil']?.toString().trim();

        if (tipoPerfil == 'Loja') {
          if (mounted) {
            setState(() => _carregandoEmpresa = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Este profissional é proprietário de uma loja e não pode entrar como membro da equipe.',
                ),
                backgroundColor: Colors.orangeAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        if (tipoPerfil != 'Independente') {
          if (mounted) {
            setState(() => _carregandoEmpresa = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'O profissional informado precisa ter o perfil Independente.',
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      // Verifica se já faz parte da empresa
      final profCheck = await supabase
          .from('dados_profissionais')
          .select('fk_grupo_empresa')
          .eq('id_profissional', idProfissionalAlvo)
          .maybeSingle();

      final grupoAtual = (profCheck?['fk_grupo_empresa'] as num?)?.toInt();

      if (grupoAtual == idGrupo) {
        if (mounted) {
          setState(() => _carregandoEmpresa = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este profissional já faz parte da sua empresa.'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (grupoAtual != null) {
        if (mounted) {
          setState(() => _carregandoEmpresa = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este profissional já faz parte de outra empresa e só pode participar de uma.',
              ),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Evita enviar convite duplicado (já pendente para este profissional/empresa)
      Map<String, dynamic>? conviteExistente;
      try {
        conviteExistente = await supabase
            .from('convites_empresa')
            .select('id_convite_empresa')
            .eq('fk_grupo_empresa', idGrupo)
            .eq('fk_dados_profissionais', idProfissionalAlvo)
            .maybeSingle();
      } catch (_) {
        conviteExistente = await supabase
            .from('convites_empresa')
            .select('id_convite_empresa')
            .eq('fk_grupo_empresa', idGrupo)
            .eq('fk_dados_profissionais', idProfissionalAlvo)
            .maybeSingle();
      }

      if (conviteExistente != null) {
        if (mounted) {
          setState(() => _carregandoEmpresa = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Já existe um convite pendente para este profissional.',
              ),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Salva convite na tabela convites_empresa
      final agora = DateTime.now().toIso8601String();
      try {
        await supabase.from('convites_empresa').insert({
          'fk_grupo_empresa': idGrupo,
          'fk_dados_profissionais': idProfissionalAlvo,
          'data_convite': agora,
        });
      } catch (_) {
        await supabase.from('convites_empresa').insert({
          'fk_grupo_empresa': idGrupo,
          'fk_dados_profissionais': idProfissionalAlvo,
          'data_convite': agora,
        });
      }

      _emailController.clear();
      await _carregarMembrosEConvites();

      if (mounted) {
        setState(() => _carregandoEmpresa = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Convite enviado com sucesso para ${nomeAlvo ?? 'o profissional'}!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao enviar convite: $e');
      if (mounted) {
        setState(() => _carregandoEmpresa = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar convite: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _abrirPopoverCriarProfissional({
    required String cpf,
    required int idGrupo,
  }) async {
    final dados = await showModalBottomSheet<DadosNovoProfissional>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CriarProfissionalPopover(cpf: cpf),
    );
    if (dados == null) return false;

    try {
      await ProfissionalEquipeService().criarConta(
        cpf: cpf,
        senha: dados.senha,
        idGrupoEmpresa: idGrupo,
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível criar a conta: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  void _copiarLink() {
    Clipboard.setData(
      const ClipboardData(text: 'https://consertaja.app/convite-empresa'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copiado para a área de transferência!'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removerMembro(String id, String nome) {
    final membro = _membros.firstWhere(
      (m) => m.id == id,
      orElse: () => _membros.first,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(membro.isPendente ? 'Cancelar Convite' : 'Remover Membro'),
        content: Text(
          membro.isPendente
              ? 'Deseja cancelar o convite para $nome?'
              : 'Tem certeza que deseja remover $nome da equipe?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final supabase = Supabase.instance.client;
                if (membro.isPendente) {
                  if (membro.idConvite != null) {
                    try {
                      await supabase
                          .from('convites_empresa')
                          .delete()
                          .eq('id_convite_empresa', membro.idConvite!);
                    } catch (_) {
                      await supabase
                          .from('convites_empresa')
                          .delete()
                          .eq('id_convite', membro.idConvite!);
                    }
                  } else if (membro.idProfissional != null &&
                      _idGrupoEmpresa != null) {
                    try {
                      await supabase.from('convites_empresa').delete().match({
                        'fk_grupo_empresa': _idGrupoEmpresa!,
                        'fk_dados_profissionais': membro.idProfissional!,
                      });
                    } catch (_) {
                      await supabase.from('convites_empresa').delete().match({
                        'fk_grupo_empresa': _idGrupoEmpresa!,
                        'fk_dados_profissionais': membro.idProfissional!,
                      });
                    }
                  }
                } else if (membro.idProfissional != null) {
                  await supabase
                      .from('dados_profissionais')
                      .update({'fk_grupo_empresa': null})
                      .eq('id_profissional', membro.idProfissional!);
                }

                await _carregarMembrosEConvites();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        membro.isPendente
                            ? 'Convite para $nome cancelado.'
                            : '$nome foi removido da equipe.',
                      ),
                      backgroundColor: _titleDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Erro ao remover/cancelar: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(membro.isPendente ? 'Cancelar Convite' : 'Remover'),
          ),
        ],
      ),
    );
  }

  void _reenviarConvite(String nome) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Convite reenviado para $nome.'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Gestão de Empresa',
          style: TextStyle(
            color: _primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _primaryBlue),
            onPressed: () async {
              final atualizou = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracoesEmpresaPage(),
                ),
              );
              if (atualizou == true) {
                _carregarDadosEmpresa();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= SEÇÃO PERFIL EMPRESARIAL =================
            const Text(
              'Perfil Empresarial',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            _buildPerfilEmpresarialCard(),
            const SizedBox(height: 20),

            // ================= CARD NOVO MEMBRO =================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: _titleDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Novo Membro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _titleDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Expanda sua equipe enviando um convite direto.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: _emailController,
                      inputFormatters: [_DocumentoOuEmailInputFormatter()],
                      decoration: const InputDecoration(
                        hintText: 'E-mail, CPF ou CNPJ do profissional.',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _convidarFuncionario(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _convidarFuncionario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Convidar Profissional',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(
                    color: Color(0xFFF1F5F9),
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Compartilhe o acesso',
                        style: TextStyle(fontSize: 14, color: _textMuted),
                      ),
                      const Spacer(),
                      Material(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _copiarLink,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, color: _primaryBlue, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Copiar Link',
                                  style: TextStyle(
                                    color: _primaryBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= SEÇÃO EQUIPE ATUAL =================
            Row(
              children: [
                const Text(
                  'Equipe Atual',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_membros.length} Membros',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista de Cards dos Membros
            ..._membros.map((membro) => _buildMembroCard(membro)),
            const SizedBox(height: 24),
            _buildServicosDisponibilizados(),
            const SizedBox(height: 24),

            // ================= SEÇÃO SOBRE A EMPRESA =================
            _buildSecaoSobreEmpresa(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBarProfissional(
        currentIndex: 4,
        // Aberta a partir da conta empresa: 5º item fica "Empresa".
        // Mesma chave da bottom bar de Mensagens: o Flutter reutiliza o
        // MESMO elemento ao alternar Gestão <-> Mensagens, sem reconstruir
        // nem piscar os itens a partir da 2ª vez.
        key: const ValueKey('bottomProfissional'),
        isContaEmpresa: true,
        // Tocar em Empresa estando na Gestão recarrega os dados.
        onReselecionarAbaAtual: (_) => _carregarDadosEmpresa(),
        onTap: (index) {
          if (index == 0) {
            AppNavigationUtil.navegarAba(
              context,
              const TelaHomeProfissional(isVisitante: false),
              isHome: true,
            );
            return;
          }
          if (index == 2) {
            AppNavigationUtil.navegarAba(
              context,
              const TelaMensagensPage(
                isVisitante: false,
                isProfissional: true,
              ),
              isHome: false,
            );
            return;
          }
          if (index == 3) {
            // Aba Serviços: abre os solicitados (conta empresa), em vez de
            // voltar para a home do profissional.
            Navigator.of(context).push(
              AppNavigationUtil.rotaSemAnimacao(
                const MeusServicosSolicitadosPage(),
                nome: 'MeusServicosSolicitadosPage',
              ),
            );
            return;
          }
          if (index == 4) {
            // Já está na Empresa: volta para a Home da empresa.
            AppNavigationUtil.navegarAba(
              context,
              const TelaHomeProfissional(isVisitante: false),
              isHome: true,
            );
            return;
          }
          // Radar (1): volta para a Home e deixa a home decidir a aba,
          // mantendo a barra consistente.
          AppNavigationUtil.navegarAba(
            context,
            const TelaHomeProfissional(isVisitante: false),
            isHome: true,
          );
        },
      ),
    );
  }

  Widget _buildMembroCard(_MembroEquipe membro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(membro),
          const SizedBox(width: 14),

          // Informações do membro
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membro.nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  membro.cargo,
                  style: const TextStyle(fontSize: 13, color: _textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: membro.corTagBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    membro.tagFuncao,
                    style: TextStyle(
                      fontSize: 11,
                      color: membro.corTagTexto,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ações à direita
          _buildAcoesMembro(membro),
        ],
      ),
    );
  }

  Widget _buildServicosDisponibilizados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Serviços Disponibilizados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _titleDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _idGrupoEmpresa == null
                  ? null
                  : () async {
                      final atualizou = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdicionarServicoProfissionalPage(
                            idGrupoEmpresaInicial: _idGrupoEmpresa,
                            associacaoEmpresaInicial: true,
                            abrirFormularioInicial: true,
                            // Gestão da empresa: sempre "Loja", independente
                            // da conta ativa no momento.
                            forcarContaAtiva: true,
                            forcarModoEmpresa: true,
                          ),
                        ),
                      );
                      if (atualizou == true) _carregarMembrosEConvites();
                    },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar serviço'),
              style: TextButton.styleFrom(
                foregroundColor: _primaryBlue,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_servicosEmpresa.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: const Text(
              'Esta empresa ainda não possui serviços',
              style: TextStyle(fontSize: 14, color: _textMuted),
            ),
          )
        else
          ..._servicosEmpresa.map(_buildServicoEmpresaCard),
      ],
    );
  }

  Widget _buildServicoEmpresaCard(ServicoProfissional servico) {
    final cor = _corFromHex(servico.cor);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: servico.imagemUrl != null && servico.imagemUrl!.isNotEmpty
                ? Image.network(
                    servico.imagemUrl!,
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildImagemServicoFallback(),
                  )
                : _buildImagemServicoFallback(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildTagServico('#$_tagEmpresa', _corTagEmpresa),
                    _buildTagServico(
                      (servico.funcao ?? 'GERAL').toUpperCase(),
                      cor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        servico.titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF202124),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar serviço',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: _primaryBlue,
                        size: 19,
                      ),
                      onPressed: () => _editarServicoEmpresa(servico),
                    ),
                    IconButton(
                      tooltip: 'Excluir serviço',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => _excluirServicoEmpresa(servico),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  servico.descricao,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Color(0xFF4B4F58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarServicoEmpresa(ServicoProfissional servico) async {
    final atualizou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdicionarServicoProfissionalPage(
          servicoParaEditar: servico,
          idGrupoEmpresaInicial: _idGrupoEmpresa,
          // Gestão da empresa: sempre "Loja", independente
          // da conta ativa no momento.
          forcarContaAtiva: true,
          forcarModoEmpresa: true,
        ),
      ),
    );
    if (atualizou == true) _carregarMembrosEConvites();
  }

  Future<void> _excluirServicoEmpresa(ServicoProfissional servico) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir serviço?'),
        content: Text('Deseja excluir "${servico.titulo}" da empresa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final excluiu = await ServicosProfissionalService.desativarServico(
      servico.id,
    );
    if (!mounted) return;
    if (excluiu) {
      await _carregarMembrosEConvites();
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          excluiu ? 'Serviço excluído da empresa.' : 'Não foi possível excluir o serviço.',
        ),
        backgroundColor: excluiu ? const Color(0xFF10B981) : Colors.redAccent,
      ),
    );
  }

  Widget _buildTagServico(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: _corContraste(cor),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildImagemServicoFallback() {
    return Container(
      width: 78,
      height: 78,
      color: const Color(0xFFE9E7E4),
      child: const Icon(
        Icons.home_repair_service_rounded,
        color: Color(0xFF64748B),
        size: 30,
      ),
    );
  }

  Widget _buildAvatar(_MembroEquipe membro) {
    if (membro.isPendente) {
      return CustomPaint(
        painter: _DashedCirclePainter(
          color: const Color(0xFFCBD5E1),
          strokeWidth: 1.5,
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              membro.iniciais ?? 'RM',
              style: const TextStyle(
                color: _textMuted,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child: membro.fotoUrl != null
                ? Image.network(
                    membro.fotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: Center(
                        child: Text(
                          membro.iniciais ?? 'U',
                          style: const TextStyle(
                            color: _textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: Text(
                        membro.iniciais ?? 'U',
                        style: const TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (membro.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAcoesMembro(_MembroEquipe membro) {
    if (membro.isPendente) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.forward_to_inbox_rounded,
              color: _textMuted,
              size: 20,
            ),
            tooltip: 'Reenviar convite',
            splashRadius: 20,
            onPressed: () => _reenviarConvite(membro.nome),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _textMuted, size: 20),
            tooltip: 'Cancelar convite',
            splashRadius: 20,
            onPressed: () => _removerMembro(membro.id, membro.nome),
          ),
        ],
      );
    }

    if (membro.tagFuncao == 'Proprietário') {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'editar') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ModificarContaProfissionalPage(),
              ),
            ).then((_) {
              _carregarDadosEmpresa();
            });
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'editar',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: _textMuted),
                SizedBox(width: 8),
                Text('Editar Perfil'),
              ],
            ),
          ),
        ],
      );
    }

    return IconButton(
      icon: const Icon(
        Icons.delete_outline_rounded,
        color: _textMuted,
        size: 22,
      ),
      tooltip: 'Remover funcionário',
      splashRadius: 20,
      onPressed: () => _removerMembro(membro.id, membro.nome),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  _DashedCirclePainter({
    this.color = const Color(0xFF94A3B8),
    this.strokeWidth = 1.5,
    this.dashLength = 4,
    this.dashGap = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final circumference = 2 * math.pi * radius;
    final totalDashLength = dashLength + dashGap;
    final count = (circumference / totalDashLength).floor();
    final angleStep = (2 * math.pi) / count;
    final dashAngle = (dashLength / circumference) * (2 * math.pi);

    for (int i = 0; i < count; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(radius, radius),
          radius: radius - strokeWidth / 2,
        ),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
