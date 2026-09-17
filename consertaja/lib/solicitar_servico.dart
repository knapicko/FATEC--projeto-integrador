import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';

class SolicitarServicoPage extends StatefulWidget {
  final int idProfissional;
  final List<ServicoProfissional> servicos;

  const SolicitarServicoPage({
    super.key,
    required this.idProfissional,
    required this.servicos,
  });

  @override
  State<SolicitarServicoPage> createState() => _SolicitarServicoPageState();
}

class _SolicitarServicoPageState extends State<SolicitarServicoPage> {
  static const _azulEscuro = Color(0xFF003F87);
  static const _texto = Color(0xFF1D2A39);
  static const _borda = Color(0xFFE2E8F0);

  final _supabase = Supabase.instance.client;
  final _detalhesController = TextEditingController();
  final _picker = ImagePicker();

  int? _idUsuario;
  ServicoProfissional? _servicoSelecionado;
  _EnderecoCliente? _enderecoSelecionado;
  String? _tipoEntrega;
  XFile? _imagem;
  DateTime? _dataSelecionada;
  bool _carregando = true;
  bool _enviando = false;
  String? _erro;

  List<ServicoProfissional> _servicos = [];
  List<_EnderecoCliente> _enderecos = [];
  Set<DateTime> _diasDisponiveis = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _detalhesController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      _servicos = widget.servicos.isNotEmpty
          ? List<ServicoProfissional>.from(widget.servicos)
          : await ServicosProfissionalService.buscarServicos(
              idProfissional: widget.idProfissional,
            );
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Faça login para solicitar um serviço.');

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      _idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (_idUsuario == null) throw Exception('Não foi possível localizar seu cadastro.');

      final vinculos = await _supabase
          .from('ass_usuario_endereco')
          .select('fk_endereco, apelido_endereco, tipo_endereco')
          .eq('fk_usuario', _idUsuario!)
          .eq('endereco_ativo', true);

      final enderecos = <_EnderecoCliente>[];
      for (final vinculo in vinculos) {
        final id = (vinculo['fk_endereco'] as num?)?.toInt();
        if (id == null) continue;
        final endereco = await _supabase
            .from('enderecos')
            .select('logradouro, numero, complemento, bairro, cep, fk_cidade')
            .eq('id_endereco', id)
            .maybeSingle();
        if (endereco == null) continue;
        final cidadeId = (endereco['fk_cidade'] as num?)?.toInt();
        final cidade = cidadeId == null
            ? null
            : await _supabase
                  .from('cidades')
                  .select('nome_cidade, fk_estado')
                  .eq('id_cidade', cidadeId)
                  .maybeSingle();
        final estadoId = (cidade?['fk_estado'] as num?)?.toInt();
        final estado = estadoId == null
            ? null
            : await _supabase
                  .from('estados')
                  .select('sigla_estado')
                  .eq('id_estado', estadoId)
                  .maybeSingle();
        enderecos.add(
          _EnderecoCliente(
            id: id,
            titulo: (vinculo['apelido_endereco'] ??
                    vinculo['tipo_endereco'] ??
                    'Endereço')
                .toString(),
            descricao: _formatarEndereco(endereco, cidade, estado),
          ),
        );
      }

      _enderecos = enderecos;
      await _carregarDiasDisponiveis();
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _formatarEndereco(
    Map<String, dynamic> endereco,
    Map<String, dynamic>? cidade,
    Map<String, dynamic>? estado,
  ) {
    final linha = '${endereco['logradouro']}, ${endereco['numero']}';
    final bairro = endereco['bairro']?.toString().trim() ?? '';
    final cidadeNome = cidade?['nome_cidade']?.toString().trim() ?? '';
    final sigla = estado?['sigla_estado']?.toString().trim() ?? '';
    final local = [
      if (bairro.isNotEmpty) bairro,
      if (cidadeNome.isNotEmpty) '$cidadeNome${sigla.isEmpty ? '' : ' - $sigla'}',
    ].join(', ');
    return local.isEmpty ? linha : '$linha, $local';
  }

  Future<void> _carregarDiasDisponiveis() async {
    List<Map<String, dynamic>> agendas = [];
    try {
      final response = await _supabase
          .from('agenda_profissional')
          .select('dias_semana, hora_ini, hora_fim')
          .eq('fk_profissional', widget.idProfissional)
          .eq('fk_solicitacao', 0);
      agendas = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      final response = await _supabase
          .from('agenda_profissional')
          .select('dias_semana, hora_ini, hora_fim')
          .eq('fk_profissional', widget.idProfissional);
      agendas = List<Map<String, dynamic>>.from(response);
    }

    final diasDaSemana = <int>{};
    for (final agenda in agendas) {
      final texto = _semAcentos(agenda['dias_semana']?.toString() ?? '');
      for (var dia = 1; dia <= 7; dia++) {
        if (_contemDia(texto, dia)) diasDaSemana.add(dia);
      }
    }

    final hoje = _semHora(DateTime.now());
    final limite = hoje.add(const Duration(days: 90));
    final excecoes = await _supabase
        .from('grade_horario_excecao')
        .select('dia_semana, hora_ini, hora_fim')
        .eq('fk_profissional', widget.idProfissional)
        .gte('dia_semana', _dataSql(hoje))
        .lte('dia_semana', _dataSql(limite));
    final bloqueados = <String>{};
    for (final excecao in excecoes) {
      if (excecao['hora_ini'] == null || excecao['hora_fim'] == null) {
        bloqueados.add(excecao['dia_semana'].toString().substring(0, 10));
      }
    }

    final disponiveis = <DateTime>{};
    for (var data = hoje;
        !data.isAfter(limite);
        data = data.add(const Duration(days: 1))) {
      if (diasDaSemana.contains(data.weekday) &&
          !bloqueados.contains(_dataSql(data))) {
        disponiveis.add(data);
      }
    }
    if (mounted) setState(() => _diasDisponiveis = disponiveis);
  }

