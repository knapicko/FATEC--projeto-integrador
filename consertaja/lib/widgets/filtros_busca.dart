import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/cor_oficio.dart';
import '../utils/funcao_servico.dart';
import 'tag_oficio.dart';
import '../utils/texto_busca.dart';

/// Métodos de realização existentes (mesmo texto de solicitacoes.tipo_execucao).
const kMetodosRealizacao = [
  'Leva e Traz',
  'Retirado no Local',
  'Receba em Casa',
  'Atendimento em Domicílio',
];

enum OrdemBusca { relevancia, menorPreco, maiorPreco, melhorAvaliados }

extension OrdemBuscaTexto on OrdemBusca {
  String get rotulo => switch (this) {
    OrdemBusca.relevancia => 'Relevância',
    OrdemBusca.menorPreco => 'Menor preço',
    OrdemBusca.maiorPreco => 'Maior preço',
    OrdemBusca.melhorAvaliados => 'Melhor avaliados',
  };
}

/// Profissional (ou loja) escolhido para ver só as coisas dele.
class ProfissionalFiltro {
  const ProfissionalFiltro({
    required this.nome,
    this.idProfissional,
    this.idGrupoEmpresa,
    this.foto,
    this.funcoes = const [],
  });

  final String nome;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final String? foto;
  final List<OficioInfo> funcoes;

  bool get ehLoja => idGrupoEmpresa != null;
}

/// Filtros da busca (tela de busca, resultados e "todos os serviços").
class FiltrosBusca {
  const FiltrosBusca({
    this.categoria,
    this.funcoes = const {},
    this.independente = true,
    this.loja = true,
    this.profissional,
    this.metodos = const {},
    this.precoMaximo,
    this.notaMinima,
    this.ordem = OrdemBusca.relevancia,
  });

  /// Categoria do ofício (chips da tela de busca / categorias da home).
  final String? categoria;
  final Set<String> funcoes;
  final bool independente;
  final bool loja;
  final ProfissionalFiltro? profissional;
  final Set<String> metodos;
  final double? precoMaximo;
  final double? notaMinima;
  final OrdemBusca ordem;

  int get quantidadeAtivos =>
      (categoria != null ? 1 : 0) +
      funcoes.length +
      (independente && loja ? 0 : 1) +
      (profissional != null ? 1 : 0) +
      metodos.length +
      (precoMaximo != null ? 1 : 0) +
      (notaMinima != null ? 1 : 0) +
      (ordem != OrdemBusca.relevancia ? 1 : 0);

  bool get ativo => quantidadeAtivos > 0;

  FiltrosBusca copiar({
    Object? categoria = _manter,
    Set<String>? funcoes,
    bool? independente,
    bool? loja,
    Object? profissional = _manter,
    Set<String>? metodos,
    Object? precoMaximo = _manter,
    Object? notaMinima = _manter,
    OrdemBusca? ordem,
  }) {
    return FiltrosBusca(
      categoria: identical(categoria, _manter)
          ? this.categoria
          : categoria as String?,
      funcoes: funcoes ?? this.funcoes,
      independente: independente ?? this.independente,
      loja: loja ?? this.loja,
      profissional: identical(profissional, _manter)
          ? this.profissional
          : profissional as ProfissionalFiltro?,
      metodos: metodos ?? this.metodos,
      precoMaximo: identical(precoMaximo, _manter)
          ? this.precoMaximo
          : precoMaximo as double?,
      notaMinima: identical(notaMinima, _manter)
          ? this.notaMinima
          : notaMinima as double?,
      ordem: ordem ?? this.ordem,
    );
  }

