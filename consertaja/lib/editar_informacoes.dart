import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'services/cor_dominante_service.dart';
import 'services/validacao_telefone.dart';
import 'widgets/skeleton_loading.dart';
import 'services/formatacao_data.dart';
import 'utils/iniciais.dart';
import 'widgets/seletor_ddi.dart';
import 'widgets/dialogo_sheet.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';

class EditarInformacoesPage extends StatefulWidget {
  const EditarInformacoesPage({super.key});

  @override
  State<EditarInformacoesPage> createState() => _EditarInformacoesPageState();
}

class _EditarInformacoesPageState extends State<EditarInformacoesPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _fundo = Color(0xFFF3F5F8);
  static const Color _texto = Color(0xFF111827);
  static const Color _verde = Color(0xFF16A34A);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  String _nomeCompleto = 'Nome não encontrado';

  /// CPF (pessoa física) ou CNPJ (pessoa jurídica), já formatado.
  String _documento = '';
  String _rotuloDocumento = 'CPF';
  String _email = '';
  String _telefone = '';
  String _dataNascimento = '';
  String? _fotoPerfilUrl;
  String _tipoConta = 'Cliente';

  // IDs para atualização
  int? _telefoneId;
  String? _telefoneDDD;
  String? _telefoneNumero;
  String _ddiSelecionado = '+55';
  int? _usuarioId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  /// Aceita "AAAA-MM-DD", "AAAA-MM-DDTHH:MM:SS" (timestamp) e "DD/MM/AAAA".
  String _dataParaExibir(Object? bruto) {
    final texto = bruto?.toString().trim() ?? '';
    if (texto.isEmpty || texto == 'null') return '';
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(texto)) return texto;
    final data = DateTime.tryParse(texto);
    if (data == null) return formatarDataBrasileira(texto);
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _carregarDados() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final usuarioResponse = await _supabase
          .from('usuarios')
          .select(
            'id_usuario, nome, data_nascimento, foto_perfil_url, fk_email, '
            'fk_telefone, fk_tipo_pessoa, tipo_conta',
          )
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      _usuarioId = (usuarioResponse?['id_usuario'] as num?)?.toInt();
      final nome =
          usuarioResponse?['nome']?.toString() ?? 'Nome não encontrado';
      final dataNascimento = _dataParaExibir(
        usuarioResponse?['data_nascimento'],
      );
      final fotoUrl = usuarioResponse?['foto_perfil_url']?.toString();

      // E-mail
      String email = user.email ?? '';
      final emailId = usuarioResponse?['fk_email'];
      if (emailId != null) {
        try {
          final emailResponse = await _supabase
              .from('emails')
              .select('endereco_email')
              .eq('id_email', emailId)
              .maybeSingle();
          final e = emailResponse?['endereco_email']?.toString().trim() ?? '';
          if (e.isNotEmpty) email = e;
        } catch (_) {}
      }

      // Telefone
      String telefone = '';
      final telefoneId = (usuarioResponse?['fk_telefone'] as num?)?.toInt();
      if (telefoneId != null) {
        _telefoneId = telefoneId;
        try {
          final telefoneResponse = await _supabase
              .from('telefones')
              .select('ddd, numero')
              .eq('id_telefone', telefoneId)
              .maybeSingle();
          if (telefoneResponse != null) {
            final ddd = telefoneResponse['ddd']?.toString() ?? '';
            final numero = telefoneResponse['numero']?.toString() ?? '';
            _telefoneDDD = ddd;
            _telefoneNumero = numero;
            if (ddd.isNotEmpty && numero.isNotEmpty) {
              telefone = _formatarTelefone(ddd, numero);
            }
          }
        } catch (_) {}
      }

      // CPF (pessoa física) ou CNPJ (pessoa jurídica)
      String documento = '';
      String rotulo = 'CPF';
      final tipoPessoaId = usuarioResponse?['fk_tipo_pessoa'];
      if (tipoPessoaId != null) {
        try {
          final ass = await _supabase
              .from('ass_tipo_pessoa')
              .select('fk_pessoa_fisica, fk_pessoa_juridica')
              .eq('id_tipo_pessoa', tipoPessoaId)
              .maybeSingle();
          final pfId = ass?['fk_pessoa_fisica'];
          final pjId = ass?['fk_pessoa_juridica'];
          if (pfId != null) {
            final pf = await _supabase
                .from('pessoa_fisica')
                .select('cpf')
                .eq('id_pessoa_fisica', pfId)
                .maybeSingle();
            final d = pf?['cpf']?.toString().replaceAll(RegExp(r'\D'), '');
            if (d != null && d.length == 11) {
              documento =
                  '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
            } else {
              documento = d ?? '';
            }
          } else if (pjId != null) {
            rotulo = 'CNPJ';
            final pj = await _supabase
                .from('pessoa_juridica')
                .select('cnpj')
                .eq('id_pessoa_juridica', pjId)
                .maybeSingle();
            final d = pj?['cnpj']?.toString().replaceAll(RegExp(r'\D'), '');
            if (d != null && d.length == 14) {
              documento =
                  '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
            } else {
              documento = d ?? '';
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _nomeCompleto = nome;
          _documento = documento;
          _rotuloDocumento = rotulo;
          _email = email;
          _telefone = telefone;
          _dataNascimento = dataNascimento;
          _fotoPerfilUrl = fotoUrl;
          _tipoConta = usuarioResponse?['tipo_conta']?.toString() ?? 'Cliente';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[editar_informacoes] $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatarTelefone(String ddd, String numero) {
    if (ddd.isEmpty && numero.isEmpty) return '';
    if (numero.length == 8) {
      return '($ddd) ${numero.substring(0, 4)}-${numero.substring(4)}';
    } else if (numero.length == 9) {
      return '($ddd) ${numero.substring(0, 5)}-${numero.substring(5)}';
    }
    return '($ddd) $numero';
  }

  void _aviso(String texto, {Color? cor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================= ALTERAR FOTO =================
  Future<void> _alterarFoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Alterar Foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: _blue),
                title: const Text('Tirar Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _escolherImagem(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: _blue),
                title: const Text('Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _escolherImagem(ImageSource.gallery);
                },
              ),
              if (_fotoPerfilUrl != null && _fotoPerfilUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remover Foto',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removerFoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _escolherImagem(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      // Lê os bytes uma única vez: usa no upload (web) e para extrair
      // a cor dominante (toda troca de foto recalcula o banner).
      Uint8List bytes;
      try {
        bytes = await pickedFile.readAsBytes();
      } catch (_) {
        bytes = Uint8List(0);
      }
      if (bytes.isEmpty) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível ler a imagem.')),
          );
        }
        return;
      }

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const bucketNovo = 'foto-perfil';
      const bucketLegado = 'Foto Perfil';

      String? publicUrl;
      Object? ultimoErro;

      // Fazer upload para o Supabase Storage (compatível Web e Mobile).
      // Tenta o bucket novo (sem espaço) e cai para o legado.
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
          ultimoErro = null;
          break;
        } catch (bucketError) {
          ultimoErro = bucketError;
          debugPrint('Upload falhou no bucket "$bucketName": $bucketError');
        }
      }

      if (publicUrl == null) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro ao fazer upload da foto ($ultimoErro). '
                'Verifique o bucket "foto-perfil".',
              ),
            ),
          );
        }
        return;
      }

      // Atualizar no banco
      await _supabase
          .from('usuarios')
          .update({'foto_perfil_url': publicUrl})
          .eq('auth_id', user.id);

      // Profissional: toda troca de foto recalcula o cor_banner.
      await _atualizarCorBannerDoProfissional(bytes);

      if (mounted) {
        setState(() {
          _fotoPerfilUrl = publicUrl;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto alterada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao alterar foto: $e')));
      }
    }
  }

  /// Se o usuário logado for profissional, recalcula o `cor_banner`
  /// a partir dos [bytes] da nova foto. Sem perfil: não faz nada.
  Future<void> _atualizarCorBannerDoProfissional(Uint8List bytes) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return;
      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('fk_perfil')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();
      final idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
      if (idPerfil == null) return;
      await CorDominanteService.atualizarCorBanner(
        supabase: _supabase,
        idPerfil: idPerfil,
        fotoBytes: bytes,
      );
    } catch (e) {
      debugPrint('Falha ao atualizar cor_banner: $e');
    }
  }

  Future<void> _removerFoto() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('usuarios')
          .update({'foto_perfil_url': null})
          .eq('auth_id', user.id);

      // Sem foto -> volta para o default 0xFF0FB3FF.
      try {
        final usuario = await _supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', user.id)
            .maybeSingle();
        final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
        if (idUsuario != null) {
          final dadosProf = await _supabase
              .from('dados_profissionais')
              .select('fk_perfil')
              .eq('fk_usuario', idUsuario)
              .maybeSingle();
          final idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
          if (idPerfil != null) {
            await _supabase
                .from('perfil')
                .update({'cor_banner': CorDominanteService.corPadrao})
                .eq('id_perfil', idPerfil);
          }
        }
      } catch (e) {
        debugPrint('Falha ao resetar cor_banner: $e');
      }

      if (mounted) {
        setState(() => _fotoPerfilUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto removida com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao remover foto: $e')));
      }
    }
  }

  // ================= POPUP DE EDIÇÃO =================
  Future<void> _mostrarPopupEdicao(
    String campo,
    String valorAtual,
    Function(String) onSalvar,
  ) async {
    final controller = TextEditingController(text: valorAtual);
    final formKey = GlobalKey<FormState>();

    final resultado = await mostrarDialogoComoSheet<String>(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: duracao(const Duration(milliseconds: 250)),
          curve: Curves.easeInOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Editar $campo',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller,
                      keyboardType: campo == 'Celular'
                          ? TextInputType.phone
                          : campo == 'Email'
                          ? TextInputType.emailAddress
                          : null,
                      inputFormatters: campo == 'Celular'
                          ? [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d+\-() ]'),
                              ),
                            ]
                          : null,
                      decoration: InputDecoration(
                        labelText: campo,
                        labelStyle: const TextStyle(color: _blue),
                        prefixIcon: campo == 'Celular'
                            ? Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: SeletorDDI(
                                  ddiInicial: _ddiSelecionado,
                                  corPrimaria: _blue,
                                  onChanged: (ddi) {
                                    setState(() => _ddiSelecionado = ddi);
                                  },
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _blue, width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F9FF),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Este campo não pode ficar vazio';
                        }
                        // Validação específica para telefone
                        if (campo == 'Celular') {
                          final validacao = validarTelefoneCompleto(value);
                          if (!validacao.valido) {
                            return validacao.erro ?? 'Telefone inválido';
                          }
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: CorOriginal(interface: true, child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, controller.text.trim());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: _textGray, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (resultado != null && resultado.isNotEmpty) {
      onSalvar(resultado);
    }
  }

  // ================= SALVAR CAMPOS NO SUPABASE =================
  Future<void> _salvarNome(String novoNome) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase
          .from('usuarios')
          .update({'nome': novoNome})
          .eq('auth_id', user.id);
      if (mounted) {
        setState(() => _nomeCompleto = novoNome);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nome atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar nome: $e')));
      }
    }
  }

  Future<void> _salvarTelefone(String novoTelefone) async {
    try {
      // Valida estrutura do telefone antes de salvar
      final validacaoTelefone = validarTelefoneCompleto(novoTelefone);
      if (!validacaoTelefone.valido) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validacaoTelefone.erro ?? 'Telefone inválido'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Extrair DDD e número do formato (XX) XXXXX-XXXX
      final digits = novoTelefone.replaceAll(RegExp(r'\D'), '');
      String ddd = '';
      String numero = '';

      if (digits.length >= 10) {
        ddd = digits.substring(0, 2);
        numero = digits.substring(2);
      } else {
        ddd = _telefoneDDD ?? '';
        numero = novoTelefone.replaceAll(RegExp(r'\D'), '');
      }

      if (_telefoneId != null) {
        await _supabase
            .from('telefones')
            .update({'ddd': ddd, 'numero': numero})
            .eq('id_telefone', _telefoneId!);
      } else {
        // Inserir novo telefone
        final telefoneResponse = await _supabase
            .from('telefones')
            .insert({'ddd': ddd, 'numero': numero, 'fk_status': 1})
            .select()
            .single();
        _telefoneId = (telefoneResponse['id_telefone'] as num?)?.toInt();

        if (_usuarioId != null) {
          await _supabase
              .from('usuarios')
              .update({'fk_telefone': _telefoneId!})
              .eq('id_usuario', _usuarioId!);
        }
      }

      _telefoneDDD = ddd;
      _telefoneNumero = numero;

      if (mounted) {
        setState(() => _telefone = _formatarTelefone(ddd, numero));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefone atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar telefone: $e')),
        );
      }
    }
  }

  Future<void> _salvarDataNascimento(String novaData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Converter de DD/MM/AAAA para AAAA-MM-DD
      final dataFormatada = converterDataParaIso(novaData);

      await _supabase
          .from('usuarios')
          .update({'data_nascimento': dataFormatada})
          .eq('auth_id', user.id);

      if (mounted) {
        setState(() => _dataNascimento = novaData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data de nascimento atualizada com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar data: $e')));
      }
    }
  }

  Future<void> _mostrarPopupEdicaoSenha() async {
    final novaSenhaController = TextEditingController();
    final confirmarSenhaController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await mostrarDialogoComoSheet<void>(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: duracao(const Duration(milliseconds: 250)),
          curve: Curves.easeInOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Alterar Senha',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: novaSenhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nova Senha',
                        labelStyle: const TextStyle(color: _blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _blue, width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F9FF),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite a nova senha';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter no mínimo 6 caracteres';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmarSenhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Senha',
                        labelStyle: const TextStyle(color: _blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _blue, width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F9FF),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirme a nova senha';
                        }
                        if (value != novaSenhaController.text) {
                          return 'As senhas não coincidem';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: CorOriginal(interface: true, child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              final user = _supabase.auth.currentUser;
                              if (user != null) {
                                await _supabase.auth.updateUser(
                                  UserAttributes(
                                    password: novaSenhaController.text,
                                  ),
                                );
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Senha alterada com sucesso!',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro ao alterar senha: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: _textGray, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= VERIFICAÇÃO POR CÓDIGO =================

  bool get _emailConfirmed =>
      _supabase.auth.currentUser?.emailConfirmedAt != null;

  /// Telefone no formato internacional (+5511999998888).
  String? get _telefoneE164 {
    final ddd = _telefoneDDD ?? '';
    final numero = _telefoneNumero ?? '';
    if (ddd.isEmpty || numero.isEmpty) return null;
    final ddi = _ddiSelecionado.replaceAll(RegExp(r'\D'), '');
    return '+$ddi$ddd$numero';
  }

  bool get _telefoneConfirmado {
    final user = _supabase.auth.currentUser;
    final e164 = _telefoneE164;
    if (user == null || e164 == null || user.phoneConfirmedAt == null) {
      return false;
    }
    final doAuth = (user.phone ?? '').replaceAll(RegExp(r'\D'), '');
    return doAuth.isNotEmpty && doAuth == e164.replaceAll(RegExp(r'\D'), '');
  }

  /// Janela para digitar o código de 6 dígitos. [verificar] lança erro se o
  /// código estiver errado; [reenviar] manda outro código.
  Future<bool> _pedirCodigo({
    required String titulo,
    required String destino,
    required Future<void> Function(String codigo) verificar,
    required Future<void> Function() reenviar,
  }) async {
    final controller = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? erro;
        bool enviando = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> confirmar() async {
              final codigo = controller.text.trim();
              if (codigo.length < 6) {
                setDialogState(() => erro = 'Digite o código de 6 dígitos.');
                return;
              }
              setDialogState(() {
                enviando = true;
                erro = null;
              });
              try {
                await verificar(codigo);
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                setDialogState(() {
                  enviando = false;
                  erro = 'Código inválido ou expirado. Tente de novo.';
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enviamos um código de 6 dígitos para $destino.',
                      style: const TextStyle(color: _textGray, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => confirmar(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        color: _texto,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        filled: true,
                        fillColor: _fundo,
                        errorText: erro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _blue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: CorOriginal(interface: true, child: FilledButton(
                        onPressed: enviando ? null : confirmar,
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: enviando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirmar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      )),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: enviando
                              ? null
                              : () async {
                                  try {
                                    await reenviar();
                                    setDialogState(() => erro = null);
                                    _aviso('Enviamos um novo código.');
                                  } catch (e) {
                                    setDialogState(
                                      () => erro =
                                          'Não foi possível reenviar agora.',
                                    );
                                  }
                                },
                          child: const Text('Reenviar código'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: _textGray),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    return confirmado == true;
  }

  /// Confirma o e-mail atual com um código enviado para ele.
  Future<void> _verificarEmail() async {
    final email = _email.trim();
    if (email.isEmpty) return;
    Future<void> enviar() =>
        _supabase.auth.resend(type: OtpType.signup, email: email);
    try {
      await enviar();
    } catch (e) {
      _aviso('Não foi possível enviar o código: $e', cor: Colors.red);
      return;
    }
    final ok = await _pedirCodigo(
      titulo: 'Verificar e-mail',
      destino: email,
      verificar: (codigo) => _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: codigo,
      ),
      reenviar: enviar,
    );
    if (!ok) return;
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {}
    if (mounted) setState(() {});
    _aviso('E-mail verificado!', cor: _verde);
  }

  /// Troca o e-mail: o novo só vale depois do código enviado para ele.
  Future<void> _trocarEmail(String novoEmail) async {
    final novo = novoEmail.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(novo)) {
      _aviso('Digite um e-mail válido.', cor: Colors.red);
      return;
    }
    if (novo == _email.trim().toLowerCase()) return;
    Future<void> enviar() =>
        _supabase.auth.updateUser(UserAttributes(email: novo));
    try {
      await enviar();
    } catch (e) {
      _aviso('Não foi possível enviar o código: $e', cor: Colors.red);
      return;
    }
    final ok = await _pedirCodigo(
      titulo: 'Confirmar novo e-mail',
      destino: novo,
      verificar: (codigo) => _supabase.auth.verifyOTP(
        type: OtpType.emailChange,
        email: novo,
        token: codigo,
      ),
      reenviar: enviar,
    );
    if (!ok) return;
    try {
      final user = _supabase.auth.currentUser;
      final usuario = user == null
          ? null
          : await _supabase
                .from('usuarios')
                .select('fk_email')
                .eq('auth_id', user.id)
                .maybeSingle();
      final emailId = usuario?['fk_email'];
      if (emailId != null) {
        await _supabase
            .from('emails')
            .update({'endereco_email': novo})
            .eq('id_email', emailId);
      }
      if (mounted) setState(() => _email = novo);
      _aviso('E-mail alterado e verificado!', cor: _verde);
    } catch (e) {
      _aviso('E-mail verificado, mas houve um erro ao salvar: $e');
    }
  }

  /// Confirma o celular com um código por SMS (precisa de um provedor de SMS
  /// configurado no Supabase: Authentication → Providers → Phone).
  Future<void> _verificarTelefone() async {
    final e164 = _telefoneE164;
    if (e164 == null) {
      _aviso('Cadastre um celular primeiro.');
      return;
    }
    Future<void> enviar() =>
        _supabase.auth.updateUser(UserAttributes(phone: e164));
    try {
      await enviar();
    } catch (e) {
      _aviso(
        'Não foi possível enviar o SMS agora. A verificação por celular '
        'precisa de um provedor de SMS ativo no Supabase.',
        cor: Colors.red,
      );
      debugPrint('[verificar telefone] $e');
      return;
    }
    final ok = await _pedirCodigo(
      titulo: 'Verificar celular',
      destino: _telefone,
      verificar: (codigo) => _supabase.auth.verifyOTP(
        type: OtpType.phoneChange,
        phone: e164,
        token: codigo,
      ),
      reenviar: enviar,
    );
    if (!ok) return;
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {}
    if (mounted) setState(() {});
    _aviso('Celular verificado!', cor: _verde);
  }

  Future<void> _escolherDataNascimento() async {
    DateTime inicial = DateTime(2000);
    final partes = _dataNascimento.split('/');
    if (partes.length == 3) {
      inicial =
          DateTime.tryParse(
            '${partes[2]}-${partes[1].padLeft(2, '0')}-${partes[0].padLeft(2, '0')}',
          ) ??
          inicial;
    }
    final agora = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1900),
      lastDate: DateTime(agora.year - 16, agora.month, agora.day),
      helpText: 'Data de nascimento',
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _blue)),
        child: child!,
      ),
    );
    if (escolhida == null) return;
    final br =
        '${escolhida.day.toString().padLeft(2, '0')}/'
        '${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}';
    await _salvarDataNascimento(br);
  }

  // ================= LAYOUT =================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _fundo,
        body: SafeArea(child: SkeletonPage(layout: SkeletonLayout.form)),
      );
    }

    final temFoto = _fotoPerfilUrl != null && _fotoPerfilUrl!.trim().isNotEmpty;
    final ehProfissional = _tipoConta == 'Profissional';

    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: _fundo,
        surfaceTintColor: _fundo,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _texto),
        ),
        title: const Text(
          'Meus dados',
          style: TextStyle(
            color: _texto,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          BotaoAjuda(
            cor: _texto,
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui você edita os seus dados pessoais.',
              conteudo: [
                'Toque em um campo para alterar. E-mail e celular são confirmados por código.',
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Foto + nome + tipo de conta
              Center(
                child: GestureDetector(
                  onTap: _isUploading ? null : _alterarFoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CorOriginal(child: CircleAvatar(
                        radius: 48,
                        backgroundColor: _blue,
                        backgroundImage: temFoto
                            ? NetworkImage(_fotoPerfilUrl!)
                            : null,
                        child: temFoto
                            ? null
                            : Text(
                                obterIniciais(_nomeCompleto),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      )),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: CorOriginal(interface: true, child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: _fundo, width: 3),
                          ),
                          child: Icon(
                            _isUploading
                                ? Icons.hourglass_top_rounded
                                : Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _nomeCompleto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _texto,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: CorOriginal(interface: true, ativo: !(ehProfissional), child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ehProfissional ? const Color(0xFFFFF1DE) : _blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ehProfissional ? 'Conta profissional' : 'Conta cliente',
                    style: TextStyle(
                      color: ehProfissional
                          ? const Color(0xFFB45309)
                          : Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 24),

              _tituloGrupo('Dados pessoais'),
              _grupo([
                _linha(
                  icone: Icons.person_outline_rounded,
                  rotulo: 'Nome',
                  valor: _nomeCompleto,
                  acao: _acao(
                    'Alterar',
                    () =>
                        _mostrarPopupEdicao('Nome', _nomeCompleto, _salvarNome),
                  ),
                ),
                _linha(
                  icone: Icons.badge_outlined,
                  rotulo: _rotuloDocumento,
                  valor: _documento.isNotEmpty ? _documento : 'Não informado',
                ),
                _linha(
                  icone: Icons.cake_outlined,
                  rotulo: 'Data de nascimento',
                  valor: _dataNascimento.isNotEmpty
                      ? _dataNascimento
                      : 'Não informada',
                  acao: _acao(
                    _dataNascimento.isEmpty ? 'Definir' : 'Alterar',
                    _escolherDataNascimento,
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              _tituloGrupo('Contato'),
              _grupo([
                _linha(
                  icone: Icons.email_outlined,
                  rotulo: 'E-mail',
                  valor: _email.isNotEmpty ? _email : 'Não informado',
                  selo: _email.isEmpty ? null : _selo(_emailConfirmed),
                  acao: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_email.isNotEmpty && !_emailConfirmed)
                        _acao('Verificar', _verificarEmail, forte: true),
                      _acao(
                        'Alterar',
                        () =>
                            _mostrarPopupEdicao('Email', _email, _trocarEmail),
                      ),
                    ],
                  ),
                ),
                _linha(
                  icone: Icons.phone_iphone_rounded,
                  rotulo: 'Celular',
                  valor: _telefone.isNotEmpty ? _telefone : 'Não informado',
                  selo: _telefone.isEmpty ? null : _selo(_telefoneConfirmado),
                  acao: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_telefone.isNotEmpty && !_telefoneConfirmado)
                        _acao('Verificar', _verificarTelefone, forte: true),
                      _acao(
                        _telefone.isEmpty ? 'Definir' : 'Alterar',
                        () => _mostrarPopupEdicao(
                          'Celular',
                          _telefone,
                          _salvarTelefone,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              _tituloGrupo('Segurança'),
              _grupo([
                _linha(
                  icone: Icons.lock_outline_rounded,
                  rotulo: 'Senha',
                  valor: '••••••••••',
                  acao: _acao('Alterar', _mostrarPopupEdicaoSenha),
                ),
              ]),
              const SizedBox(height: 24),

              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: _textGray, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seus dados pessoais estão protegidos e só são usados '
                      'para o funcionamento do ConsertaJá.',
                      style: TextStyle(
                        color: _textGray,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: _blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tituloGrupo(String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
    child: Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: _textGray,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );

  /// Bloco branco sólido (sem sombra) com as linhas separadas por divisória.
  Widget _grupo(List<Widget> linhas) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        for (var i = 0; i < linhas.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 56, color: Color(0xFFEDEFF2)),
          linhas[i],
        ],
      ],
    ),
  );

  Widget _linha({
    required IconData icone,
    required String rotulo,
    required String valor,
    Widget? selo,
    Widget? acao,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F6FE),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, color: _blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rotulo,
                      style: const TextStyle(
                        color: _textGray,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selo != null) ...[const SizedBox(width: 6), selo],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ?acao,
        ],
      ),
    );
  }

  Widget _acao(String texto, VoidCallback aoTocar, {bool forte = false}) {
    return CorOriginal(interface: true, ativo: forte, child: TextButton(
      onPressed: aoTocar,
      style: TextButton.styleFrom(
        foregroundColor: forte ? Colors.white : _blue,
        backgroundColor: forte ? _blue : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ));
  }

  Widget _selo(bool verificado) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: verificado ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      verificado ? 'Verificado' : 'Não verificado',
      style: TextStyle(
        color: verificado ? _verde : const Color(0xFFB45309),
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