  String _semAcentos(String valor) => valor
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u');

  bool _contemDia(String texto, int dia) {
    const nomes = [
      'segunda',
      'terca',
      'quarta',
      'quinta',
      'sexta',
      'sabado',
      'domingo',
    ];
    return texto.contains(nomes[dia - 1]);
  }

  DateTime _semHora(DateTime data) => DateTime(data.year, data.month, data.day);

  String _dataSql(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

  Future<void> _selecionarImagem() async {
    final imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (imagem != null && mounted) setState(() => _imagem = imagem);
  }

  Future<void> _enviarSolicitacao() async {
    if (_idUsuario == null || _servicoSelecionado == null ||
        _enderecoSelecionado == null || _tipoEntrega == null ||
        _dataSelecionada == null) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final resposta = await _supabase
          .from('solicitacoes')
          .insert({
            'data_solicitacao': DateTime.now().toUtc().toIso8601String(),
            'fk_usuario': _idUsuario,
            'fk_profissional': widget.idProfissional,
            'fk_grupo_empresa': _servicoSelecionado!.fkGrupoEmpresa,
            'fk_status': 1,
            'fk_servico_prof': _servicoSelecionado!.id,
            'fk_endereco': _enderecoSelecionado!.id,
            'tipo_execucao': _servicoSelecionado!.tipoExecucao,
            'tipo_entrega': _tipoEntrega,
            'detalhes': _detalhesController.text.trim().isEmpty
                ? null
                : _detalhesController.text.trim(),
            'data_agendada': _dataSql(_dataSelecionada!),
          })
          .select('id_solicitacao')
          .single();
      final idSolicitacao = (resposta['id_solicitacao'] as num).toInt();

      if (_imagem != null) {
        final bytes = await _imagem!.readAsBytes();
        final caminho = 'solicitacao/$idSolicitacao/${_imagem!.name}';
        final bucket = _supabase.storage.from('Imagens Servico');
        await bucket.uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(
            contentType: _imagem!.mimeType ?? 'image/jpeg',
            upsert: true,
          ),
        );
        await _supabase.from('solicitacoes_anexos').insert({
          'fk_solicitacao': idSolicitacao,
          'anexo_url': bucket.getPublicUrl(caminho),
          'nome_arquivo': _imagem!.name,
          'tipo_mime': _imagem!.mimeType ?? 'image/jpeg',
          'tamanho_bytes': bytes.length,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitação enviada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = 'Não foi possível enviar a solicitação: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        top: false,
        child: _carregando
            ? const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                children: [
                  _buildCabecalhoSheet(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildServicos(),
                          _buildEnderecos(),
                          _buildEntrega(),
                          _buildDetalhes(),
                          _buildAgenda(),
                          if (_erro != null) _mensagemErro(),
                        ],
                      ),
                    ),
                  ),
                  _buildRodape(),
                ],
              ),
      ),
    );
  }

  Widget _buildCabecalhoSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borda)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Solicitar serviço',
              style: TextStyle(
                color: _texto,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: _texto),
          ),
        ],
      ),
    );
  }

  Widget _buildServicos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Escolha o serviço que deseja solicitar',
          style: TextStyle(color: _texto, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_servicos.isEmpty)
          const Text('Este profissional ainda não cadastrou serviços.'),
        ..._servicos.map((servico) {
          final selecionado = _servicoSelecionado?.id == servico.id;
          return _ItemSelecao(
            selecionado: selecionado,
            titulo: servico.titulo,
            subtitulo:
                '${servico.funcao ?? 'Serviço'} • ${servico.tipoExecucao} • Carga ${servico.cargaServico}',
            valor: 'R\$ ${servico.valor.toStringAsFixed(2).replaceAll('.', ',')}',
            onTap: () => setState(() {
              _servicoSelecionado = servico;
              _tipoEntrega = servico.tipoExecucao == 'Execução' ? 'Local' : null;
            }),
          );
        }),
        if (_erro != null) _mensagemErro(),
      ],
    );
  }

  Widget _buildEnderecos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Escolha o local do serviço',
            style: TextStyle(color: _texto, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_enderecos.isEmpty)
          const Text('Cadastre um endereço antes de solicitar o serviço.'),
        ..._enderecos.map(
          (endereco) => _ItemSelecao(
            selecionado: _enderecoSelecionado?.id == endereco.id,
            titulo: endereco.titulo,
            subtitulo: endereco.descricao,
            icone: Icons.location_on_outlined,
            onTap: () => setState(() => _enderecoSelecionado = endereco),
          ),
        ),
        if (_erro != null) _mensagemErro(),
      ],
    );
  }

  Widget _buildEntrega() {
    final entrega = _servicoSelecionado?.tipoExecucao == 'Entrega';
    final opcoes = entrega
        ? const [
            ('Domicilio', 'Receber no endereço escolhido', Icons.home_outlined),
            ('Retirada', 'Retirar no estabelecimento', Icons.store_outlined),
          ]
        : const [
            ('Local', 'Execução no endereço escolhido', Icons.build_outlined),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entrega
              ? 'Como deseja receber o serviço?'
              : 'Este serviço será executado no local.',
          style: const TextStyle(color: _texto, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...opcoes.map(
          (opcao) => _ItemSelecao(
            selecionado: _tipoEntrega == opcao.$1,
            titulo: opcao.$1 == 'Domicilio'
                ? 'Receber em casa'
                : opcao.$1 == 'Retirada'
                    ? 'Retirar no estabelecimento'
                    : 'Execução no local',
            subtitulo: opcao.$2,
            icone: opcao.$3,
            onTap: () => setState(() => _tipoEntrega = opcao.$1),
          ),
        ),
        if (_erro != null) _mensagemErro(),
      ],
    );
  }

  Widget _buildDetalhes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Descreva os detalhes do serviço (opcional)',
            style: TextStyle(color: _texto, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _detalhesController,
          maxLength: 500,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Conte o que precisa ser feito...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _selecionarImagem,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Anexar imagem'),
        ),
        if (_imagem != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImagemPreview(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: 'Remover anexo',
                    onPressed: () => setState(() => _imagem = null),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImagemPreview() {
    final imagem = _imagem;
    if (imagem == null) return const SizedBox.shrink();
    return FutureBuilder<List<int>>(
      future: imagem.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Image.memory(
          Uint8List.fromList(snapshot.data!),
          width: double.infinity,
          height: 190,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _buildAgenda() {
    final hoje = _semHora(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Escolha um dia disponível',
            style: TextStyle(color: _texto, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_diasDisponiveis.isEmpty)
          const Text('Este profissional não possui dias disponíveis nos próximos 90 dias.')
        else
          CalendarDatePicker(
            initialDate: _dataSelecionada ?? _diasDisponiveis.first,
            firstDate: hoje,
            lastDate: hoje.add(const Duration(days: 90)),
            selectableDayPredicate: (date) =>
                _diasDisponiveis.contains(_semHora(date)),
            onDateChanged: (date) => setState(() => _dataSelecionada = date),
          ),
        if (_dataSelecionada != null)
          Center(child: Text('Dia escolhido: ${_dataSql(_dataSelecionada!)}')),
        if (_erro != null) _mensagemErro(),
      ],
    );
  }

  Widget _mensagemErro() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_erro!, style: const TextStyle(color: Colors.red)),
      );

  Widget _buildRodape() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _enviando ? null : _enviarFormulario,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
              label: const Text('Solicitar Serviço'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulEscuro,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _enviarFormulario() {
    setState(() => _erro = null);
    if (_servicoSelecionado == null) {
      setState(() => _erro = 'Selecione um serviço para continuar.');
      return;
    }
    if (_enderecoSelecionado == null) {
      setState(() => _erro = 'Selecione um endereço para continuar.');
      return;
    }
    if (_tipoEntrega == null) {
      setState(() => _erro = 'Escolha como o serviço será realizado.');
      return;
    }
    if (_dataSelecionada == null) {
      setState(() => _erro = 'Escolha um dia disponível.');
      return;
    }
    _enviarSolicitacao();
  }
}

class _EnderecoCliente {
  final int id;
  final String titulo;
  final String descricao;

  const _EnderecoCliente({
    required this.id,
    required this.titulo,
    required this.descricao,
  });
}

class _ItemSelecao extends StatelessWidget {
  final bool selecionado;
  final String titulo;
  final String subtitulo;
  final String? valor;
  final IconData? icone;
  final VoidCallback onTap;

  const _ItemSelecao({
    required this.selecionado,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.valor,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionado ? const Color(0xFF0FB3FF) : const Color(0xFFE2E8F0),
          width: selecionado ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icone ?? Icons.home_repair_service_outlined,
          color: selecionado ? const Color(0xFF0FB3FF) : Colors.grey,
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitulo),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (valor != null)
              Text(valor!, style: const TextStyle(fontWeight: FontWeight.w700)),
            Icon(
              selecionado ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selecionado ? const Color(0xFF0FB3FF) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}