  /// O serviço passa nos filtros? [categoriaDaFuncao] traduz função →
  /// categoria do ofício.
  bool aceitaServico({
    required String? funcao,
    required String tipoExecucao,
    required double preco,
    required bool ehLoja,
    required int idProfissional,
    required int? idGrupoEmpresa,
    String? Function(String funcao)? categoriaDaFuncao,
  }) {
    final f = (funcao ?? '').trim().toLowerCase();
    if (categoria != null) {
      final cat = categoriaDaFuncao?.call(f)?.toLowerCase();
      if (cat != categoria!.toLowerCase() && f != categoria!.toLowerCase()) {
        return false;
      }
    }
    if (funcoes.isNotEmpty && !funcoes.any((x) => x.toLowerCase() == f)) {
      return false;
    }
    if (ehLoja && !loja) return false;
    if (!ehLoja && !independente) return false;
    final p = profissional;
    if (p != null) {
      final mesmo = p.ehLoja
          ? idGrupoEmpresa == p.idGrupoEmpresa
          : idProfissional == p.idProfissional;
      if (!mesmo) return false;
    }
    if (metodos.isNotEmpty) {
      final t = tipoExecucao.toLowerCase();
      if (!metodos.any((m) => t.contains(m.toLowerCase()))) return false;
    }
    if (precoMaximo != null && preco > precoMaximo!) return false;
    return true;
  }

  bool aceitaProfissional({
    required List<OficioInfo> oficios,
    required bool ehLoja,
    required int? idProfissional,
    required int? idGrupoEmpresa,
    required double? nota,
  }) {
    if (categoria != null &&
        !oficios.any(
          (o) =>
              (o.categoria ?? '').toLowerCase() == categoria!.toLowerCase() ||
              o.funcao.toLowerCase() == categoria!.toLowerCase(),
        )) {
      return false;
    }
    if (funcoes.isNotEmpty &&
        !oficios.any(
          (o) => funcoes.any((x) => x.toLowerCase() == o.funcao.toLowerCase()),
        )) {
      return false;
    }
    if (ehLoja && !loja) return false;
    if (!ehLoja && !independente) return false;
    final p = profissional;
    if (p != null) {
      final mesmo = p.ehLoja
          ? idGrupoEmpresa == p.idGrupoEmpresa
          : idProfissional == p.idProfissional;
      if (!mesmo) return false;
    }
    if (notaMinima != null && (nota ?? 0) < notaMinima!) return false;
    return true;
  }
}

const Object _manter = Object();

/// Abre o bottom sheet de filtros e devolve os filtros escolhidos (ou null).
Future<FiltrosBusca?> mostrarFiltrosBusca(
  BuildContext context, {
  required FiltrosBusca atuais,
  List<OficioInfo> funcoesDisponiveis = const [],
}) {
  return showModalBottomSheet<FiltrosBusca>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FiltrosSheet(atuais: atuais, funcoes: funcoesDisponiveis),
  );
}

/// Carrega as funções (com categoria e cor) para os filtros.
Future<List<OficioInfo>> carregarFuncoesFiltro() async {
  try {
    final rows = await Supabase.instance.client
        .from('funcoes')
        .select(kColunasFuncaoComoOficio)
        .order('funcao');
    final vistas = <String>{};
    final lista = [
      for (final r in rows)
        if (OficioInfo.fromMap(r) case final o
            when o.funcao.isNotEmpty && vistas.add(o.funcao.toLowerCase()))
          o,
    ];
    // Agrupadas por ofício (categoria) e, dentro dele, por nome.
    lista.sort((a, b) {
      final c = (a.categoria ?? '').compareTo(b.categoria ?? '');
      return c != 0 ? c : a.funcao.compareTo(b.funcao);
    });
    return lista;
  } catch (_) {
    return const [];
  }
}

class _FiltrosSheet extends StatefulWidget {
  const _FiltrosSheet({required this.atuais, required this.funcoes});

