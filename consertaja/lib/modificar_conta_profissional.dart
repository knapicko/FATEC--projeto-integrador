import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/salvamento_automatico.dart';
import 'widgets/skeleton_loading.dart';
import 'services/cor_dominante_service.dart';
import 'utils/iniciais.dart';
import 'widgets/aviso_obrigatorio.dart';
import 'services/requisitos_conta.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/ilustracoes.dart';

class ModificarContaProfissionalPage extends StatefulWidget {
  const ModificarContaProfissionalPage({
    super.key,
    this.tutorialTipoConta = false,
  });

  /// Aberta pelo tutorial da home: mostra o "Tipo de conta" e volta
  /// devolvendo o [ResultadoTutorial].
  final bool tutorialTipoConta;

  @override
  State<ModificarContaProfissionalPage> createState() =>
      _ModificarContaProfissionalPageState();
}

enum _TipoConta { independente, loja }

class _ModificarContaProfissionalPageState
    extends State<ModificarContaProfissionalPage> {
  static const Color _blue = Color(0xFF0A6E9D);
  static const Color _bg = Color(0xFFF6F6F7);
  static const Color _textDark = Color(0xFF3E4350);
  static const Color _muted = Color(0xFFA2A8B3);

  // Tutorial do tipo de conta (destaques).
  final _kTituloTipo = GlobalKey();
  final _kCardLoja = GlobalKey();
  bool _tutorialIniciado = false;

  Rect? _rectDe(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _rodarTutorialTipoConta() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Rect? secao() {
      final a = _rectDe(_kTituloTipo);
      final b = _rectDe(_kCardLoja);
      if (a == null) return b;
      return b == null ? a : a.expandToInclude(b);
    }

    final r = await Tutorial.mostrar(
      context,
      pularParaFinal: true,
      chave: 'modificar_conta_tipo',
      forcar: true,
      comEntrada: false,
      passos: [
        PassoTutorial(
          'Aqui fica o tipo da sua conta: independente ou loja/empresa.',
          alvo: _kTituloTipo,
          alvoRect: secao,
          alinhamentoRolagem: 0.25,
        ),
        PassoTutorial(
          'Para ativar a conta de empresa, é só marcar "Loja / Empresa".',
          alvo: _kCardLoja,
        ),
        const PassoTutorial(
          'Assim você ganha a conta da loja, com equipe e página própria, '
          'sem perder a sua conta independente.',
          ilustracao: IlustracaoEquipe(),
        ),
        const PassoTutorial('Agora vamos voltar para a home!'),
        passoFinalTutorial(apenasAoPular: true),
      ],
    );
    if (mounted) Navigator.of(context).pop(r);
  }

  static const List<String> _opcoesExperiencia = [
    '0-1 ano',
    '2-5 anos',
    '6-10 anos',
    '11-15 anos',
    'Mais de 15 anos',
  ];

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descricaoController = TextEditingController();

  Timer? _descricaoTimer;
  bool _carregando = true;

  /// Tudo salva sozinho a cada mudança (sem botão "Salvar Alterações").
  late final SalvamentoAutomatico _autosave = SalvamentoAutomatico(
    _salvarAlteracoes,
  );
  bool _enviandoFoto = false;

  String? _fotoPerfilUrl;
  Color _corBanner = CorDominanteService.corPadraoColor;
  String _nomeCompleto = 'Nome não encontrado';
  String? _anosExperienciaSelecionado;
  _TipoConta _tipoConta = _TipoConta.independente;
  bool _isPessoaJuridica = false;

  int? _idUsuario;
  int? _idProfissional;
  int? _idPerfil;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _descricaoTimer?.cancel();
    _autosave.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url, fk_tipo_pessoa')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (usuario == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      _idUsuario = (usuario['id_usuario'] as num?)?.toInt();
      _nomeCompleto = (usuario['nome']?.toString().trim().isNotEmpty ?? false)
          ? usuario['nome'].toString().trim()
          : 'Nome não encontrado';
      _fotoPerfilUrl = usuario['foto_perfil_url']?.toString();

      // Verifica se o profissional é pessoa jurídica (possui CNPJ)
      final tipoPessoaId = usuario['fk_tipo_pessoa'];
      if (tipoPessoaId != null) {
        final assTipoPessoa = await _supabase
            .from('ass_tipo_pessoa')
            .select('fk_pessoa_fisica, fk_pessoa_juridica')
            .eq('id_tipo_pessoa', tipoPessoaId)
            .maybeSingle();

        _isPessoaJuridica = assTipoPessoa?['fk_pessoa_juridica'] != null;
      }

      if (_idUsuario != null) {
        final dadosProf = await RequisitosConta.dadosProfissionalLogado(
          'id_profissional, fk_perfil, anos_experiencia',
        );

        _idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
        _idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();

        final anosRaw = dadosProf?['anos_experiencia']?.toString().trim();
        if (anosRaw != null && _opcoesExperiencia.contains(anosRaw)) {
          _anosExperienciaSelecionado = anosRaw;
        }

        if (_idPerfil != null) {
          final perfil = await _supabase
              .from('perfil')
              .select('descricao_perfil, tipo_perfil, cor_banner')
              .eq('id_perfil', _idPerfil!)
              .maybeSingle();

          _descricaoController.text =
              perfil?['descricao_perfil']?.toString().trim() ?? '';
          _corBanner = CorDominanteService.paraColor(
            perfil?['cor_banner']?.toString(),
          );

          final tipoPerfilRaw = perfil?['tipo_perfil']?.toString();
          if (tipoPerfilRaw == 'Loja') {
            _tipoConta = _TipoConta.loja;
          } else if (tipoPerfilRaw == 'Independente') {
            _tipoConta = _TipoConta.independente;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados de modificar conta: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<int?> _obterOuCriarPerfil() async {
    if (_idPerfil != null) return _idPerfil;

    if (_idProfissional == null || _idUsuario == null) return null;

    try {
      await _supabase.from('perfil').upsert({
        'id_perfil': _idProfissional,
        'descricao_perfil': null,
        'cor_banner': CorDominanteService.corPadrao,
      });

      await _supabase
          .from('dados_profissionais')
          .update({'fk_perfil': _idProfissional})
          .eq('id_profissional', _idProfissional!);

      _idPerfil = _idProfissional;
      return _idPerfil;
    } catch (e) {
      debugPrint('Erro ao criar perfil fallback: $e');
      return null;
    }
  }

  void _agendarSalvamentoDescricao(String value) {
    _autosave.agendar();
    setState(() {});
  }

  Future<void> _escolherFotoPerfil() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _enviandoFoto = true);

      // Lê os bytes UMA vez e extrai a cor dominante deles.
      // Se a extração falhar por qualquer motivo, usa o default
      // 0xFF0FB3FF (profissional sem foto válida).
      Uint8List bytes;
      try {
        bytes = await pickedFile.readAsBytes();
      } catch (_) {
        bytes = Uint8List(0);
      }
      final corBanner = CorDominanteService.extrair(bytes);

      // Nome/bucket SEM espaço: bucket "Foto Perfil" quebra URL pública
      // (vira %20) e pode falhar por RLS/policy dependendo do projeto.
      // Usa "foto-perfil" e cai para "Foto Perfil" (legado) se preciso.
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const bucketNovo = 'foto-perfil';
      const bucketLegado = 'Foto Perfil';

      String bucketUsado = bucketNovo;
      String? publicUrl;
      Object? ultimoErro;

      for (final bucketName in [bucketNovo, bucketLegado]) {
        try {
          if (kIsWeb) {
            await _supabase.storage
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
            await _supabase.storage
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

          publicUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);
          bucketUsado = bucketName;
          ultimoErro = null;
          break;
        } catch (e) {
          ultimoErro = e;
          debugPrint('Upload falhou no bucket \"$bucketName\": $e');
        }
      }

      if (publicUrl == null) {
        throw Exception(
          'Falha no upload da foto (buckets \"$bucketNovo\" / \"$bucketLegado\"). '
          'Verifique se o bucket existe e está público. Detalhe: $ultimoErro',
        );
      }
      debugPrint('Foto enviada para o bucket \"$bucketUsado\".');

      await _supabase
          .from('usuarios')
          .update({'foto_perfil_url': publicUrl})
          .eq('auth_id', user.id);

      final idPerfil = await _obterOuCriarPerfil();
      if (idPerfil != null) {
        // Salva a cor dominante da NOVA foto toda vez que ela mudar.
        await CorDominanteService.atualizarCorBanner(
          supabase: _supabase,
          idPerfil: idPerfil,
          fotoBytes: bytes,
        );
      }

      if (mounted) {
        setState(() {
          _fotoPerfilUrl = publicUrl;
          _corBanner = CorDominanteService.paraColor(corBanner);
          _enviandoFoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoFoto = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar foto: $e')));
      }
    }
  }

  /// Grava descrição, tipo de conta e anos de experiência.
  Future<void> _salvarAlteracoes() async {
    final idPerfil = await _obterOuCriarPerfil();
    if (idPerfil == null) {
      throw Exception('perfil profissional não encontrado.');
    }

    final textoLimpo = _descricaoController.text.trim();
    final descricaoFinal = textoLimpo.isEmpty
        ? null
        : (textoLimpo.length > 500 ? textoLimpo.substring(0, 500) : textoLimpo);

    await _supabase
        .from('perfil')
        .update({
          'descricao_perfil': descricaoFinal,
          // Tipo de perfil (apenas para pessoa jurídica).
          if (_isPessoaJuridica)
            'tipo_perfil': _tipoConta == _TipoConta.loja
                ? 'Loja'
                : 'Independente',
        })
        .eq('id_perfil', idPerfil);

    if (_anosExperienciaSelecionado != null && _idProfissional != null) {
      await _supabase
          .from('dados_profissionais')
          .update({'anos_experiencia': _anosExperienciaSelecionado})
          .eq('id_profissional', _idProfissional!);
    }
  }

  String get _contadorDescricao =>
      '${_descricaoController.text.characters.length}/500';

  @override
  Widget build(BuildContext context) {
    if (!_carregando && widget.tutorialTipoConta && !_tutorialIniciado) {
      _tutorialIniciado = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _rodarTutorialTipoConta(),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _carregando
            ? const SkeletonPage(layout: SkeletonLayout.form)
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildBannerAndProfile(),
                    if (_descricaoController.text.trim().isEmpty ||
                        (_anosExperienciaSelecionado ?? '').trim().isEmpty)
                      const AvisoObrigatorio(
                        titulo: 'Complete sua conta',
                        texto:
                            'Preencha a descrição e os anos de experiência. '
                            'Eles aparecem no seu perfil para os clientes.',
                      ),
                    const SizedBox(height: 18),
                    _buildForm(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0FB3FF)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            child: Center(
              child: const Text(
                'Modificar Conta',
                style: TextStyle(
                  color: Color(0xFF0FB3FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAndProfile() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: 128,
              child: ColoredBox(color: _corBanner),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -52,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFFE9EEF5),
                        backgroundImage:
                            (_fotoPerfilUrl != null &&
                                _fotoPerfilUrl!.isNotEmpty)
                            ? NetworkImage(_fotoPerfilUrl!)
                            : null,
                        child:
                            (_fotoPerfilUrl == null || _fotoPerfilUrl!.isEmpty)
                            ? Text(
                                obterIniciais(_nomeCompleto),
                                style: const TextStyle(
                                  color: _blue,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: 4,
                      child: GestureDetector(
                        onTap: _enviandoFoto ? null : _escolherFotoPerfil,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _enviandoFoto
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 62),
      ],
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESCRIÇÃO / SOBRE MIM',
            style: TextStyle(
              color: _textDark,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descricaoController,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            onChanged: _agendarSalvamentoDescricao,
            style: const TextStyle(fontSize: 16, color: Color(0xFF5A6170)),
            decoration: InputDecoration(
              counterText: '',
              hintText:
                  'Conte um pouco sobre sua experiência e os serviços que oferece...',
              hintStyle: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8E95A3),
                height: 1.35,
              ),
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1E5EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1E5EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _blue, width: 1.4),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _contadorDescricao,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'ANOS DE EXPERIÊNCIA',
            style: TextStyle(
              color: _textDark,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _anosExperienciaSelecionado,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            hint: const Text('Selecione seu tempo de atuação'),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1E5EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1E5EB)),
              ),
            ),
            items: _opcoesExperiencia
                .map(
                  (opcao) => DropdownMenuItem<String>(
                    value: opcao,
                    child: Text(opcao),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _anosExperienciaSelecionado = value);
              _autosave.agendar();
            },
          ),
          if (_isPessoaJuridica) ...[
            const SizedBox(height: 16),
            Text(
              key: _kTituloTipo,
              'TIPO DE CONTA',
              style: TextStyle(
                color: _textDark,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            _buildTipoContaCard(
              tipo: _TipoConta.independente,
              titulo: 'Profissional Independente',
              subtitulo: 'Atuo por conta própria.',
              icon: Icons.person,
              selecionado: _tipoConta == _TipoConta.independente,
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _kCardLoja,
              child: _buildTipoContaCard(
                tipo: _TipoConta.loja,
                titulo: 'Loja / Empresa',
                subtitulo: 'Possuo CNPJ e equipe.',
                icon: Icons.storefront_outlined,
                selecionado: _tipoConta == _TipoConta.loja,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(child: IndicadorSalvamento(controle: _autosave)),
        ],
      ),
    );
  }

  Widget _buildTipoContaCard({
    required _TipoConta tipo,
    required String titulo,
    required String subtitulo,
    required IconData icon,
    required bool selecionado,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _tipoConta = tipo);
        _autosave.agendar();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFDDF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selecionado
                ? const Color(0xFFCDE8FF)
                : const Color(0xFFE2E6EC),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selecionado
                    ? const Color(0xFF1FA9EB)
                    : const Color(0xFFE8EAEE),
              ),
              child: Icon(
                icon,
                color: selecionado ? Colors.white : const Color(0xFF6E7481),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: selecionado ? _blue : const Color(0xFF3D4452),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5D6472),
                    ),
                  ),
                ],
              ),
            ),
            Radio<_TipoConta>(
              value: tipo,
              groupValue: _tipoConta,
              activeColor: const Color(0xFF1FA9EB),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _tipoConta = value);
                _autosave.agendar();
              },
            ),
          ],
        ),
      ),
    );
  }
}
