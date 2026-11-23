import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/avisos_bottom_sheet.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_da_tela.dart';

const _bucket = 'Certificados Profissional';
const _azul = Color(0xFF0FB3FF);
const _texto = Color(0xFF111827);
const _sec = Color(0xFF6B7280);

/// Certificado de um profissional (ou da empresa).
class Certificado {
  const Certificado({
    required this.id,
    required this.titulo,
    required this.arquivo,
    required this.tipo,
    this.dataEmissao,
  });

  final int id;
  final String titulo;
  final String arquivo; // caminho no bucket
  final String tipo; // 'imagem' | 'pdf'
  final DateTime? dataEmissao;

  bool get ehPdf => tipo == 'pdf';

  String get url =>
      Supabase.instance.client.storage.from(_bucket).getPublicUrl(arquivo);

  String get dataTexto {
    final d = dataEmissao;
    if (d == null) return 'Sem data de emissão';
    return 'Emitido em ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  factory Certificado.fromMap(Map<String, dynamic> m) => Certificado(
    id: (m['id_certificado'] as num).toInt(),
    titulo: m['titulo']?.toString() ?? '',
    arquivo: m['arquivo']?.toString() ?? '',
    tipo: m['tipo_arquivo']?.toString() ?? 'imagem',
    dataEmissao: DateTime.tryParse(m['data_emissao']?.toString() ?? ''),
  );
}

class CertificadosService {
  CertificadosService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Certificado>> listar({
    int? idProfissional,
    int? idGrupoEmpresa,
  }) async {
    if (idProfissional == null && idGrupoEmpresa == null) return const [];
    try {
      var q = _db.from('certificados_profissional').select();
      q = idGrupoEmpresa != null
          ? q.eq('fk_grupo_empresa', idGrupoEmpresa)
          : q.eq('fk_profissional', idProfissional!);
      final rows = await q.order('data_emissao', ascending: false);
      return rows.map(Certificado.fromMap).toList();
    } catch (e) {
      debugPrint('[certificados] $e');
      return const [];
    }
  }

  /// id_profissional do usuário logado.
  static Future<int?> meuIdProfissional() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final u = await _db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id)
        .limit(1)
        .maybeSingle();
    if (u == null) return null;
    final d = await _db
        .from('dados_profissionais')
        .select('id_profissional')
        .eq('fk_usuario', u['id_usuario'])
        .limit(1)
        .maybeSingle();
    return (d?['id_profissional'] as num?)?.toInt();
  }

  static Future<void> adicionar({
    int? idProfissional,
    int? idGrupoEmpresa,
    required String titulo,
    DateTime? dataEmissao,
    required Uint8List bytes,
    required String extensao,
  }) async {
    final uid = _db.auth.currentUser!.id;
    final ext = extensao.toLowerCase();
    final pdf = ext == 'pdf';
    final caminho = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(
            contentType: pdf
                ? 'application/pdf'
                : 'image/${ext == 'jpg' ? 'jpeg' : ext}',
          ),
        );
    await _db.from('certificados_profissional').insert({
      'fk_profissional': ?idGrupoEmpresa == null ? idProfissional : null,
      'fk_grupo_empresa': ?idGrupoEmpresa,
      'titulo': titulo,
      if (dataEmissao != null)
        'data_emissao': dataEmissao.toIso8601String().substring(0, 10),
      'arquivo': caminho,
      'tipo_arquivo': pdf ? 'pdf' : 'imagem',
    });
  }

  static Future<void> remover(Certificado c) async {
    await _db
        .from('certificados_profissional')
        .delete()
        .eq('id_certificado', c.id);
    try {
      await _db.storage.from(_bucket).remove([c.arquivo]);
    } catch (_) {}
  }
}

