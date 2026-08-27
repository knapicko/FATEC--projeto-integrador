import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modificar_conta_profissional.dart';
import 'utils/cor_oficio.dart';
import 'widgets/tag_oficio.dart';

class GestaoEquipePage extends StatefulWidget {
  const GestaoEquipePage({super.key});

  @override
  State<GestaoEquipePage> createState() => _GestaoEquipePageState();
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

  static const List<Color> _coresPreset = [
    Color(0xFF0FB3FF), // Azul ConsertaJá
    Color(0xFF1E293B), // Slate Escuro
    Color(0xFF2563EB), // Azul Royal
    Color(0xFF10B981), // Verde Esmeralda
    Color(0xFFF59E0B), // Âmbar
    Color(0xFFEF4444), // Vermelho
    Color(0xFF8B5CF6), // Roxo
    Color(0xFF6D4C41), // Marrom
  ];

  final TextEditingController _emailController = TextEditingController();
  String _nomeEmpresa = 'ConsertaJá Serviços Ltda.';
  String _tagEmpresa = 'LOJA';
  Color _corTagEmpresa = const Color(0xFF0FB3FF);
  String? _fotoUrlEmpresa;
  String? _bannerUrlEmpresa;
  String? _fotoPerfilProprietario;
  String? _nomeProprietario;
  List<OficioInfo> _oficiosEquipe = [];

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
          final grupo = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa',
              )
              .eq('id_grupo_empresa', _idGrupoEmpresa!)
              .maybeSingle();

          if (grupo != null) {
            final nomeGrupo = grupo['nome_empresa']?.toString().trim();
            final tagGrupo = grupo['tag_empresa']?.toString().trim();
            final corGrupo = grupo['cor_tag_empresa']?.toString();
            final fotoGrupo = grupo['foto_url_empresa']?.toString();
            final bannerGrupo = grupo['banner_url_empresa']?.toString();

            if (mounted) {
              setState(() {
                if (nomeGrupo != null && nomeGrupo.isNotEmpty)
                  _nomeEmpresa = nomeGrupo;
                if (tagGrupo != null && tagGrupo.isNotEmpty)
                  _tagEmpresa = tagGrupo.toUpperCase();
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
          final grupo = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa',
              )
              .eq('fk_perfil', _idPerfil!)
              .maybeSingle();

          if (grupo != null) {
            _idGrupoEmpresa = (grupo['id_grupo_empresa'] as num?)?.toInt();
            final nomeGrupo = grupo['nome_empresa']?.toString().trim();
            final tagGrupo = grupo['tag_empresa']?.toString().trim();
            final corGrupo = grupo['cor_tag_empresa']?.toString();
            final fotoGrupo = grupo['foto_url_empresa']?.toString();
            final bannerGrupo = grupo['banner_url_empresa']?.toString();

            if (_idGrupoEmpresa != null && _idProfissional != null) {
              await supabase
                  .from('dados_profissionais')
                  .update({'fk_grupo_empresa': _idGrupoEmpresa})
                  .eq('id_profissional', _idProfissional!);
            }

            if (mounted) {
              setState(() {
                if (nomeGrupo != null && nomeGrupo.isNotEmpty)
                  _nomeEmpresa = nomeGrupo;
                if (tagGrupo != null && tagGrupo.isNotEmpty)
                  _tagEmpresa = tagGrupo.toUpperCase();
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

      // 4. Carregar Ofícios herdados dos profissionais membros da equipe (sem repetições)
      List<OficioInfo> oficiosEquipe = [];
      final Set<int> idsProfissionais = {};
      if (_idProfissional != null) {
        idsProfissionais.add(_idProfissional!);
      }
      for (final m in lista) {
        if (!m.isPendente && m.idProfissional != null) {
          idsProfissionais.add(m.idProfissional!);
        }
      }

      if (idsProfissionais.isNotEmpty) {
        try {
          final assOficios = await supabase
              .from('ass_oficio_profissional')
              .select('fk_oficio')
              .inFilter('fk_profissional', idsProfissionais.toList());

          final idsOficios = assOficios
              .map((e) => e['fk_oficio'])
              .whereType<num>()
              .map((e) => e.toInt())
              .toSet()
              .toList();

          if (idsOficios.isNotEmpty) {
            final oficiosData = await supabase
                .from('oficios')
                .select('funcao, cor')
                .inFilter('id_oficio', idsOficios);

            final Set<String> funcoesVistas = {};
            for (final row in oficiosData) {
              final info = OficioInfo.fromMap(row);
              final chave = info.funcao.trim().toLowerCase();
              if (info.funcao.trim().isNotEmpty && !funcoesVistas.contains(chave)) {
                funcoesVistas.add(chave);
                oficiosEquipe.add(info);
              }
            }
          }
        } catch (e) {
          debugPrint('Erro ao carregar ofícios da equipe: $e');
        }
      }

      if (mounted) {
        setState(() {
          _membros = lista;
          _oficiosEquipe = oficiosEquipe;
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
                              _nomeEmpresa,
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
                OutlinedButton.icon(
                  onPressed: _carregandoEmpresa
                      ? null
                      : _abrirBottomSheetEditarNomeEmpresa,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryBlue,
                    side: const BorderSide(color: _primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
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

  Future<void> _abrirBottomSheetEditarNomeEmpresa() async {
    final nomeController = TextEditingController(text: _nomeEmpresa);
    final tagController = TextEditingController(text: _tagEmpresa);
    Color corSelecionada = _corTagEmpresa;
    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final corTextoTag = _corContraste(corSelecionada);
            final tagPreview = tagController.text.trim().isEmpty
                ? 'TAG'
                : tagController.text.trim().toUpperCase();
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle de arraste
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Cabeçalho da ActionSheet
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: _primaryBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Perfil da Empresa',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _titleDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Altere o nome, a tag e a cor identificadora',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _textMuted,
                              ),
                              splashRadius: 20,
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _cardBorder),

                      // Conteúdo rolável com o formulário
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'NOME DA EMPRESA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: nomeController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: Assistência Express',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: _cardBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: _cardBorder,
                                      ),
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
                                const SizedBox(height: 16),
                                const Text(
                                  'TAG DA EMPRESA (MÁX. 5 LETRAS)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 14,
                                          right: 4,
                                        ),
                                        child: Text(
                                          '#',
                                          style: TextStyle(
                                            color: _textMuted,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: tagController,
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
                                            letterSpacing: 1,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'LOJA',
                                            border: InputBorder.none,
                                            counterText: '',
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                          ),
                                          onChanged: (v) {
                                            final upper = v.toUpperCase();
                                            if (upper != v) {
                                              tagController.value = tagController
                                                  .value
                                                  .copyWith(
                                                    text: upper,
                                                    selection:
                                                        TextSelection.collapsed(
                                                          offset: upper.length,
                                                        ),
                                                  );
                                            }
                                            setSheetState(() {});
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Informe a tag da empresa.';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'COR DA TAG',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ..._coresPreset.map((cor) {
                                        final selecionada =
                                            corSelecionada.toARGB32() ==
                                            cor.toARGB32();
                                        return GestureDetector(
                                          onTap: () {
                                            setSheetState(() {
                                              corSelecionada = cor;
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: cor,
                                              shape: BoxShape.circle,
                                              border: selecionada
                                                  ? Border.all(
                                                      color: _titleDark,
                                                      width: 2.5,
                                                    )
                                                  : Border.all(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                            ),
                                            child: selecionada
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }),
                                      GestureDetector(
                                        onTap: () async {
                                          final cor = await showDialog<Color>(
                                            context: context,
                                            builder: (context) =>
                                                _ColorPickerDialog(
                                                  corInicial: corSelecionada,
                                                ),
                                          );
                                          if (cor != null) {
                                            setSheetState(() {
                                              corSelecionada = cor;
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
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
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
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Prévia:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: corSelecionada,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '#$tagPreview',
                                          style: TextStyle(
                                            color: corTextoTag,
                                            fontSize: 12,
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
                          ),
                        ),
                      ),

                      // Botões de Ação na base
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: salvando
                                    ? null
                                    : () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textMuted,
                                  side: const BorderSide(color: _cardBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: salvando
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        final novoNome = nomeController.text
                                            .trim();
                                        final novaTag = tagController.text
                                            .trim()
                                            .toUpperCase();
                                        setSheetState(() => salvando = true);

                                        final scaffold = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final sucesso =
                                            await _salvarDadosEmpresaNoBanco(
                                              novoNome,
                                              novaTag,
                                              corSelecionada,
                                            );
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                        if (sucesso && mounted) {
                                          scaffold.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Perfil da empresa atualizado com sucesso!',
                                              ),
                                              backgroundColor: Color(
                                                0xFF10B981,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: salvando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Salvar Alterações',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
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
          },
        );
      },
    );
  }

  Future<bool> _salvarDadosEmpresaNoBanco(
    String novoNome,
    String novaTag,
    Color novaCor,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      // Garante _idUsuario e _idProfissional
      if (_idUsuario == null) {
        final usuario = await supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', user.id)
            .maybeSingle();
        _idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      }

      if (_idUsuario == null) return false;

      if (_idProfissional == null || _idPerfil == null) {
        final dadosProf = await supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_perfil, fk_grupo_empresa')
            .eq('fk_usuario', _idUsuario!)
            .maybeSingle();

        _idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
        _idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
        _idGrupoEmpresa ??= (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();
      }

      // Se fk_perfil ainda não existe, cria um registro na tabela perfil
      if (_idPerfil == null && _idProfissional != null) {
        try {
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
        } catch (e) {
          debugPrint('Erro ao criar perfil para grupo_empresa: $e');
        }
      }

      if (_idPerfil == null) return false;

      final hexCor = _corParaHex(novaCor);

      // 1. Se já temos _idGrupoEmpresa, atualiza diretamente
      if (_idGrupoEmpresa != null) {
        await supabase
            .from('grupo_empresa')
            .update({
              'nome_empresa': novoNome,
              'tag_empresa': novaTag,
              'cor_tag_empresa': hexCor,
            })
            .eq('id_grupo_empresa', _idGrupoEmpresa!);
      } else {
        // 2. Verifica se já existe registro em grupo_empresa para o fk_perfil
        final existente = await supabase
            .from('grupo_empresa')
            .select('id_grupo_empresa')
            .eq('fk_perfil', _idPerfil!)
            .maybeSingle();

        if (existente != null) {
          _idGrupoEmpresa = (existente['id_grupo_empresa'] as num?)?.toInt();
          await supabase
              .from('grupo_empresa')
              .update({
                'nome_empresa': novoNome,
                'tag_empresa': novaTag,
                'cor_tag_empresa': hexCor,
              })
              .eq('id_grupo_empresa', _idGrupoEmpresa!);

          if (_idProfissional != null && _idGrupoEmpresa != null) {
            await supabase
                .from('dados_profissionais')
                .update({'fk_grupo_empresa': _idGrupoEmpresa})
                .eq('id_profissional', _idProfissional!);
          }
        } else {
          // 3. Cria novo registro em grupo_empresa
          final novoGrupo = await supabase
              .from('grupo_empresa')
              .insert({
                'fk_perfil': _idPerfil!,
                'nome_empresa': novoNome,
                'tag_empresa': novaTag,
                'cor_tag_empresa': hexCor,
              })
              .select('id_grupo_empresa')
              .single();

          _idGrupoEmpresa = (novoGrupo['id_grupo_empresa'] as num?)?.toInt();

          if (_idProfissional != null && _idGrupoEmpresa != null) {
            await supabase
                .from('dados_profissionais')
                .update({'fk_grupo_empresa': _idGrupoEmpresa})
                .eq('id_profissional', _idProfissional!);
          }
        }
      }

      if (mounted) {
        setState(() {
          _nomeEmpresa = novoNome;
          _tagEmpresa = novaTag;
          _corTagEmpresa = novaCor;
        });
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao salvar dados da empresa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar perfil da empresa: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _convidarFuncionario() async {
    final input = _emailController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o e-mail ou CPF do profissional.'),
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
        // 2. Busca por CPF
        final cpfDigits = input.replaceAll(RegExp(r'\D'), '');
        if (cpfDigits.length != 11) {
          if (mounted) {
            setState(() => _carregandoEmpresa = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'CPF inválido. Digite os 11 dígitos ou um e-mail válido.',
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
                idProfissionalAlvo = (dp?['id_profissional'] as num?)?.toInt();
              }
            }
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModificarContaProfissionalPage(),
                ),
              );
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
                      decoration: const InputDecoration(
                        hintText: 'E-mail ou CPF do profissional',
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
            const SizedBox(height: 30),
          ],
        ),
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
