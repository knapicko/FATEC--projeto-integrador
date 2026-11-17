import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/home_cliente_service.dart';
import 'utils/cor_oficio.dart';
import 'utils/texto_busca.dart';
import 'widgets/card_profissional_vitrine.dart';
import 'widgets/filtros_busca.dart';
import 'widgets/skeleton_loading.dart';

/// Todos os profissionais independentes e lojas cadastrados, com busca,
/// ordenação e filtros (igual a "Todos os serviços").
class TodosProfissionaisPage extends StatefulWidget {
  const TodosProfissionaisPage({super.key});

  @override
  State<TodosProfissionaisPage> createState() => _TodosProfissionaisPageState();
}

enum _Ordem { avaliacao, nome, novos, disponiveis }

extension on _Ordem {
  String get rotulo => switch (this) {
    _Ordem.avaliacao => 'Melhor avaliados',
    _Ordem.nome => 'A–Z',
    _Ordem.novos => 'Mais novos',
    _Ordem.disponiveis => 'Disponíveis hoje',
  };
}

class _TodosProfissionaisPageState extends State<TodosProfissionaisPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _fundo = Color(0xFFF3F6FA);

  final _busca = TextEditingController();
  List<ProfissionalVitrine> _todos = const [];
  bool _carregando = true;
  _Ordem _ordem = _Ordem.avaliacao;
  FiltrosBusca _filtros = const FiltrosBusca();
  List<OficioInfo> _funcoes = const [];

  @override
  void initState() {
    super.initState();
    _busca.addListener(() => setState(() {}));
    _carregar();
    carregarFuncoesFiltro().then((l) {
      if (mounted) setState(() => _funcoes = l);
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final lista = await HomeClienteService.todosProfissionais();
    if (mounted) {
      setState(() {
        _todos = lista;
        _carregando = false;
      });
    }
  }

  List<ProfissionalVitrine> get _visiveis {
    final termo = _busca.text;
    final lista = _todos.where((p) {
      if (!textoContem([
        p.nome,
        p.tagEmpresa ?? '',
        ...p.funcoes.map((f) => f.funcao),
        ...p.funcoes.map((f) => f.categoria ?? ''),
      ], termo)) {
        return false;
      }
      return _filtros.aceitaProfissional(
        oficios: p.funcoes,
        ehLoja: p.ehEmpresa,
        idProfissional: p.idProfissional,
        idGrupoEmpresa: p.idGrupoEmpresa,
        nota: p.nota ?? 5,
      );
    }).toList();
    switch (_ordem) {
      case _Ordem.avaliacao:
        lista.sort((a, b) => (b.nota ?? 5).compareTo(a.nota ?? 5));
      case _Ordem.nome:
        lista.sort(
          (a, b) => normalizarBusca(a.nome).compareTo(normalizarBusca(b.nome)),
        );
      case _Ordem.novos:
        lista.sort(
          (a, b) => (b.criadoEm ?? DateTime(2000)).compareTo(
            a.criadoEm ?? DateTime(2000),
          ),
        );
      case _Ordem.disponiveis:
        lista.sort(
          (a, b) => (b.disponivelHoje ? 1 : 0) - (a.disponivelHoje ? 1 : 0),
        );
    }
    return lista;
  }

  Future<void> _abrirFiltros() async {
    final novos = await mostrarFiltrosBusca(
      context,
      atuais: _filtros,
      funcoesDisponiveis: _funcoes,
    );
    if (novos != null && mounted) setState(() => _filtros = novos);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _visiveis;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _fundo,
        appBar: AppBar(
          backgroundColor: _fundo,
          surfaceTintColor: _fundo,
          elevation: 0,
          title: const Text(
            'Profissionais',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busca,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar profissional, loja ou função',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _busca.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _busca.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Badge(
                    isLabelVisible: _filtros.ativo,
                    label: Text('${_filtros.quantidadeAtivos}'),
                    child: Material(
                      color: _azul,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _abrirFiltros,
                        child: const SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(Icons.tune_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _Ordem.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final o = _Ordem.values[i];
                  final ativo = o == _ordem;
                  return ChoiceChip(
                    label: Text(o.rotulo),
                    selected: ativo,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _ordem = o),
                    selectedColor: _azul,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: ativo ? Colors.white : const Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _carregando
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: const [
                        SkeletonBox(height: 236, borderRadius: 22),
                        SizedBox(height: 14),
                        SkeletonBox(height: 236, borderRadius: 22),
                      ],
                    )
                  : lista.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nenhum profissional encontrado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: _azul,
                      onRefresh: _carregar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) =>
                            CardProfissionalVitrine(p: lista[i], largura: null),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