  final FiltrosBusca atuais;
  final List<OficioInfo> funcoes;

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);
  static const _campo = Color(0xFFF3F5F8);

  late FiltrosBusca _f = widget.atuais;
  late List<OficioInfo> _funcoes = widget.funcoes;
  final _nome = TextEditingController();
  Timer? _debounce;
  List<ProfissionalFiltro> _sugestoes = [];
  bool _buscandoNome = false;

  @override
  void initState() {
    super.initState();
    if (_funcoes.isEmpty) {
      carregarFuncoesFiltro().then((l) {
        if (mounted) setState(() => _funcoes = l);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nome.dispose();
    super.dispose();
  }

  void _aoDigitarNome(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _buscarSugestoes(texto.trim());
    });
  }

  /// Profissionais (independentes) e lojas cujo nome contém o texto, com
  /// foto e as funções.
  Future<void> _buscarSugestoes(String texto) async {
    if (texto.length < 2) {
      setState(() => _sugestoes = []);
      return;
    }
    setState(() => _buscandoNome = true);
    final db = Supabase.instance.client;
    final lista = <ProfissionalFiltro>[];
    try {
      // Sem acento / maiúsculas: filtra no app.
      final usuarios =
          (await db
                  .from('usuarios')
                  .select('id_usuario, nome, foto_perfil_url')
                  .eq('tipo_conta', 'Profissional'))
              .where((u) => textoContem([u['nome']?.toString() ?? ''], texto))
              .take(6)
              .toList();
      final idsUsuario = [
        for (final u in usuarios) (u['id_usuario'] as num).toInt(),
      ];
      final dados = idsUsuario.isEmpty
          ? const <Map<String, dynamic>>[]
          : await db
                .from('dados_profissionais')
                .select('id_profissional, fk_usuario, fk_grupo_empresa')
                .inFilter('fk_usuario', idsUsuario);
      final profPorUsuario = <int, int>{
        for (final d in dados)
          if (d['fk_grupo_empresa'] == null)
            (d['fk_usuario'] as num).toInt(): (d['id_profissional'] as num)
                .toInt(),
      };
      final funcoesPorProf = <int, List<OficioInfo>>{};
      if (profPorUsuario.isNotEmpty) {
        final ass = await db
            .from('ass_oficio_profissional')
            .select('fk_profissional, $kSelectFuncao')
            .inFilter('fk_profissional', profPorUsuario.values.toList());
        for (final a in ass) {
          final f = extrairFuncao(a);
          if (f == null) continue;
          funcoesPorProf
              .putIfAbsent((a['fk_profissional'] as num).toInt(), () => [])
              .add(OficioInfo.fromMap(f));
        }
      }
      for (final u in usuarios) {
        final idProf = profPorUsuario[(u['id_usuario'] as num).toInt()];
        if (idProf == null) continue;
        lista.add(
          ProfissionalFiltro(
            nome: u['nome']?.toString() ?? '',
            idProfissional: idProf,
            foto: u['foto_perfil_url']?.toString(),
            funcoes: funcoesPorProf[idProf] ?? const [],
          ),
        );
      }
      final lojas =
          (await db
                  .from('grupo_empresa')
                  .select('id_grupo_empresa, nome_empresa, foto_url_empresa'))
              .where(
                (l) =>
                    textoContem([l['nome_empresa']?.toString() ?? ''], texto),
              )
              .take(4)
              .toList();
      for (final l in lojas) {
        lista.add(
          ProfissionalFiltro(
            nome: l['nome_empresa']?.toString() ?? 'Loja',
            idGrupoEmpresa: (l['id_grupo_empresa'] as num).toInt(),
            foto: l['foto_url_empresa']?.toString(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[filtros] sugestões: $e');
    }
    if (mounted) {
      setState(() {
        _sugestoes = lista;
        _buscandoNome = false;
      });
    }
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Text(
      t,
      style: const TextStyle(
        color: _texto,
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  /// [cor]: cor do ofício (funções) — fundo claro na cor e, selecionado,
  /// a cor cheia.
  Widget _chip(String texto, bool ativo, VoidCallback aoTocar, {Color? cor}) {
    final base = cor ?? _azul;
    final fundo = ativo
        ? (cor == null ? _azul : CorOficio.corTexto(base))
        : (cor == null ? _campo : base.withValues(alpha: 0.22));
    final letra = ativo
        ? Colors.white
        : (cor == null ? const Color(0xFF374151) : CorOficio.corTexto(base));
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: letra,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _caixa(String texto, bool marcado, ValueChanged<bool> mudar) =>
      InkWell(
        onTap: () => mudar(!marcado),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: marcado ? _azul : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: marcado ? _azul : const Color(0xFFCBD5E1),
                    width: 1.6,
                  ),
                ),
                child: marcado
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                texto,
                style: const TextStyle(color: _texto, fontSize: 14.5),
              ),
            ],
          ),
        ),
      );

  Widget _avatar(ProfissionalFiltro p, {double r = 20}) {
    final foto = p.foto ?? '';
    final temFoto = foto.startsWith('http');
    return CircleAvatar(
      radius: r,
      backgroundColor: _azul,
      backgroundImage: temFoto ? NetworkImage(foto) : null,
      child: temFoto
          ? null
          : Icon(
              p.ehLoja ? Icons.storefront_rounded : Icons.person_rounded,
              color: Colors.white,
              size: r,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height * 0.88;
    final p = _f.profissional;
    return Container(
      height: altura,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtros',
                    style: TextStyle(
                      color: _texto,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _f = const FiltrosBusca()),
                  child: const Text('Limpar tudo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                _titulo('Ordenar por'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in OrdemBusca.values)
                      _chip(
                        o.rotulo,
                        _f.ordem == o,
                        () => setState(() => _f = _f.copiar(ordem: o)),
                      ),
                  ],
                ),

                _titulo('Funções'),
                if (_funcoes.isEmpty)
                  const Text('Carregando…', style: TextStyle(color: _sec))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in _funcoes)
                        _chip(o.funcao, _f.funcoes.contains(o.funcao), () {
                          final novo = {..._f.funcoes};
                          if (!novo.remove(o.funcao)) novo.add(o.funcao);
                          setState(() => _f = _f.copiar(funcoes: novo));
                        }, cor: CorOficio.parse(o.cor)),
                    ],
                  ),

                _titulo('Profissionais'),
                _caixa(
                  'Independente',
                  _f.independente,
                  (v) => setState(() => _f = _f.copiar(independente: v)),
                ),
                _caixa(
                  'Loja',
                  _f.loja,
                  (v) => setState(() => _f = _f.copiar(loja: v)),
                ),
                const SizedBox(height: 10),
                if (p != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F6FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _avatar(p),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Só de ${p.nome}',
                            style: const TextStyle(
                              color: _texto,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _f = _f.copiar(profissional: null),
                          ),
                          icon: const Icon(Icons.close_rounded, color: _sec),
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextField(
                    controller: _nome,
                    onChanged: _aoDigitarNome,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Nome de um profissional ou loja',
                      prefixIcon: const Icon(Icons.person_search_rounded),
                      suffixIcon: _buscandoNome
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: _campo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  for (final s in _sugestoes)
                    InkWell(
                      onTap: () => setState(() {
                        _f = _f.copiar(profissional: s);
                        _sugestoes = [];
                        _nome.clear();
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            _avatar(s),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.nome,
                                    style: const TextStyle(
                                      color: _texto,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (s.ehLoja)
                                    const Text(
                                      'Loja',
                                      style: TextStyle(
                                        color: _sec,
                                        fontSize: 12,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        for (final f in s.funcoes.take(3))
                                          TagOficio(
                                            oficio: f,
                                            fontSize: 10,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
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
                    ),
                ],

                _titulo('Serviços: método de realização'),
                for (final m in kMetodosRealizacao)
                  _caixa(m, _f.metodos.contains(m), (v) {
                    final novo = {..._f.metodos};
                    v ? novo.add(m) : novo.remove(m);
                    setState(() => _f = _f.copiar(metodos: novo));
                  }),

                _titulo('Preço máximo'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: (_f.precoMaximo ?? 1000).clamp(20, 1000),
                        min: 20,
                        max: 1000,
                        divisions: 49,
                        activeColor: _azul,
                        onChanged: (v) => setState(
                          () =>
                              _f = _f.copiar(precoMaximo: v >= 1000 ? null : v),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 86,
                      child: Text(
                        _f.precoMaximo == null
                            ? 'Sem limite'
                            : 'R\$ ${_f.precoMaximo!.round()}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: _texto,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                _titulo('Avaliação mínima do profissional'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in const [null, 3.0, 4.0, 4.5])
                      _chip(
                        n == null ? 'Qualquer' : '★ $n+',
                        _f.notaMinima == n,
                        () => setState(() => _f = _f.copiar(notaMinima: n)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _f),
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _f.ativo
                        ? 'Aplicar filtros (${_f.quantidadeAtivos})'
                        : 'Aplicar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
