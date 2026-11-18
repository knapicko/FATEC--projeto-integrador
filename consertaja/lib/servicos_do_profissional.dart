import 'package:flutter/material.dart';

import 'models/servico_profissional.dart';
import 'services/home_cliente_service.dart';
import 'tela_servico.dart';
import 'utils/cor_oficio.dart';
import 'utils/texto_busca.dart';
import 'widgets/card_servico_popular.dart';
import 'widgets/filtros_busca.dart';

/// Todos os serviços de um profissional/loja, com busca, ordenação e
/// filtros (aberto pelo "Ver todos" do perfil).
class ServicosDoProfissionalPage extends StatefulWidget {
  const ServicosDoProfissionalPage({
    super.key,
    required this.servicos,
    required this.nome,
  });

  final List<ServicoProfissional> servicos;
  final String nome;

  @override
  State<ServicosDoProfissionalPage> createState() =>
      _ServicosDoProfissionalPageState();
}

enum _Ordem { recentes, menorPreco, maiorPreco, nome }

extension on _Ordem {
  String get rotulo => switch (this) {
    _Ordem.recentes => 'Mais recentes',
    _Ordem.menorPreco => 'Menor preço',
    _Ordem.maiorPreco => 'Maior preço',
    _Ordem.nome => 'A–Z',
  };
}

class _ServicosDoProfissionalPageState
    extends State<ServicosDoProfissionalPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _fundo = Color(0xFFF3F6FA);

  final _busca = TextEditingController();
  _Ordem _ordem = _Ordem.recentes;
  FiltrosBusca _filtros = const FiltrosBusca();
  List<OficioInfo> _funcoes = const [];
  final Map<String, String> _categoriaPorFuncao = {};

  @override
  void initState() {
    super.initState();
    _busca.addListener(() => setState(() {}));
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

  List<ServicoProfissional> get _visiveis {
    final lista = widget.servicos.where((s) {
      if (!textoContem([s.titulo, s.descricao, s.funcao ?? ''], _busca.text)) {
        return false;
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
      case _Ordem.recentes:
        lista.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
      case _Ordem.menorPreco:
        lista.sort((a, b) => a.valor.compareTo(b.valor));
      case _Ordem.maiorPreco:
        lista.sort((a, b) => b.valor.compareTo(a.valor));
      case _Ordem.nome:
        lista.sort(
          (a, b) =>
              normalizarBusca(a.titulo).compareTo(normalizarBusca(b.titulo)),
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
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: _fundo,
        surfaceTintColor: _fundo,
        elevation: 0,
        title: Text(
          'Serviços de ${widget.nome}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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
                    decoration: InputDecoration(
                      hintText: 'Buscar serviço',
                      prefixIcon: const Icon(Icons.search_rounded),
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
            child: lista.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum serviço encontrado.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: lista.length,
                    itemBuilder: (_, i) => CardServicoPopular(
                      item: ServicoAvaliado(servico: lista[i]),
                      aoTocar: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TelaServico(
                            idServico: lista[i].id,
                            servicoInicial: lista[i],
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