/// Abre o certificado grande (imagem com zoom; PDF no visualizador).
Future<void> abrirCertificado(BuildContext context, Certificado c) async {
  if (c.ehPdf) {
    await launchUrl(Uri.parse(c.url), mode: LaunchMode.externalApplication);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(c.titulo),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.network(c.url, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

/// Cartão com a prévia (imagem ou PDF), título e data.
class CartaoCertificado extends StatelessWidget {
  const CartaoCertificado({
    super.key,
    required this.c,
    this.largura = 220,
    this.aoRemover,
  });

  final Certificado c;
  final double? largura;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => abrirCertificado(context, c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: c.ehPdf
                        ? Container(
                            color: const Color(0xFFFEE2E2),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 44,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'PDF • toque para abrir',
                                  style: TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                            c.url,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, p) => p == null
                                ? child
                                : const SkeletonBox(
                                    height: 130,
                                    borderRadius: 0,
                                  ),
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: _sec,
                              ),
                            ),
                          ),
                  ),
                  if (aoRemover != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: aoRemover,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _texto,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.dataTexto,
                      style: const TextStyle(color: _sec, fontSize: 12),
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
}

/// Seção "Certificados" do perfil público (rolagem horizontal).
class SecaoCertificados extends StatefulWidget {
  const SecaoCertificados({
    super.key,
    this.idProfissional,
    this.idGrupoEmpresa,
  });

  final int? idProfissional;
  final int? idGrupoEmpresa;

  @override
  State<SecaoCertificados> createState() => _SecaoCertificadosState();
}

class _SecaoCertificadosState extends State<SecaoCertificados> {
  List<Certificado>? _lista;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant SecaoCertificados old) {
    super.didUpdateWidget(old);
    if (old.idProfissional != widget.idProfissional ||
        old.idGrupoEmpresa != widget.idGrupoEmpresa) {
      _carregar();
    }
  }

  Future<void> _carregar() async {
    final l = await CertificadosService.listar(
      idProfissional: widget.idProfissional,
      idGrupoEmpresa: widget.idGrupoEmpresa,
    );
    if (mounted) setState(() => _lista = l);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    if (lista != null && lista.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: _azul, size: 20),
                SizedBox(width: 6),
                Text(
                  'Certificados',
                  style: TextStyle(
                    color: _texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 196,
            child: lista == null
                ? ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: const [
                      SkeletonBox(width: 220, height: 196, borderRadius: 18),
                      SizedBox(width: 12),
                      SkeletonBox(width: 220, height: 196, borderRadius: 18),
                    ],
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: CartaoCertificado(c: lista[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tela "Certificados": o profissional (ou a empresa, com [idGrupoEmpresa])
/// adiciona, vê e remove certificados.
class CertificadosPage extends StatefulWidget {
  const CertificadosPage({super.key, this.idGrupoEmpresa});

  final int? idGrupoEmpresa;

  @override
  State<CertificadosPage> createState() => _CertificadosPageState();
}

class _CertificadosPageState extends State<CertificadosPage>
    with TutorialDaTela<CertificadosPage> {
  int? _idProfissional;
  List<Certificado>? _lista;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    _idProfissional ??= await CertificadosService.meuIdProfissional();
    final l = await CertificadosService.listar(
      idProfissional: _idProfissional,
      idGrupoEmpresa: widget.idGrupoEmpresa,
    );
    if (mounted) setState(() => _lista = l);
  }

  Future<void> _adicionar() async {
    final novo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FormCertificado(
        idProfissional: _idProfissional,
        idGrupoEmpresa: widget.idGrupoEmpresa,
      ),
    );
    if (novo == true) _carregar();
  }

  Future<void> _remover(Certificado c) async {
    final ok = await mostrarAvisoBottomSheet<bool>(
      context,
      icone: Icons.delete_outline_rounded,
      corIcone: const Color(0xFFDC2626),
      titulo: 'Remover certificado?',
      mensagem: '"${c.titulo}" deixa de aparecer no seu perfil.',
      textoBotao: 'Remover',
      valorBotao: true,
      textoSecundario: 'Cancelar',
      valorSecundario: false,
    );
    if (ok != true) return;
    await CertificadosService.remover(c);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    if (lista != null) {
      tutorialDaTela(
        chave: 'certificados',
        passos: () => [
          PassoTutorial(
            'Aqui ficam os seus cursos e certificações. Eles aparecem no seu '
            'perfil e passam mais confiança aos clientes.',
            alvo: chaveTut('lista'),
          ),
          PassoTutorial(
            'Para cadastrar um certificado, com foto, toque em "Adicionar".',
            alvo: chaveTut('adicionar'),
            raio: 20,
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6FA),
        surfaceTintColor: const Color(0xFFF3F6FA),
        elevation: 0,
        title: const Text(
          'Certificados',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: chaveTut('adicionar'),
        onPressed: _adicionar,
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Adicionar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: KeyedSubtree(
        key: chaveTut('lista'),
        child: lista == null
            ? GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: List.generate(
                  4,
                  (_) => const SkeletonBox(
                    height: double.infinity,
                    borderRadius: 18,
                  ),
                ),
              )
            : lista.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: _azul,
                        size: 56,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Nenhum certificado ainda',
                        style: TextStyle(
                          color: _texto,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Adicione cursos e certificações: eles aparecem no seu '
                        'perfil e passam mais confiança aos clientes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _sec),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: lista.length,
                itemBuilder: (_, i) => CartaoCertificado(
                  c: lista[i],
                  largura: null,
                  aoRemover: () => _remover(lista[i]),
                ),
              ),
      ),
    );
  }
}

class _FormCertificado extends StatefulWidget {
  const _FormCertificado({this.idProfissional, this.idGrupoEmpresa});

  final int? idProfissional;
  final int? idGrupoEmpresa;

  @override
  State<_FormCertificado> createState() => _FormCertificadoState();
}

class _FormCertificadoState extends State<_FormCertificado> {
  final _titulo = TextEditingController();
  DateTime? _data;
  PlatformFile? _arquivo;
  bool _enviando = false;
  String? _erro;
  bool _avisoAnexo = false;
  Timer? _timerAviso;

  @override
  void dispose() {
    _titulo.dispose();
    _timerAviso?.cancel();
    super.dispose();
  }

  Future<void> _escolherArquivo() async {
    final r = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (r == null || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _arquivo = r;
      _avisoAnexo = true;
    });
    _timerAviso?.cancel();
    _timerAviso = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _avisoAnexo = false);
    });
  }

  /// Aviso verde que sobe e pode ser arrastado para baixo (dispensado).
  Widget _avisoAnexado() => AnimatedSize(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    child: !_avisoAnexo
        ? const SizedBox(width: double.infinity)
        : Dismissible(
            key: const ValueKey('aviso_anexo'),
            direction: DismissDirection.down,
            onDismissed: (_) => setState(() => _avisoAnexo = false),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Documento anexado com sucesso!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
  );

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _data ?? hoje,
      firstDate: DateTime(1970),
      lastDate: hoje,
      helpText: 'Data de emissão',
      // Azul do app (antes vinha roxo do tema padrão).
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: _azul,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _texto,
            surfaceTint: Colors.transparent,
          ),
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: Colors.white,
            headerBackgroundColor: _azul,
            headerForegroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _azul),
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _salvar() async {
    final titulo = _titulo.text.trim();
    final arq = _arquivo;
    if (titulo.isEmpty || arq == null) {
      setState(() => _erro = 'Informe o título e escolha o arquivo.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await CertificadosService.adicionar(
        idProfissional: widget.idProfissional,
        idGrupoEmpresa: widget.idGrupoEmpresa,
        titulo: titulo,
        dataEmissao: _data,
        bytes: await arq.readAsBytes(),
        extensao: arq.extension ?? 'jpg',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _enviando = false;
        _erro = 'Não foi possível salvar. Tente de novo.';
      });
      debugPrint('[certificados] salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Novo certificado',
              style: TextStyle(
                color: _texto,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _avisoAnexado(),
            TextField(
              controller: _titulo,
              maxLength: 120,
              cursorColor: _azul,
              decoration: InputDecoration(
                labelText: 'Título (ex.: NR-10, Curso de Elétrica)',
                floatingLabelStyle: const TextStyle(
                  color: _azul,
                  fontWeight: FontWeight.w600,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _azul, width: 1.6),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F5F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined, color: _azul),
              title: Text(
                d == null
                    ? 'Data de emissão'
                    : '${d.day.toString().padLeft(2, '0')}/'
                          '${d.month.toString().padLeft(2, '0')}/${d.year}',
              ),
              trailing: const Text(
                'Escolher',
                style: TextStyle(color: _azul, fontWeight: FontWeight.w700),
              ),
              onTap: _escolherData,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _arquivo?.extension?.toLowerCase() == 'pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: _azul,
              ),
              title: Text(
                _arquivo?.name ?? 'Imagem ou PDF do certificado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _arquivo == null ? 'Anexar' : 'Alterar',
                style: const TextStyle(
                  color: _azul,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _escolherArquivo,
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _erro!,
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _enviando ? null : _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  shape: const StadiumBorder(),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar certificado',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
