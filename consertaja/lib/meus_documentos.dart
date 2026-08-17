import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _DocumentoStatus { validado, pendente }

class _DocumentoItem {
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final _DocumentoStatus status;
  final bool iconeAtivo;

  const _DocumentoItem({
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

  Widget _buildBotaoValidar() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        icon: const Icon(Icons.camera_alt_outlined, size: 20),
        label: const Text(
          'Validar Agora',
          style: TextStyle(
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
            _buildBotaoValidar(),
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