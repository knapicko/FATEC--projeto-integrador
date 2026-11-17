import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/home_cliente_service.dart';
import 'tela_servico.dart';
import 'utils/cor_oficio.dart';
import 'widgets/card_servico_popular.dart';
import 'widgets/filtros_busca.dart';
import 'widgets/skeleton_loading.dart';

/// Todos os serviços disponíveis, do mais bem avaliado para o menos, com
/// busca, ordenação e filtros.
class TodosServicosPage extends StatefulWidget {
  const TodosServicosPage({super.key});

  @override
  State<TodosServicosPage> createState() => _TodosServicosPageState();
}

enum _Ordem { avaliacao, menorPreco, maiorPreco, recentes }

extension on _Ordem {
  String get rotulo => switch (this) {
    _Ordem.avaliacao => 'Melhor avaliados',
    _Ordem.menorPreco => 'Menor preço',
    _Ordem.maiorPreco => 'Maior preço',
    _Ordem.recentes => 'Mais recentes',
  };
}

class _TodosServicosPageState extends State<TodosServicosPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _fundo = Color(0xFFF3F6FA);

  final _busca = TextEditingController();
  List<ServicoAvaliado> _todos = const [];
  bool _carregando = true;
  _Ordem _ordem = _Ordem.avaliacao;
  FiltrosBusca _filtros = const FiltrosBusca();
  List<OficioInfo> _funcoes = const [];
  final Map<String, String> _categoriaPorFuncao = {};

  @override
  void initState() {
    super.initState();
    _busca.addListener(() => setState(() {}));
    _carregar();
    carregarFuncoesFiltro().then((l) {
      if (!mounted) return;
      setState(() {
        _funcoes = l;
        for (final f in l) {
          if (f.categoria != null) {
            _categoriaPorFuncao[f.funcao.toLowerCase()] = f.categoria!;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final lista = await HomeClienteService.servicosPorAvaliacao();
    if (mounted) {
      setState(() {
        _todos = lista;
        _carregando = false;
      });
    }
  }

  String _norm(String t) => t
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  List<ServicoAvaliado> get _visiveis {
    final termo = _norm(_busca.text.trim());
    final lista = _todos.where((i) {
      final s = i.servico;
      if (termo.isNotEmpty) {
        final campos = [s.titulo, s.descricao, s.funcao ?? ''].map(_norm);
        if (!campos.any((c) => c.contains(termo))) return false;
      }
      return _filtros.aceitaServico(
        funcao: s.funcao,
        tipoExecucao: s.tipoExecucao,
        preco: s.valor,
        ehLoja: s.fkGrupoEmpresa != null,
        idProfissional: s.fkProfissional,
        idGrupoEmpresa: s.fkGrupoEmpresa,
        categoriaDaFuncao: (f) => _categoriaPorFuncao[f],
      );
    }).toList();
    switch (_ordem) {
      case _Ordem.avaliacao:
        break; // já vem ordenado
      case _Ordem.menorPreco:
        lista.sort((a, b) => a.servico.valor.compareTo(b.servico.valor));
      case _Ordem.maiorPreco:
        lista.sort((a, b) => b.servico.valor.compareTo(a.servico.valor));
      case _Ordem.recentes:
        lista.sort(
          (a, b) => b.servico.dataCriacao.compareTo(a.servico.dataCriacao),
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
            'Todos os serviços',
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
                        hintText: 'Buscar serviço',
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
                        SkeletonBox(height: 280, borderRadius: 22),
                        SizedBox(height: 18),
                        SkeletonBox(height: 280, borderRadius: 22),
                      ],
                    )
                  : lista.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nenhum serviço encontrado com esses filtros.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: _azul,
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: lista.length,
                        itemBuilder: (_, i) => CardServicoPopular(
                          item: lista[i],
                          aoTocar: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TelaServico(idServico: lista[i].servico.id),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
