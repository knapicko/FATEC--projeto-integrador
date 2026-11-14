import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'services/lista_servicos_service.dart';
import 'services/servicos_profissional_service.dart';
import 'meus_enderecos.dart';
import 'utils/fluxo_solicitacao.dart';
import 'widgets/skeleton_loading.dart';
import 'utils/funcao_servico.dart';

class EnderecoItemLista {
  final int idEndereco;
  final String apelido;
  final String tipoEndereco;
  final String enderecoFormatado;
  final bool principal;

  const EnderecoItemLista({
    required this.idEndereco,
    required this.apelido,
    required this.tipoEndereco,
    required this.enderecoFormatado,
    required this.principal,
  });
}

class ItemServicoLista {
  final int fkLista;
  final int fkServicoProf;
  final double valorFinal;
  final String tipoExecucao;
  final int? fkEnderecoEscolhido;
  final String? detalhes;
  final List<String> imagensAnexadasCliente;
  final String dataAgendada;
  final String horaAgendada;
  final String horaAgendadaFim;
  final String titulo;
  final String? imagemUrl;
  final String? funcao;
  final String? tagEmpresa;
  final bool ehLoja;
  final String tipoPrestador; // 'empresa' | 'independente' | 'cpf'
  final int? idGrupoEmpresa;
  final int? idProfissional;
  final String nomePrestador;
  final String? fotoPrestador;
  final String enderecoPrestador;

  bool get ehEmpresa => tipoPrestador == 'empresa' || ehLoja;
  bool get ehIndependente => tipoPrestador == 'independente';
  bool get ehCpf => tipoPrestador == 'cpf';

  String get rotuloTipoPrestador {
    if (ehEmpresa) return 'Loja / Empresa';
    if (ehIndependente) return 'Independente (CNPJ)';
    return 'Autônomo (CPF)';
  }

  ItemServicoLista({
    required this.fkLista,
    required this.fkServicoProf,
    required this.valorFinal,
    required this.tipoExecucao,
    this.fkEnderecoEscolhido,
    this.detalhes,
    this.imagensAnexadasCliente = const [],
    required this.dataAgendada,
    required this.horaAgendada,
    required this.horaAgendadaFim,
    required this.titulo,
    this.imagemUrl,
    this.funcao,
    this.tagEmpresa,
    required this.ehLoja,
    this.tipoPrestador = 'cpf',
    this.idGrupoEmpresa,
    this.idProfissional,
    required this.nomePrestador,
    this.fotoPrestador,
    required this.enderecoPrestador,
  });
}

class ListaServicos extends StatefulWidget {
  final int? idUsuario;

  const ListaServicos({super.key, this.idUsuario});

  @override
  State<ListaServicos> createState() => _ListaServicosState();
}

