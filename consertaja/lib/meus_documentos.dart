import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _DocumentoStatus { validado, pendente }

class _DocumentoItem {
  final String tipo;
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final _DocumentoStatus status;
  final bool iconeAtivo;

  const _DocumentoItem({
    required this.tipo,
    required this.titulo,
    this.subtitulo,
    required this.icone,
    required this.status,
    this.iconeAtivo = true,
  });
}

class MeusDocumentosPage extends StatefulWidget {
  const MeusDocumentosPage({super.key});

  @override
  State<MeusDocumentosPage> createState() => _MeusDocumentosPageState();
}

class _MeusDocumentosPageState extends State<MeusDocumentosPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _iconBlue = Color(0xFF1A3A5C);
  static const Color _iconCircleBlue = Color(0xFFE8F7FF);
  static const Color _iconCircleGray = Color(0xFFF0F0F0);
  static const Color _iconGray = Color(0xFF878B8D);
  static const Color _greenBadgeBg = Color(0xFFE8F5E9);
  static const Color _greenBadgeText = Color(0xFF2E7D32);
  static const Color _pendingColor = Color(0xFFD97706);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _salvando = false;
  List<_DocumentoItem> _documentos = [];

  /// Mapeia o tipo de documento vindo do Supabase para os dados de exibição.
  static const Map<String, ({String titulo, String subtitulo, IconData icone})>
      _tiposDocumento = {
    'RG': (
      titulo: 'RG',
      subtitulo: 'Registro Geral',
      icone: Icons.badge_outlined,
    ),
    'CIN': (
      titulo: 'CIN',
      subtitulo: 'Carteira de Identidade Nacional',
      icone: Icons.description_outlined,
    ),
    'CNH': (
      titulo: 'CNH',
      subtitulo: 'Carteira Nacional de Habilitação',
      icone: Icons.directions_car_outlined,
    ),
    'PASSAPORTE': (
      titulo: 'Passaporte',
      subtitulo: 'Passaporte',
      icone: Icons.menu_book_outlined,
    ),
  };

  /// Ordem de exibição dos tipos de documento.
  static const List<String> _ordemTipos = ['RG', 'CIN', 'CNH', 'PASSAPORTE'];

  @override
  void initState() {
    super.initState();
    _carregarDocumentos();
  }

  Future<int?> _buscarIdUsuario(String authId) async {
    final response = await _supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authId)
        .maybeSingle();
    if (response == null) return null;
    final id = response['id_usuario'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Future<void> _carregarDocumentos() async {
    setState(() => _carregando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // 1. Busca o id_usuario do usuário logado
      final usuarioId = await _buscarIdUsuario(user.id);
      if (usuarioId == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // 2. Busca o id_profissional na tabela dados_profissionais
      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      if (dadosProf == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
      if (idProfissional == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      // 3. Busca os documentos do profissional
      final docsResponse = await _supabase
          .from('documentos_profissionais')
          .select('tipo_documento, validacao_documento')
          .eq('fk_profissional', idProfissional);

      // 4. Converte os dados do Supabase para um mapa de status por tipo
      final statusPorTipo = <String, bool>{};
      for (final doc in docsResponse) {
        final tipo = doc['tipo_documento']?.toString().toUpperCase() ?? '';
        if (tipo.isEmpty) continue;
        statusPorTipo[tipo] = doc['validacao_documento'] == true;
      }

      // 5. Monta a lista de documentos exibindo TODOS os tipos possíveis.
      //    Documentos que não existem no banco ou com validacao_documento = false
      //    são exibidos como pendentes.
      final documentos = <_DocumentoItem>[];

      for (final tipo in _ordemTipos) {
        final info = _tiposDocumento[tipo];
        if (info == null) continue;

        final validado = statusPorTipo[tipo] ?? false;

        documentos.add(
          _DocumentoItem(
            tipo: tipo,
            titulo: info.titulo,
            subtitulo: info.subtitulo,
            icone: info.icone,
            status: validado
                ? _DocumentoStatus.validado
                : _DocumentoStatus.pendente,
            iconeAtivo: validado,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _documentos = documentos;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar documentos: $e')),
        );
      }
    }
  }

  /// Busca os dados do profissional (CPF/CNPJ, data de nascimento, tipo de pessoa)
  /// para usar na validação dos documentos.
  Future<Map<String, dynamic>?> _buscarDadosParaValidacao() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final usuario = await _supabase
          .from('usuarios')
          .select('fk_tipo_pessoa, data_nascimento')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuario == null) return null;

      final dados = <String, dynamic>{
        'data_nascimento': usuario['data_nascimento']?.toString() ?? '',
      };

      final tipoPessoaId = usuario['fk_tipo_pessoa'];
      if (tipoPessoaId == null) return dados;

      final assTipoPessoa = await _supabase
          .from('ass_tipo_pessoa')
          .select('fk_pessoa_fisica, fk_pessoa_juridica')
          .eq('id_tipo_pessoa', tipoPessoaId)
          .maybeSingle();
      if (assTipoPessoa == null) return dados;

      final pfId = assTipoPessoa['fk_pessoa_fisica'];
      if (pfId != null) {
        // Pessoa física
        final pf = await _supabase
            .from('pessoa_fisica')
            .select('cpf')
            .eq('id_pessoa_fisica', pfId)
            .maybeSingle();
        if (pf != null) {
          dados['cpf'] = pf['cpf']?.toString() ?? '';
        }
        dados['is_pessoa_juridica'] = false;
      } else {
        // Pessoa jurídica
        final pjId = assTipoPessoa['fk_pessoa_juridica'];
        if (pjId != null) {
          final pj = await _supabase
              .from('pessoa_juridica')
              .select('cnpj')
              .eq('id_pessoa_juridica', pjId)
              .maybeSingle();
          if (pj != null) {
            dados['cnpj'] = pj['cnpj']?.toString() ?? '';
          }
        }
        dados['is_pessoa_juridica'] = true;
      }

      return dados;
    } catch (e) {
      debugPrint('Erro ao buscar dados para validação: $e');
      return null;
    }
  }

  /// Busca o id_profissional do usuário logado.
  Future<int?> _buscarIdProfissional() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final usuarioId = await _buscarIdUsuario(user.id);
      if (usuarioId == null) return null;

      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      if (dadosProf == null) return null;

      return (dadosProf['id_profissional'] as num?)?.toInt();
    } catch (e) {
      debugPrint('Erro ao buscar id_profissional: $e');
      return null;
    }
  }

  /// Abre o fluxo de validação de documentos diretamente (sem tela intermediária).
  Future<void> _abrirValidacaoDocumento(String tipoDocumento) async {
    if (_salvando) return;

    // Busca os dados do profissional para validar os documentos
    final dadosValidacao = await _buscarDadosParaValidacao();
    if (dadosValidacao == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar seus dados. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Abre a página de validação direta (captura frente/verso sem tela de lista)
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _ValidarDocumentoPage(
          tipoDocumento: tipoDocumento,
          cpf: dadosValidacao['cpf'] as String?,
          cnpj: dadosValidacao['cnpj'] as String?,
          dataNascimento: dadosValidacao['data_nascimento'] as String?,
          isPessoaJuridica: dadosValidacao['is_pessoa_juridica'] == true,
        ),
      ),
    );

    if (resultado != null && resultado['validado'] == true && mounted) {
      final docsData = List<Map<String, dynamic>>.from(resultado['docsData'] ?? []);

      if (docsData.isEmpty) return;

      // Salva os documentos validados no Supabase
      setState(() => _salvando = true);

      try {
        final idProfissional = await _buscarIdProfissional();
        if (idProfissional == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível identificar seu perfil profissional.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _salvando = false);
          return;
        }

        for (final doc in docsData) {
          final tipo = doc['tipo']?.toString().toUpperCase() ?? '';
          if (tipo.isEmpty) continue;

          // Verifica se o documento já existe para atualizar ou inserir
          final existente = await _supabase
              .from('documentos_profissionais')
              .select('id_documento')
              .eq('fk_profissional', idProfissional)
              .eq('tipo_documento', tipo)
              .maybeSingle();

          if (existente != null) {
            // Atualiza o documento existente para validado
            await _supabase
                .from('documentos_profissionais')
                .update({'validacao_documento': true})
                .eq('id_documento', existente['id_documento']);
          } else {
            // Insere novo documento validado
            await _supabase.from('documentos_profissionais').insert({
              'tipo_documento': tipo,
              'fk_profissional': idProfissional,
              'validacao_documento': true,
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento(s) validado(s) com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Recarrega a lista de documentos
        await _carregarDocumentos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar documentos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _blue, size: 20),
          ),
          const Expanded(
            child: Text(
              'Meus Documentos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIntroducao() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos validados',
            style: TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Gerencie seus documentos de identidade. Documentos validados aumentam sua confiabilidade na plataforma.',
            style: TextStyle(
              color: _textGray,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconeDocumento(_DocumentoItem documento) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: documento.iconeAtivo ? _iconCircleBlue : _iconCircleGray,
        shape: BoxShape.circle,
      ),
      child: Icon(
        documento.icone,
        color: documento.iconeAtivo ? _iconBlue : _iconGray,
        size: 22,
      ),
    );
  }

  Widget _buildBadgeValidado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _greenBadgeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, color: _greenBadgeText, size: 16),
          SizedBox(width: 4),
          Text(
            'Validado',
            style: TextStyle(
              color: _greenBadgeText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPendente() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _pendingColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Pendente',
          style: TextStyle(
            color: _pendingColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoValidar(_DocumentoItem documento) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: _salvando
            ? null
            : () => _abrirValidacaoDocumento(documento.tipo),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        icon: _salvando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.camera_alt_outlined, size: 20),
        label: Text(
          _salvando ? 'Salvando...' : 'Validar Agora',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCardDocumento(_DocumentoItem documento) {
    final isPendente = documento.status == _DocumentoStatus.pendente;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconeDocumento(documento),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documento.titulo,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isPendente) ...[
                      const SizedBox(height: 4),
                      _buildStatusPendente(),
                    ] else if (documento.subtitulo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        documento.subtitulo!,
                        style: const TextStyle(
                          color: _textGray,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isPendente) _buildBadgeValidado(),
            ],
          ),
          if (isPendente) ...[
            const SizedBox(height: 14),
            _buildBotaoValidar(documento),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(color: _blue),
                    )
                  : _documentos.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum documento encontrado.',
                            style: TextStyle(
                              color: _textGray,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildIntroducao(),
                            ..._documentos.map(_buildCardDocumento),
                            const SizedBox(height: 16),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= PÁGINA DE VALIDAÇÃO DIRETA (SEM TELA DE LISTA) =================
/// Página que captura frente/verso do documento e valida via OCR,
/// sem mostrar a tela de "Escolha o tipo de documento".
class _ValidarDocumentoPage extends StatefulWidget {
  final String tipoDocumento;
  final String? cpf;
  final String? cnpj;
  final String? dataNascimento;
  final bool isPessoaJuridica;

  const _ValidarDocumentoPage({
    required this.tipoDocumento,
    this.cpf,
    this.cnpj,
    this.dataNascimento,
    this.isPessoaJuridica = false,
  });

  @override
  State<_ValidarDocumentoPage> createState() => _ValidarDocumentoPageState();
}

class _ValidarDocumentoPageState extends State<_ValidarDocumentoPage> {
  static const Color _blue = Color(0xFF0FB3FF);

  final ImagePicker _picker = ImagePicker();
  bool _processando = false;
  String? _filePathFrente;
  String? _filePathVerso;

  // UFs e Órgãos Emissores válidos do Brasil
  static const List<String> _ufsValidas = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
    'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];

  static const List<String> _orgaosValidos = [
    'SSP', 'SESP', 'SDS', 'DETRAN', 'POLÍCIA CIVIL', 'PC', 'SECRETARIA DE SEGURANÇA PÚBLICA',
    'INSTITUTO DE IDENTIFICAÇÃO', 'IFP', 'II', 'DIC', 'DPC', 'MTB', 'CREA', 'CRC',
    'OAB', 'CRM', 'SSP-SP', 'SSP-RJ', 'SSP-MG', 'SSP-BA', 'SSP-RS', 'SSP-PR',
    'SSP-PE', 'SSP-CE', 'SSP-PA', 'SSP-MA', 'SSP-SC', 'SSP-GO', 'SSP-DF',
    'SESP-PI', 'SDS-PE'
  ];

  @override
  void initState() {
    super.initState();
    // Inicia automaticamente a captura da frente ao abrir a página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturarFrente();
    });
  }

  String _somenteDigitos(String valor) {
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  bool _validarCpfLocal(String cpf) {
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    final numeros = cpf.split('').map(int.parse).toList();

    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += numeros[i] * (10 - i);
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;
    if (numeros[9] != digito1) return false;

    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += numeros[i] * (11 - i);
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    return numeros[10] == digito2;
  }

  bool _validarCnpjLocal(String cnpj) {
    if (cnpj.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

    final numeros = cnpj.split('').map(int.parse).toList();

    const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

    int soma = 0;
    for (int i = 0; i < 12; i++) {
      soma += numeros[i] * pesos1[i];
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;
    if (numeros[12] != digito1) return false;

    soma = 0;
    for (int i = 0; i < 13; i++) {
      soma += numeros[i] * pesos2[i];
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    return numeros[13] == digito2;
  }

  String? _extrairCpf(String texto) {
    var textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

    final regex1 = RegExp(r'\d{3}\.?\d{3}\.?\d{3}-?\d{2}');
    var match = regex1.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    final regex2 = RegExp(r'\d{9,11}/\d{2}');
    match = regex2.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    final regex4 = RegExp(r'CPF[:\s]*(\d{3}[\s\.]?\d{3}[\s\.]?\d{3}[\s\-]?\d{2})');
    match = regex4.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(1)!);
    }

    final apenasDigitos = _somenteDigitos(texto);
    if (apenasDigitos.length >= 11) {
      for (int i = 0; i <= apenasDigitos.length - 11; i++) {
        final candidato = apenasDigitos.substring(i, i + 11);
        if (!RegExp(r'^(\d)\1{10}$').hasMatch(candidato)) {
          if (_validarCpfLocal(candidato)) {
            return candidato;
          }
        }
      }
    }

    return null;
  }

  String? _extrairCnpj(String texto) {
    var textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

    final regex1 = RegExp(r'\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}');
    var match = regex1.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    final apenasDigitos = _somenteDigitos(texto);
    if (apenasDigitos.length >= 14) {
      for (int i = 0; i <= apenasDigitos.length - 14; i++) {
        final candidato = apenasDigitos.substring(i, i + 14);
        if (!RegExp(r'^(\d)\1{13}$').hasMatch(candidato)) {
          if (_validarCnpjLocal(candidato)) {
            return candidato;
          }
        }
      }
    }

    final regex3 = RegExp(r'CNPJ[:\s]*(\d{2}[\s\.]?\d{3}[\s\.]?\d{3}[\s\/]?\d{4}[\s\-]?\d{2})');
    match = regex3.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(1)!);
    }

    return null;
  }

  List<DateTime> _extrairDatas(String texto) {
    final datas = <DateTime>[];
    final regex1 = RegExp(r'\d{2}/\d{2}/\d{4}');
    final regex2 = RegExp(r'\d{4}-\d{2}-\d{2}');

    for (final match in regex1.allMatches(texto)) {
      final partes = match.group(0)!.split('/');
      final dia = int.tryParse(partes[0]) ?? 0;
      final mes = int.tryParse(partes[1]) ?? 0;
      final ano = int.tryParse(partes[2]) ?? 0;
      if (ano >= 1920 && ano <= 2050 && mes >= 1 && mes <= 12 && dia >= 1 && dia <= 31) {
        datas.add(DateTime(ano, mes, dia));
      }
    }

    for (final match in regex2.allMatches(texto)) {
      final partes = match.group(0)!.split('-');
      final ano = int.tryParse(partes[0]) ?? 0;
      final mes = int.tryParse(partes[1]) ?? 0;
      final dia = int.tryParse(partes[2]) ?? 0;
      if (ano >= 1920 && ano <= 2050 && mes >= 1 && mes <= 12 && dia >= 1 && dia <= 31) {
        datas.add(DateTime(ano, mes, dia));
      }
    }

    return datas;
  }

  String? _extrairRg(String texto) {
    final regex = RegExp(r'\d{1,2}\.?\d{3}\.?\d{3}-?[\dxX]');
    final match = regex.firstMatch(texto);
    return match?.group(0);
  }

  String? _extrairUf(String texto) {
    for (final uf in _ufsValidas) {
      if (texto.contains(uf)) return uf;
    }
    return null;
  }

  String? _extrairOrgaoEmissor(String texto) {
    for (final orgao in _orgaosValidos) {
      if (texto.toUpperCase().contains(orgao)) return orgao;
    }
    return null;
  }

  bool _validarFormatoRg(String? rg, String? uf) {
    if (rg == null) return false;
    final digitos = _somenteDigitos(rg);
    return digitos.length >= 7 && digitos.length <= 11;
  }

  bool _verificarNacionalidadeBrasileira(String texto) {
    final textoUp = texto.toUpperCase();
    return textoUp.contains('BRASILEIRO') ||
        textoUp.contains('BRASILEIRA') ||
        textoUp.contains('BRAZIL') ||
        textoUp.contains('NACIONALIDADE') ||
        textoUp.contains('REPÚBLICA FEDERATIVA DO BRASIL') ||
        textoUp.contains('REPUBLICA FEDERATIVA DO BRASIL');
  }

  DateTime? _parseData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return null;
    try {
      if (dataStr.contains('-')) {
        final partes = dataStr.split('-');
        return DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
      }
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        return DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
      }
    } catch (_) {}
    return null;
  }

  DateTime? _encontrarDataNascimento(List<DateTime> datas, String? dataNascimentoEsperada) {
    if (datas.isEmpty) return null;

    final dataEsperada = _parseData(dataNascimentoEsperada);
    if (dataEsperada != null) {
      for (final data in datas) {
        if (data.year == dataEsperada.year &&
            data.month == dataEsperada.month &&
            data.day == dataEsperada.day) {
          return data;
        }
      }
    }

    if (datas.length == 1) return datas.first;

    datas.sort((a, b) => a.compareTo(b));
    return datas.first;
  }

  Future<String> _processarOcr(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      return recognizedText.text;
    } catch (e) {
      debugPrint('Erro no OCR: $e');
      return '';
    }
  }

  Future<ImageSource?> _mostrarOpcoesOrigem(String titulo) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: _blue),
                title: const Text('Tirar Foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: _blue),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _capturarFrente() async {
    if (_processando) return;

    final source = await _mostrarOpcoesOrigem('Frente do Documento');
    if (source == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );

    if (file == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _filePathFrente = file.path;
    });

    // Agora pede o verso
    await _capturarVerso();
  }

  Future<void> _capturarVerso() async {
    final source = await _mostrarOpcoesOrigem('Verso do Documento');
    if (source == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (file == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _filePathVerso = file.path;
      _processando = true;
    });

    // Processa OCR da frente e verso
    String fullText = '';
    try {
      fullText = await _processarOcr(File(_filePathFrente!));
    } catch (e) {
      fullText = '';
    }

    String fullTextVerso = '';
    try {
      fullTextVerso = await _processarOcr(File(_filePathVerso!));
    } catch (e) {
      fullTextVerso = '';
    }

    fullText = '$fullText\n$fullTextVerso';

    debugPrint('=== TEXTO EXTRAÍDO DO DOCUMENTO ${widget.tipoDocumento} ===');
    debugPrint(fullText);
    debugPrint('==============================================');

    // Valida o documento
    final erros = <String>[];
    bool valido = true;

    if (widget.isPessoaJuridica) {
      final cnpjDigitado = widget.cnpj != null ? _somenteDigitos(widget.cnpj!) : null;
      final cnpjEncontrado = _extrairCnpj(fullText);

      if (cnpjDigitado == null) {
        erros.add('CNPJ não encontrado no cadastro.');
        valido = false;
      } else if (cnpjEncontrado == null) {
        erros.add('Não foi possível identificar o CNPJ no documento.');
        valido = false;
      } else if (cnpjEncontrado != cnpjDigitado) {
        erros.add('CNPJ do documento não corresponde ao CNPJ cadastrado.');
        valido = false;
      }
    } else {
      final cpfDigitado = widget.cpf != null ? _somenteDigitos(widget.cpf!) : null;
      final cpfEncontrado = _extrairCpf(fullText);
      final datas = _extrairDatas(fullText);
      final dataNascimentoStr = widget.dataNascimento;

      switch (widget.tipoDocumento) {
        case 'RG':
          if (cpfDigitado == null) {
            erros.add('CPF não encontrado no cadastro.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }

          final rg = _extrairRg(fullText);
          final uf = _extrairUf(fullText);
          if (!_validarFormatoRg(rg, uf)) {
            erros.add('Número do RG não identificado ou formato inválido.');
            valido = false;
          }

          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(datas, dataNascimentoStr);
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add('Data de nascimento do documento não confere com a cadastrada.');
                valido = false;
              }
            }
          }

          final orgao = _extrairOrgaoEmissor(fullText);
          if (orgao == null) {
            erros.add('Órgão emissor não identificado.');
            valido = false;
          }
          if (uf == null) {
            erros.add('UF do documento não identificada.');
            valido = false;
          } else if (!_ufsValidas.contains(uf)) {
            erros.add('UF "$uf" não é válida.');
            valido = false;
          }
          break;

        case 'CIN':
          if (cpfDigitado == null) {
            erros.add('CPF não encontrado no cadastro.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(datas, dataNascimentoStr);
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add('Data de nascimento do documento não confere com a cadastrada.');
                valido = false;
              }
            }
          }
          final orgao = _extrairOrgaoEmissor(fullText);
          if (orgao == null) {
            erros.add('Órgão emissor não identificado.');
            valido = false;
          }
          final uf = _extrairUf(fullText);
          if (uf == null) {
            erros.add('UF do documento não identificada.');
            valido = false;
          } else if (!_ufsValidas.contains(uf)) {
            erros.add('UF "$uf" não é válida.');
            valido = false;
          }
          break;

        case 'CNH':
          if (cpfDigitado == null) {
            erros.add('CPF não encontrado no cadastro.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }
          final hojeCNH = DateTime.now();
          bool temDataValida = false;
          for (final data in datas) {
            if (data.isAfter(hojeCNH) ||
                (data.year == hojeCNH.year && data.month == hojeCNH.month && data.day == hojeCNH.day)) {
              temDataValida = true;
              break;
            }
          }
          if (!temDataValida && datas.isNotEmpty) {
            erros.add('Documento parece estar vencido (data de validade expirada).');
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(datas, dataNascimentoStr);
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add('Data de nascimento do documento não confere com a cadastrada.');
                valido = false;
              }
            }
          }
          break;

        case 'PASSAPORTE':
          final hojePass = DateTime.now();
          bool temDataValidaPass = false;
          for (final data in datas) {
            if (data.isAfter(hojePass)) {
              temDataValidaPass = true;
              break;
            }
          }
          if (!temDataValidaPass) {
            erros.add('Passaporte parece estar vencido ou data de validade não identificada.');
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(datas, dataNascimentoStr);
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no passaporte.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add('Data de nascimento do passaporte não confere com a cadastrada.');
                valido = false;
              }
            }
          }
          if (!_verificarNacionalidadeBrasileira(fullText)) {
            erros.add('Nacionalidade brasileira não identificada no passaporte.');
            valido = false;
          }
          break;
      }
    }

    if (!mounted) return;

    setState(() {
      _processando = false;
    });

    if (valido) {
      // Sucesso - retorna o resultado
      Navigator.pop(context, {
        'validado': true,
        'docsData': [
          {'tipo': widget.tipoDocumento},
        ],
      });
    } else {
      // Falha - mostra erro e permite tentar novamente
      _mostrarErroValidacao(erros);
    }
  }

  void _mostrarErroValidacao(List<String> erros) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Falha na validação', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Não foi possível validar o documento. Verifique:'),
            const SizedBox(height: 12),
            ...erros.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Tenta novamente
              _capturarFrente();
            },
            child: const Text('Tentar Novamente', style: TextStyle(color: _blue)),
          ),
        ],
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Validar ${widget.tipoDocumento}',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: _processando
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _blue),
                  SizedBox(height: 16),
                  Text(
                    'Validando documento...',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.credit_card, size: 80, color: _blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Capturando documento...',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aguarde, estamos preparando a captura.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }
}