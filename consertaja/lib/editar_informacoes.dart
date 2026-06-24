import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'tela_meu_perfil_cliente.dart';

class EditarInformacoesPage extends StatefulWidget {
  const EditarInformacoesPage({super.key});

  @override
  State<EditarInformacoesPage> createState() => _EditarInformacoesPageState();
}

class _EditarInformacoesPageState extends State<EditarInformacoesPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _textGray = Color(0xFF7B7B7B);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  String _nomeCompleto = 'Carregando...';
  String _cpf = '';
  String _email = '';
  String _telefone = '';
  String _dataNascimento = '';
  String? _fotoPerfilUrl;
  String _genero = '';

  // IDs para atualização
  int? _telefoneId;
  String? _telefoneDDD;
  String? _telefoneNumero;
  int? _usuarioId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  String _obterIniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) {
      return 'U';
    }
    final partes = nome.trim().split(' ');
    if (partes.length > 1) {
      final sobrenome = partes.last.trim();
      if (sobrenome.length >= 2) {
        return sobrenome.substring(0, 2).toUpperCase();
      }
      return sobrenome.toUpperCase();
    }
    return nome.substring(0, 1).toUpperCase();
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
          .select('''
            id_usuario,
            nome,
            data_nascimento,
            foto_perfil_url,
            fk_email,
            fk_telefone,
            fk_tipo_pessoa
          ''')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      _usuarioId = usuarioResponse?['id_usuario'] as int?;
      String nome = usuarioResponse?['nome']?.toString() ?? 'Usuário';
      String dataNascimento = usuarioResponse?['data_nascimento']?.toString() ?? '';
      String? fotoUrl = usuarioResponse?['foto_perfil_url']?.toString();

      if (dataNascimento.isNotEmpty && dataNascimento != 'null') {
        try {
          final partes = dataNascimento.split('-');
          if (partes.length == 3) {
            dataNascimento = '${partes[2]}/${partes[1]}/${partes[0]}';
          }
        } catch (_) {}
      } else {
        dataNascimento = '';
      }

      // Buscar email
      String email = '';
      final emailId = usuarioResponse?['fk_email'];
      if (emailId != null) {
        try {
          final emailResponse = await _supabase
              .from('emails')
              .select('endereco_email')
              .eq('id_email', emailId)
              .maybeSingle();
          email = emailResponse?['endereco_email']?.toString() ?? user.email ?? '';
        } catch (_) {
          email = user.email ?? '';
        }
      } else {
        email = user.email ?? '';
      }

      // Buscar telefone
      String telefone = '';
      final telefoneId = usuarioResponse?['fk_telefone'];
      if (telefoneId != null) {
        _telefoneId = telefoneId as int;
        try {
          final telefoneResponse = await _supabase
              .from('telefones')
              .select('ddd, numero')
              .eq('id_telefone', _telefoneId!)
              .maybeSingle();
          if (telefoneResponse != null) {
            final ddd = telefoneResponse['ddd']?.toString() ?? '';
            final numero = telefoneResponse['numero']?.toString() ?? '';
            _telefoneDDD = ddd;
            _telefoneNumero = numero;
            if (ddd.isNotEmpty && numero.isNotEmpty) {
              telefone = '($ddd) $numero';
            }
          }
        } catch (_) {}
      }

      // Buscar CPF
      String cpf = '';
      final tipoPessoaId = usuarioResponse?['fk_tipo_pessoa'];
      if (tipoPessoaId != null) {
        try {
          final assTipoPessoaResponse = await _supabase
              .from('ass_tipo_pessoa')
              .select('fk_pessoa_fisica')
              .eq('id_tipo_pessoa', tipoPessoaId)
              .maybeSingle();
          final pfId = assTipoPessoaResponse?['fk_pessoa_fisica'];
          if (pfId != null) {
            final pfResponse = await _supabase
                .from('pessoa_fisica')
                .select('cpf')
                .eq('id_pessoa_fisica', pfId)
                .maybeSingle();
            final cpfRaw = pfResponse?['cpf']?.toString() ?? '';
            if (cpfRaw.length == 11) {
              cpf = '${cpfRaw.substring(0, 3)}.${cpfRaw.substring(3, 6)}.${cpfRaw.substring(6, 9)}-${cpfRaw.substring(9, 11)}';
            } else {
              cpf = cpfRaw;
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _nomeCompleto = nome;
          _cpf = cpf;
          _email = email;
          _telefone = telefone;
          _dataNascimento = dataNascimento;
          _fotoPerfilUrl = fotoUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
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
                  title: const Text('Remover Foto',
                      style: TextStyle(color: Colors.red)),
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
      if (user == null) return;

      final file = File(pickedFile.path);
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucketName = 'Foto Perfil';

      // Fazer upload para o Supabase Storage
      try {
        await _supabase.storage.from(bucketName).upload(
          fileName,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      } catch (bucketError) {
        // Se o bucket não existir, apenas ignora o erro de upload
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ocorreu um erro ao fazer upload da foto. Contate o suporte.')),
          );
        }
        return;
      }

      // Obter URL pública
      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);

      // Atualizar no banco
      await _supabase
          .from('usuarios')
          .update({'foto_perfil_url': publicUrl})
          .eq('auth_id', user.id);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar foto: $e')),
        );
      }
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

      if (mounted) {
        setState(() => _fotoPerfilUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto removida com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover foto: $e')),
        );
      }
    }
  }

  // ================= POPUP DE EDIÇÃO =================
  Future<void> _mostrarPopupEdicao(String campo, String valorAtual, Function(String) onSalvar) async {
    final controller = TextEditingController(text: valorAtual);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
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
                      decoration: InputDecoration(
                        labelText: campo,
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
                        if (value == null || value.trim().isEmpty) {
                          return 'Este campo não pode ficar vazio';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: _textGray,
                            fontSize: 15,
                          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar nome: $e')),
        );
      }
    }
  }

  Future<void> _salvarEmail(String novoEmail) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Atualizar email no auth
      await _supabase.auth.updateUser(UserAttributes(email: novoEmail));

      // Atualizar na tabela emails
      final usuarioResponse = await _supabase
          .from('usuarios')
          .select('fk_email')
          .eq('auth_id', user.id)
          .maybeSingle();

      final emailId = usuarioResponse?['fk_email'];
      if (emailId != null) {
        await _supabase
            .from('emails')
            .update({'endereco_email': novoEmail})
            .eq('id_email', emailId);
      }

      if (mounted) {
        setState(() => _email = novoEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar email: $e')),
        );
      }
    }
  }

  Future<void> _salvarTelefone(String novoTelefone) async {
    try {
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
        _telefoneId = telefoneResponse['id_telefone'] as int?;

        if (_usuarioId != null) {
          await _supabase
              .from('usuarios')
              .update({'fk_telefone': _telefoneId!})
              .eq('id_usuario', user.id);
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
      String dataFormatada = novaData;
      if (novaData.contains('/')) {
        final partes = novaData.split('/');
        if (partes.length == 3) {
          dataFormatada = '${partes[2]}-${partes[1]}-${partes[0]}';
        }
      }

      await _supabase
          .from('usuarios')
          .update({'data_nascimento': dataFormatada})
          .eq('auth_id', user.id);

      if (mounted) {
        setState(() => _dataNascimento = novaData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data de nascimento atualizada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar data: $e')),
        );
      }
    }
  }

  Future<void> _salvarGenero(String novoGenero) async {
    try {
      if (mounted) {
        setState(() => _genero = novoGenero);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gênero atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar gênero: $e')),
        );
      }
    }
  }

  void _definirCampo(String campo) {
    switch (campo) {
      case 'Nome':
        _mostrarPopupEdicao('Nome', _nomeCompleto, _salvarNome);
        break;
      case 'Email':
        _mostrarPopupEdicao('Email', _email, _salvarEmail);
        break;
      case 'Celular':
        _mostrarPopupEdicao('Celular', _telefone, _salvarTelefone);
        break;
      case 'Data de Nascimento':
        _mostrarPopupEdicao('Data de Nascimento', _dataNascimento, _salvarDataNascimento);
        break;
      case 'Gênero':
        _mostrarPopupEdicao('Gênero', _genero, _salvarGenero);
        break;
      case 'Senha':
        _mostrarPopupEdicaoSenha();
        break;
    }
  }

  Future<void> _mostrarPopupEdicaoSenha() async {
    final novaSenhaController = TextEditingController();
    final confirmarSenhaController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
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
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              final user = _supabase.auth.currentUser;
                              if (user != null) {
                                await _supabase.auth.updateUser(
                                  UserAttributes(password: novaSenhaController.text),
                                );
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Senha alterada com sucesso!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao alterar senha: $e')),
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
                      ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _blue,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
          label: const Text(
            'Voltar',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        title: const Text(
          'Editar Informações',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // ================= FOTO DE PERFIL =================
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: _blue,
                        backgroundImage: _fotoPerfilUrl != null && _fotoPerfilUrl!.trim().isNotEmpty
                            ? NetworkImage(_fotoPerfilUrl!)
                            : null,
                        child: _fotoPerfilUrl == null || _fotoPerfilUrl!.trim().isEmpty
                            ? Text(
                                _obterIniciais(_nomeCompleto),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _isUploading ? null : _alterarFoto,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isUploading ? Icons.hourglass_top : Icons.camera_alt_outlined,
                        color: _blue,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isUploading ? 'Enviando...' : 'Alterar Foto',
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ================= TIPO DE PERFIL =================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: _blue, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Tipo de perfil:',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Perfil de Cliente',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ================= DADOS PESSOAIS =================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dados Pessoais',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // CPF (não editável)
                _buildInfoField(
                  label: 'CPF',
                  value: _cpf.isNotEmpty ? _cpf : 'Não informado',
                  icon: Icons.badge_outlined,
                  editable: false,
                ),
                const SizedBox(height: 16),

                // Nome
                _buildInfoField(
                  label: 'Nome',
                  value: _nomeCompleto,
                  icon: Icons.person_outline,
                  editable: true,
                  showEditButton: true,
                  onTap: () => _definirCampo('Nome'),
                ),
                const SizedBox(height: 16),

                // Email
                _buildInfoField(
                  label: 'Email',
                  value: _email.isNotEmpty ? _email : 'Não informado',
                  icon: Icons.email_outlined,
                  editable: true,
                  isEmail: true,
                  showEditButton: true,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A função de alterar email ainda não foi implementada')),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Celular
                _buildInfoField(
                  label: 'Celular',
                  value: _telefone.isNotEmpty ? _telefone : 'Definir agora',
                  icon: Icons.phone_outlined,
                  editable: true,
                  showArrow: _telefone.isEmpty,
                  showEditButton: _telefone.isNotEmpty,
                  onTap: () => _definirCampo('Celular'),
                ),
                const SizedBox(height: 16),

                // Data de Nascimento
                _buildInfoField(
                  label: 'Data de Nascimento',
                  value: _dataNascimento.isNotEmpty ? _dataNascimento : 'Definir agora',
                  icon: Icons.cake_outlined,
                  editable: true,
                  showArrow: _dataNascimento.isEmpty,
                  showEditButton: _dataNascimento.isNotEmpty,
                  onTap: () => _definirCampo('Data de Nascimento'),
                ),
                const SizedBox(height: 16),

                // Gênero
                _buildInfoField(
                  label: 'Gênero',
                  value: _genero.isNotEmpty ? _genero : 'Definir agora',
                  icon: Icons.people_outline,
                  editable: true,
                  showArrow: _genero.isEmpty,
                  showEditButton: _genero.isNotEmpty,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A função de definir gênero ainda não foi implementada')),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // ================= SENHA =================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: _blue, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Senha:',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '************',
                              style: TextStyle(
                                color: _textGray,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A função de alterar senha ainda não foi implementada')),
                          );
                        },
                        child: const Text(
                          'Alterar >',
                          style: TextStyle(
                            color: _blue,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ================= RODAPÉ DE PRIVACIDADE =================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: _textGray, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: _textGray,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Os seus dados pessoais estão protegidos. Para mais informações confira a ',
                            ),
                            TextSpan(
                              text: 'Política de Privacidade.',
                              style: TextStyle(
                                color: _blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
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

  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
    required bool editable,
    bool isEmail = false,
    bool showArrow = false,
    bool showEditButton = false,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEmail && !_emailConfirmed)
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: _blue, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Valide o seu e-mail',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    value,
                    style: const TextStyle(
                      color: _textGray,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (editable && showArrow)
            InkWell(
              onTap: onTap,
              child: const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 22),
            ),
          if (editable && showEditButton && !isEmail)
            InkWell(
              onTap: onTap,
              child: const Text(
                'Alterar >',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (editable && isEmail)
            InkWell(
              onTap: onTap,
              child: const Text(
                'Alterar >',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get _emailConfirmed {
    final user = _supabase.auth.currentUser;
    return user?.emailConfirmedAt != null;
  }
}