class _ListaServicosState extends State<ListaServicos> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _bgFundo = Color(0xFFF1F5F9);
  static const Color _textoEscuro = Color(0xFF0F172A);
  static const Color _textoMuted = Color(0xFF64748B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _enviandoSolicitacao = false;
  int? _idLista;
  int? _idUsuarioResolvido;
  String _enderecoUsuario = 'Carregando endereço...';
  List<EnderecoItemLista> _enderecosUsuario = [];
  List<ItemServicoLista> _itens = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final user = _supabase.auth.currentUser;
      int? idUsuario = widget.idUsuario;

      if (idUsuario == null && user != null) {
        final usuarioRow = await _supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', user.id)
            .maybeSingle();
        idUsuario = (usuarioRow?['id_usuario'] as num?)?.toInt();
      }

      if (idUsuario == null) {
        setState(() => _carregando = false);
        return;
      }

      // 1. Carrega endereço completo do cliente
      await _carregarEnderecoCliente(idUsuario);

      // 2. Busca lista de serviços do cliente
      final listaRow = await _supabase
          .from('lista_servicos')
          .select('id_lista')
          .eq('fk_usuario', idUsuario)
          .order('id_lista', ascending: false)
          .limit(1)
          .maybeSingle();

      if (listaRow == null) {
        setState(() {
          _itens = [];
          _carregando = false;
        });
        ListaServicosService.instance.atualizar();
        return;
      }

      _idLista = (listaRow['id_lista'] as num).toInt();

      // 3. Busca serviços adicionados em ass_servicos_lista
      final assRows = await _supabase
          .from('ass_servicos_lista')
          .select('*, servicos_profissional(*, $kSelectFuncao)')
          .eq('fk_lista', _idLista!)
          .order('data_criacao', ascending: false);

      final List<ItemServicoLista> listaMontada = [];

      for (final row in assRows) {
        final fkLista = (row['fk_lista'] as num).toInt();
        final fkServicoProf = (row['fk_servico_prof'] as num).toInt();
        final valorFinal =
            double.tryParse(row['valor_final']?.toString() ?? '0') ?? 0.0;
        final tipoExecucao = normalizarTipoExecucao(
          row['tipo_execucao_escolhido']?.toString(),
        );
        final fkEndereco = (row['fk_endereco_escolhido'] as num?)?.toInt();
        final detalhes = row['detalhes']?.toString();
        final imagensAnexadasCliente = row['imagens_anexadas_cliente'] is List
            ? List<String>.from(
                (row['imagens_anexadas_cliente'] as List).map(
                  (item) => item.toString(),
                ),
              )
            : <String>[];
        final dataAgendada = row['data_agendada']?.toString() ?? '';
        final horaAgendada = row['hora_agendada']?.toString() ?? '';
        final horaAgendadaFim = row['hora_agendada_fim']?.toString() ?? '';

        final servicoMap =
            row['servicos_profissional'] as Map<String, dynamic>?;
        final titulo = servicoMap?['titulo']?.toString() ?? 'Conserto';
        final imagemUrl = servicoMap?['imagem_url']?.toString();
        final idProfissional = (servicoMap?['fk_profissional'] as num?)
            ?.toInt();
        final idGrupoEmpresa = (servicoMap?['fk_grupo_empresa'] as num?)
            ?.toInt();

        // Ofício / Função
        String? funcao;
        final oficioMap = servicoMap?['funcoes'] as Map<String, dynamic>?;
        if (oficioMap != null && oficioMap['funcao'] != null) {
          funcao = oficioMap['funcao']?.toString();
        }

        // Busca dados do prestador (detalhe público)
        String nomePrestador = 'Caedss';
        String? fotoPrestador;
        String enderecoPrestador =
            'Travessa Doutor Eduardo Maffei, 87, Casa 3,...';
        String? tagEmpresa;
        bool ehLoja = idGrupoEmpresa != null;
        String tipoPrestador = ehLoja ? 'empresa' : 'cpf';

        try {
          final detalhePublico =
              await ServicosProfissionalService.buscarDetalhePublico(
                fkServicoProf,
              );
          if (detalhePublico != null) {
            nomePrestador = detalhePublico.nomePrestador;
            fotoPrestador = detalhePublico.fotoPrestador;
            enderecoPrestador = detalhePublico.enderecoFormatado;
            tagEmpresa = detalhePublico.tagEmpresa;
            ehLoja = detalhePublico.ehLoja;
            tipoPrestador = detalhePublico.tipoPrestador;
          }
        } catch (_) {}

        listaMontada.add(
          ItemServicoLista(
            fkLista: fkLista,
            fkServicoProf: fkServicoProf,
            valorFinal: valorFinal,
            tipoExecucao: tipoExecucao,
            fkEnderecoEscolhido: fkEndereco,
            detalhes: detalhes,
            imagensAnexadasCliente: imagensAnexadasCliente,
            dataAgendada: dataAgendada,
            horaAgendada: horaAgendada,
            horaAgendadaFim: horaAgendadaFim,
            titulo: titulo,
            imagemUrl: imagemUrl,
            funcao: funcao ?? 'Geral',
            tagEmpresa: tagEmpresa,
            ehLoja: ehLoja,
            tipoPrestador: tipoPrestador,
            idGrupoEmpresa: idGrupoEmpresa,
            idProfissional: idProfissional,
            nomePrestador: nomePrestador,
            fotoPrestador: fotoPrestador,
            enderecoPrestador: enderecoPrestador,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _itens = listaMontada;
          _carregando = false;
        });
      }

      // Atualiza o serviço global da barra de serviços
      ListaServicosService.instance.atualizar();
    } catch (e) {
      debugPrint('Erro ao carregar lista de serviços: $e');
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _definirEnderecoAtivo(int idEndereco) async {
    if (_idUsuarioResolvido == null) return;
    try {
      await _supabase
          .from('ass_usuario_endereco')
          .update({'endereco_ativo': false})
          .eq('fk_usuario', _idUsuarioResolvido!);

      await _supabase
          .from('ass_usuario_endereco')
          .update({'endereco_ativo': true})
          .eq('fk_usuario', _idUsuarioResolvido!)
          .eq('fk_endereco', idEndereco);

      await _carregarEnderecoCliente(_idUsuarioResolvido!);
    } catch (e) {
      debugPrint('Erro ao definir endereco ativo: $e');
    }
  }

  Future<void> _carregarEnderecoCliente([int? idUsuario]) async {
    final resolvedId = idUsuario ?? _idUsuarioResolvido;
    if (resolvedId == null) return;
    _idUsuarioResolvido = resolvedId;
    try {
      final assResponse = await _supabase
          .from('ass_usuario_endereco')
          .select(
            'fk_endereco, apelido_endereco, tipo_endereco, endereco_ativo',
          )
          .eq('fk_usuario', resolvedId);

      if (assResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _enderecoUsuario = 'Cadastre um endereço';
            _enderecosUsuario = [];
          });
        }
        return;
      }

      final idsEnderecos = assResponse
          .map((a) => (a['fk_endereco'] as num?)?.toInt())
          .whereType<int>()
          .toList();

      if (idsEnderecos.isEmpty) {
        if (mounted) {
          setState(() {
            _enderecoUsuario = 'Cadastre um endereço';
            _enderecosUsuario = [];
          });
        }
        return;
      }

      final enderecosResponse = await _supabase
          .from('enderecos')
          .select(
            'id_endereco, logradouro, numero, bairro, complemento, fk_cidade',
          )
          .inFilter('id_endereco', idsEnderecos);

      final cidadesResponse = await _supabase
          .from('cidades')
          .select('id_cidade, nome_cidade, fk_estado');

      final estadosResponse = await _supabase
          .from('estados')
          .select('id_estado, sigla_estado');

      final Map<int, Map<String, dynamic>> cidadesMap = {};
      for (final cidade in cidadesResponse) {
        final id = (cidade['id_cidade'] as num?)?.toInt();
        if (id != null) cidadesMap[id] = Map<String, dynamic>.from(cidade);
      }

      final Map<int, String> estadosMap = {};
      for (final estado in estadosResponse) {
        final id = (estado['id_estado'] as num?)?.toInt();
        if (id != null)
          estadosMap[id] = estado['sigla_estado']?.toString() ?? '';
      }

      final listaEnd = <EnderecoItemLista>[];
      String? enderecoAtivoTexto;

      for (final ass in assResponse) {
        final idEnd = (ass['fk_endereco'] as num?)?.toInt();
        if (idEnd == null) continue;

        final endRow = enderecosResponse.firstWhere(
          (r) => (r['id_endereco'] as num?)?.toInt() == idEnd,
          orElse: () => const {},
        );

        final logradouro = endRow['logradouro']?.toString().trim() ?? '';
        final numero = endRow['numero']?.toString().trim() ?? '';
        final bairro = endRow['bairro']?.toString().trim() ?? '';
        final idCidade = (endRow['fk_cidade'] as num?)?.toInt();

        final cidadeInfo = idCidade != null ? cidadesMap[idCidade] : null;
        final nomeCidade = cidadeInfo?['nome_cidade']?.toString().trim() ?? '';
        final idEstado = (cidadeInfo?['fk_estado'] as num?)?.toInt();
        final siglaEstado = idEstado != null
            ? (estadosMap[idEstado] ?? '')
            : '';

        var formatado = '';
        if (logradouro.isNotEmpty) {
          formatado = numero.isNotEmpty ? '$logradouro, $numero' : logradouro;
          if (bairro.isNotEmpty) formatado += ' - $bairro';
          if (nomeCidade.isNotEmpty) formatado += ', $nomeCidade';
          if (siglaEstado.isNotEmpty) formatado += ' - $siglaEstado';
        } else if (nomeCidade.isNotEmpty) {
          formatado = siglaEstado.isNotEmpty
              ? '$nomeCidade - $siglaEstado'
              : nomeCidade;
        } else {
          formatado = 'Endereço #$idEnd';
        }

        final ativo = ass['endereco_ativo'] == true;
        final apelido = ass['apelido_endereco']?.toString().trim() ?? '';
        final tipo = ass['tipo_endereco']?.toString().trim() ?? 'Residencial';

        if (ativo) {
          enderecoAtivoTexto = formatado;
        }

        listaEnd.add(
          EnderecoItemLista(
            idEndereco: idEnd,
            apelido: apelido.isNotEmpty ? apelido : tipo,
            tipoEndereco: tipo,
            enderecoFormatado: formatado,
            principal: ativo,
          ),
        );
      }

      listaEnd.sort((a, b) => b.principal ? 1 : (a.principal ? -1 : 0));
      enderecoAtivoTexto ??= listaEnd.isNotEmpty
          ? listaEnd.first.enderecoFormatado
          : 'Nenhum endereço selecionado';

      if (mounted) {
        setState(() {
          _enderecosUsuario = listaEnd;
          _enderecoUsuario = enderecoAtivoTexto!;
        });
      }
      return;
    } catch (e) {
      debugPrint('Erro ao carregar enderecos do cliente: $e');
    }
  }

  Future<void> _carregarEnderecoClienteLegado(int idUsuario) async {
    try {
      final assResponse = await _supabase
          .from('ass_usuario_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_usuario', idUsuario)
          .eq('endereco_ativo', true)
          .limit(1);

      int? idEndereco;
      if (assResponse.isNotEmpty) {
        idEndereco = (assResponse.first['fk_endereco'] as num?)?.toInt();
      }

      if (idEndereco != null) {
        final endRow = await _supabase
            .from('enderecos')
            .select('logradouro, numero, bairro, fk_cidade')
            .eq('id_endereco', idEndereco)
            .maybeSingle();

        final logradouro = endRow?['logradouro']?.toString().trim() ?? '';
        final numero = endRow?['numero']?.toString().trim() ?? '';
        final idCidade = (endRow?['fk_cidade'] as num?)?.toInt();

        String cidadeEstado = 'Novo Horizonte - SP';
        if (idCidade != null) {
          final cidRow = await _supabase
              .from('cidades')
              .select('nome_cidade, fk_estado')
              .eq('id_cidade', idCidade)
              .maybeSingle();
          final nomeCidade = cidRow?['nome_cidade']?.toString() ?? '';
          final idEstado = (cidRow?['fk_estado'] as num?)?.toInt();

          String siglaEstado = 'SP';
          if (idEstado != null) {
            final estRow = await _supabase
                .from('estados')
                .select('sigla_estado')
                .eq('id_estado', idEstado)
                .maybeSingle();
            siglaEstado = estRow?['sigla_estado']?.toString() ?? 'SP';
          }

          if (nomeCidade.isNotEmpty) {
            cidadeEstado = '$nomeCidade - $siglaEstado';
          }
        }

        if (logradouro.isNotEmpty) {
          final ruaNumero = numero.isNotEmpty
              ? '$logradouro, $numero'
              : logradouro;
          _enderecoUsuario = '$ruaNumero - $cidadeEstado';
        } else {
          _enderecoUsuario = cidadeEstado;
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar endereco cliente: $e');
    }
  }

  Future<void> _abrirBottomSheetRemoverItem(ItemServicoLista item) async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrasto
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Ícone de lixeira em destaque vermelho
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Remover serviço da lista?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Deseja remover "${item.titulo}" da sua lista de serviços?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _textoMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Card de prévia do serviço
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child:
                            item.imagemUrl != null &&
                                (item.imagemUrl!.startsWith('http://') ||
                                    item.imagemUrl!.startsWith('https://'))
                            ? Image.network(
                                item.imagemUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _placeholderServico(),
                              )
                            : _placeholderServico(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _textoEscuro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.nomePrestador,
                            style: const TextStyle(
                              color: _textoMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatarPreco(item.valorFinal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _azul,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Remover',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmar != true) return;

    try {
      await _supabase
          .from('ass_servicos_lista')
          .delete()
          .eq('fk_lista', item.fkLista)
          .eq('fk_servico_prof', item.fkServicoProf);

      setState(() {
        _itens.removeWhere(
          (element) =>
              element.fkLista == item.fkLista &&
              element.fkServicoProf == item.fkServicoProf,
        );
      });

      // Atualiza a barra global
      ListaServicosService.instance.atualizar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serviço removido da lista.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirModalMetodosSelecionados() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Métodos de Execução Escolhidos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Os serviços da sua lista possuem os seguintes métodos de atendimento:',
                style: TextStyle(color: _textoMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _itens.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, i) {
                    final item = _itens[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _obterIconeMetodo(item.tipoExecucao),
                          color: _azul,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        item.tipoExecucao,
                        style: const TextStyle(
                          color: _azul,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _obterIconeMetodo(String tipo) {
    final limpo = tipo.trim().toLowerCase();
    if (limpo.contains('leva') || limpo.contains('traz')) {
      return Icons.local_shipping_outlined;
    } else if (limpo.contains('retirad') || limpo.contains('local')) {
      return Icons.storefront_outlined;
    } else if (limpo.contains('receba') || limpo.contains('casa')) {
      return Icons.home_outlined;
    } else if (limpo.contains('domic')) {
      return Icons.home_repair_service_outlined;
    }
    return Icons.local_shipping_outlined;
  }

  String _formatarDataHora(String dataStr, String horaStr) {
    if (dataStr.isEmpty) return '25 de junho - 13:00';
    try {
      final partesData = dataStr.split('-');
      if (partesData.length == 3) {
        final dia = int.tryParse(partesData[2]) ?? 25;
        final mesNum = int.tryParse(partesData[1]) ?? 6;
        const meses = [
          'janeiro',
          'fevereiro',
          'março',
          'abril',
          'maio',
          'junho',
          'julho',
          'agosto',
          'setembro',
          'outubro',
          'novembro',
          'dezembro',
        ];
        final mesNome = (mesNum >= 1 && mesNum <= 12)
            ? meses[mesNum - 1]
            : 'junho';

        String horaFormatada = '13:00';
        if (horaStr.isNotEmpty) {
          final partesHora = horaStr.split(':');
          if (partesHora.length >= 2) {
            horaFormatada = '${partesHora[0]}:${partesHora[1]}';
          }
        }
        return '$dia de $mesNome - $horaFormatada';
      }
    } catch (_) {}
    return '$dataStr - $horaStr';
  }

  // ── Envio das solicitações (botão Continuar) ─────────────────────────────
  // Para cada item em `ass_servicos_lista`, cria UMA linha em `solicitacoes`
  // com os dados do serviço, depois apaga os itens da lista.
  Future<void> _enviarSolicitacoes() async {
    if (_itens.isEmpty || _enviandoSolicitacao) return;
    setState(() => _enviandoSolicitacao = true);
    try {
      final user = _supabase.auth.currentUser;
      int? idUsuario = widget.idUsuario;
      if (idUsuario == null && user != null) {
        final usuarioRow = await _supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', user.id)
            .maybeSingle();
        idUsuario = (usuarioRow?['id_usuario'] as num?)?.toInt();
      }
      if (idUsuario == null) {
        throw Exception('Não foi possível identificar o usuário logado.');
      }

      final statusRows = await _supabase
          .from('status')
          .select('id_status, status')
          .eq('tipo_status', 'Serviço')
          .inFilter('status', [
            'Aberto',
            'Aguardando Profissional',
            'Pendente',
            'Novo',
          ]);
      const statusInicialPreferido = [
        'Aberto',
        'Aguardando Profissional',
        'Pendente',
        'Novo',
      ];
      final statusRow = statusRows.cast<Map<String, dynamic>>().firstWhere(
        (row) => statusInicialPreferido.contains(row['status']?.toString()),
        orElse: () => <String, dynamic>{},
      );
      final idStatus = (statusRow['id_status'] as num?)?.toInt();
      if (idStatus == null) {
        throw Exception(
          'Status inicial do serviço não encontrado. Cadastre Aberto, Aguardando Profissional ou Pendente na tabela status.',
        );
      }

      final solicitacoes = _itens.map((item) {
        return <String, dynamic>{
          'data_solicitacao': DateTime.now().toUtc().toIso8601String(),
          'valor_final': item.valorFinal,
          'fk_usuario': idUsuario,
          'fk_profissional': item.idProfissional,
          'fk_status': idStatus,
          'fk_servico_prof': item.fkServicoProf,
          'fk_endereco': item.fkEnderecoEscolhido,
          'fk_grupo_empresa': item.idGrupoEmpresa,
          'tipo_execucao': normalizarTipoExecucao(item.tipoExecucao),
          'detalhes': item.detalhes,
          'data_agendada': item.dataAgendada.isNotEmpty
              ? item.dataAgendada
              : null,
          'hora_agendada': item.horaAgendada.isNotEmpty
              ? item.horaAgendada
              : null,
          'hora_agendada_fim': item.horaAgendadaFim.isNotEmpty
              ? item.horaAgendadaFim
              : null,
          'imagens_anexadas_cliente': item.imagensAnexadasCliente,
        };
      }).toList();
      await _supabase.from('solicitacoes').insert(solicitacoes);

      if (_idLista != null) {
        await _supabase
            .from('ass_servicos_lista')
            .delete()
            .eq('fk_lista', _idLista!);
      }

      if (mounted) {
        setState(() {
          _itens = [];
          _enviandoSolicitacao = false;
        });
      }
      ListaServicosService.instance.atualizar();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      // A home é a primeira rota; o sheet é exibido sobre ela.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _exibirSheetSolicitacaoEnviada();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoSolicitacao = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exibirSheetSolicitacaoEnviada() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _azul.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _azul,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Solicitação enviada!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Foi enviada uma solicitação de serviço ao profissional e você deve aguardar o profissional responder.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _textoMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatarPreco(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  double get _totalGeral {
    return _itens.fold(0.0, (soma, item) => soma + item.valorFinal);
  }

  List<String> get _metodosUnicos {
    return _itens
        .map((i) => i.tipoExecucao.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final count = _itens.length;
    final totalFormatado = _formatarPreco(_totalGeral);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgFundo,
        body: Column(
          children: [
            _buildHeader(count),
            Expanded(
              child: _carregando
                  ? const SkeletonPage(layout: SkeletonLayout.cards)
                  : _itens.isEmpty
                  ? _buildListaVazia()
                  : RefreshIndicator(
                      color: _azul,
                      onRefresh: _carregarDados,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _itens.length,
                        itemBuilder: (context, index) {
                          return _buildCardServico(_itens[index]);
                        },
                      ),
                    ),
            ),
            if (!_carregando && _itens.isNotEmpty)
              _buildBarraInferior(count, totalFormatado),
          ],
        ),
      ),
    );
  }

  // ── 1. Cabeçalho Superior ──────────────────────────────────────────────────
  Widget _buildHeader(int count) {
    return Container(
      color: _azul,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  Text(
                    'Lista de Serviços ($count)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: _buildSeletorEndereco(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2. Card do Serviço (Design Fiel ao Print com Lixeira Vermelha) ──────────
  Widget _buildCardServico(ItemServicoLista item) {
    final tagEmpresa = item.tagEmpresa?.trim();
    final ehLoja = item.ehLoja;
    final temTagEmpresa = ehLoja && tagEmpresa != null && tagEmpresa.isNotEmpty;
    final tagEmpresaFormatada = temTagEmpresa
        ? (tagEmpresa.startsWith('#') ? tagEmpresa : '#$tagEmpresa')
        : '#CAEDS';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Card: Fornecedor + Endereço + Lixeira Vermelha (no lugar da seta)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
            child: Row(
              children: [
                // Ao tocar no avatar e nome, navega para o perfil
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (item.ehLoja && item.idGrupoEmpresa != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerfilLoja(
                              idGrupoEmpresa: item.idGrupoEmpresa,
                              nomeEmpresa: item.nomePrestador,
                              fotoUrlEmpresa: item.fotoPrestador,
                              tagEmpresa: item.tagEmpresa,
                            ),
                          ),
                        );
                      } else if (item.idProfissional != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerfilProfissionalPage(
                              nomeInicial: item.nomePrestador,
                              imagemInicial: item.fotoPrestador ?? '',
                              profissao: item.funcao ?? 'Profissional',
                              idGrupoEmpresa: item.idGrupoEmpresa,
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        _buildAvatarPrestador(item),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Fornecido por ',
                                    style: TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      item.nomePrestador,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _azul,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.verified,
                                    color: _azul,
                                    size: 15,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _buildBadgeTipoPrestador(item.tipoPrestador),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.enderecoPrestador,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _textoMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
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

                // Ícone de lixeira vermelho destacado (substituindo a seta >)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 24,
                  ),
                  tooltip: 'Remover serviço',
                  splashRadius: 22,
                  onPressed: () => _abrirBottomSheetRemoverItem(item),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Corpo do Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem quadrada do serviço
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child:
                        item.imagemUrl != null &&
                            (item.imagemUrl!.startsWith('http://') ||
                                item.imagemUrl!.startsWith('https://'))
                        ? Image.network(
                            item.imagemUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholderServico(),
                          )
                        : _placeholderServico(),
                  ),
                ),
                const SizedBox(height: 12),

                // Nome do Serviço
                Text(
                  item.titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textoEscuro,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Tags de Empresa e Função
                Row(
                  children: [
                    if (temTagEmpresa || ehLoja) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tagEmpresaFormatada,
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (item.funcao != null && item.funcao!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.funcao!,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Data Agendada - Hora Agendada e Preço
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatarDataHora(item.dataAgendada, item.horaAgendada),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatarPreco(item.valorFinal),
                      style: const TextStyle(
                        color: _textoEscuro,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 12),

                // Formas de Pagamento
                Row(
                  children: [
                    const Text(
                      'Formas de Pagamento',
                      style: TextStyle(
                        color: _azul,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Símbolo Pix (losango inclinado)
                    Transform.rotate(
                      angle: 0.785,
                      child: const Icon(
                        Icons.crop_square_rounded,
                        size: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.credit_card_outlined,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 17,
                      color: Color(0xFF475569),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Prazo e Método de Execução com ícone dinâmico
                Row(
                  children: [
                    const Text(
                      'Entregue em até 5 dias - ',
                      style: TextStyle(
                        color: _textoMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      item.tipoExecucao,
                      style: const TextStyle(
                        color: _azul,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _obterIconeMetodo(item.tipoExecucao),
                      color: _azul,
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPrestador(ItemServicoLista item) {
    if (item.fotoPrestador != null &&
        (item.fotoPrestador!.startsWith('http://') ||
            item.fotoPrestador!.startsWith('https://'))) {
      return CircleAvatar(
        radius: 21,
        backgroundColor: const Color(0xFFE2E8F0),
        backgroundImage: NetworkImage(item.fotoPrestador!),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _azul,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
      ),
      child: Center(
        child: Text(
          item.nomePrestador.isNotEmpty
              ? item.nomePrestador.substring(0, 1).toUpperCase()
              : 'P',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _placeholderServico() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.home_repair_service_rounded,
          color: Color(0xFF94A3B8),
          size: 40,
        ),
      ),
    );
  }

  // ── 3. Barra Inferior de Finalização / Checkout ────────────────────────────
  Widget _buildBarraInferior(int count, String totalFormatado) {
    final metodos = _metodosUnicos;
    final temVariosMetodos = metodos.length > 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produtos ($count): $totalFormatado',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Método: ',
                          style: TextStyle(
                            color: _azul,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (temVariosMetodos)
                          InkWell(
                            onTap: _abrirModalMetodosSelecionados,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'vários',
                                    style: TextStyle(
                                      color: _azul,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _azul,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${metodos.isNotEmpty ? metodos.first : "Retirada"} ',
                                style: const TextStyle(
                                  color: _azul,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Icon(
                                _obterIconeMetodo(
                                  metodos.isNotEmpty
                                      ? metodos.first
                                      : "Retirada",
                                ),
                                color: _azul,
                                size: 17,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                Text(
                  'Total: $totalFormatado',
                  style: const TextStyle(
                    color: _textoEscuro,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _enviandoSolicitacao ? null : _enviarSolicitacoes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _enviandoSolicitacao
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continuar ($count)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaVazia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sua lista de serviços está vazia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textoEscuro,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione serviços para agendar e contratar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textoMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTipoPrestador(String tipo) {
    final tipoNormalizado = tipo.trim().toLowerCase();
    Color bg;
    Color borda;
    Color texto;
    IconData icone;
    String rotulo;

    if (tipoNormalizado == 'empresa' || tipoNormalizado == 'loja') {
      bg = const Color(0xFFEFF6FF);
      borda = const Color(0xFF93C5FD);
      texto = const Color(0xFF1D4ED8);
      icone = Icons.storefront_outlined;
      rotulo = 'Empresa';
    } else if (tipoNormalizado == 'independente' || tipoNormalizado == 'cnpj') {
      bg = const Color(0xFFECFDF5);
      borda = const Color(0xFFA7F3D0);
      texto = const Color(0xFF047857);
      icone = Icons.business_center_outlined;
      rotulo = 'Independente';
    } else {
      bg = const Color(0xFFF1F5F9);
      borda = const Color(0xFFCBD5E1);
      texto = const Color(0xFF475569);
      icone = Icons.person_outline;
      rotulo = 'AutÃ´nomo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borda, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 11, color: texto),
          const SizedBox(width: 3),
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: texto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeletorEndereco() {
    final conteudo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on_outlined, color: Colors.white, size: 19),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _enderecoUsuario,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
      ],
    );

    if (_enderecosUsuario.isEmpty) {
      return GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MeusEnderecosPage(isVisitante: false),
            ),
          );
          await _carregarEnderecoCliente();
        },
        child: conteudo,
      );
    }

    return PopupMenuButton<int>(
      tooltip: 'Selecionar endereÃ§o',
      offset: const Offset(0, 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (idEndereco) async {
        if (idEndereco == -1) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MeusEnderecosPage(isVisitante: false),
            ),
          );
          await _carregarEnderecoCliente();
        } else {
          await _definirEnderecoAtivo(idEndereco);
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<int>> items = [];

        for (final end in _enderecosUsuario) {
          items.add(
            PopupMenuItem<int>(
              value: end.idEndereco,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Row(
                  children: [
                    Icon(
                      end.principal ? Icons.location_on : Icons.place_outlined,
                      size: 18,
                      color: end.principal ? _azul : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            end.enderecoFormatado,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            end.tipoEndereco,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (end.principal) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, color: _azul, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        items.add(const PopupMenuDivider());
        items.add(
          PopupMenuItem<int>(
            value: -1,
            child: Row(
              children: const [
                Icon(Icons.add_location_alt_outlined, color: _azul, size: 18),
                SizedBox(width: 8),
                Text(
                  'Gerenciar endereÃ§os',
                  style: TextStyle(
                    color: _azul,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );

        return items;
      },
      child: conteudo,
    );
  }
}
