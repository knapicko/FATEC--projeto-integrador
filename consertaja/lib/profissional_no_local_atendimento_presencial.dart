import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gestao_equipe.dart';
import 'servico_concluido.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_profissional.dart';

class ProfissionalNoLocalAtendimentoPresencialPage extends StatefulWidget {
  final int idSolicitacao;
  final String codigoPedido;
  final String nomeCliente;
  final String? fotoCliente;
  final String nomeServico;
  final String enderecoPrincipal;
  final String enderecoComplementar;
  final bool isEmpresa;
  final int? idGrupoEmpresa;
  final String? fotoPerfilProfissional;
  final String? nomeProfissional;

  const ProfissionalNoLocalAtendimentoPresencialPage({
    super.key,
    required this.idSolicitacao,
    required this.codigoPedido,
    required this.nomeCliente,
    this.fotoCliente,
    required this.nomeServico,
    required this.enderecoPrincipal,
    required this.enderecoComplementar,
    this.isEmpresa = false,
    this.idGrupoEmpresa,
    this.fotoPerfilProfissional,
    this.nomeProfissional,
  });

  @override
  State<ProfissionalNoLocalAtendimentoPresencialPage> createState() =>
      _ProfissionalNoLocalAtendimentoPresencialPageState();
}

class _ProfissionalNoLocalAtendimentoPresencialPageState
    extends State<ProfissionalNoLocalAtendimentoPresencialPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _fundo = Color(0xFFF7F8FA);
  static const _texto = Color(0xFF253042);
  static const _muted = Color(0xFF687386);

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  Timer? _timer;
  Timer? _relogio;
  Timer? _statusPolling;
  DateTime? _inicio;
  int _segundos = 0;
  bool _pausado = false;
  bool _carregando = true;
  bool _salvando = false;
  bool _finalizado = false;
  bool _codigoValidado = false;
  String _codigoRecDev = '';
  final List<TextEditingController> _codigoControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  double _preco = 0;
  List<String> _antes = [];
  List<String> _depois = [];
  final List<XFile> _arquivosAntes = [];
  final List<XFile> _arquivosDepois = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _relogio?.cancel();
    _statusPolling?.cancel();
    for (final controller in _codigoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final row = await _supabase
          .from('solicitacoes')
          .select(
            'data_inicio_andamento, duracao_atendimento, andamento_pausado, '
            'profissional_finalizado_atendimento, valor_final, '
            'codigo_rec_dev, fk_status, '
            'imagens_atendimento_antes, imagens_atendimento_depois',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      _segundos = (row['duracao_atendimento'] as num?)?.toInt() ?? 0;
      _pausado = row['andamento_pausado'] == true;
      _finalizado = row['profissional_finalizado_atendimento'] == true;
      _codigoRecDev = row['codigo_rec_dev']?.toString().trim() ?? '';
      _preco = (row['valor_final'] as num?)?.toDouble() ?? 0;
      _inicio = DateTime.tryParse(
        row['data_inicio_andamento']?.toString() ?? '',
      );
      _antes = _lista(row['imagens_atendimento_antes']);
      _depois = _lista(row['imagens_atendimento_depois']);
      if ((row['fk_status'] as num?)?.toInt() == 6) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  ServicoConcluidoPage(idSolicitacao: widget.idSolicitacao),
            ),
          );
        }
        return;
      }
      _codigoValidado = _inicio != null;
      if (_codigoValidado) _iniciarRelogios();
      _statusPolling = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _verificarConclusaoCliente(),
      );
    } catch (e) {
      if (mounted) _mostrarErro('Não foi possível carregar o atendimento: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _verificarConclusaoCliente() async {
    if (!mounted) return;
    final row = await _supabase
        .from('solicitacoes')
        .select('fk_status')
        .eq('id_solicitacao', widget.idSolicitacao)
        .maybeSingle();
    if ((row?['fk_status'] as num?)?.toInt() != 6 || !mounted) return;
    _statusPolling?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            ServicoConcluidoPage(idSolicitacao: widget.idSolicitacao),
      ),
    );
  }

  List<String> _lista(dynamic value) => value is List
      ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : [];

  void _iniciarRelogios() {
    _timer?.cancel();
    _relogio?.cancel();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (!_pausado && !_finalizado) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _persistirTimer(),
      );
    }
  }

  int get _tempoAtual {
    if (_pausado || _inicio == null) return _segundos;
    return _segundos + DateTime.now().difference(_inicio!).inSeconds;
  }

  String _formatar(int total) {
    final min = (total ~/ 60).toString().padLeft(2, '0');
    final sec = (total % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _persistirTimer() async {
    if (_pausado || _inicio == null || _finalizado) return;
    final atual = _tempoAtual;
    _segundos = atual;
    _inicio = DateTime.now();
    await _supabase
        .from('solicitacoes')
        .update({
          'duracao_atendimento': atual,
          'data_inicio_andamento': _inicio!.toUtc().toIso8601String(),
        })
        .eq('id_solicitacao', widget.idSolicitacao);
  }

  Future<void> _alternarPausa() async {
    setState(() => _salvando = true);
    try {
      if (!_pausado) {
        _segundos = _tempoAtual;
        _pausado = true;
        _timer?.cancel();
        await _supabase
            .from('solicitacoes')
            .update({
              'duracao_atendimento': _segundos,
              'andamento_pausado': true,
            })
            .eq('id_solicitacao', widget.idSolicitacao);
      } else {
        _pausado = false;
        _inicio = DateTime.now();
        _iniciarRelogios();
        await _supabase
            .from('solicitacoes')
            .update({
              'andamento_pausado': false,
              'data_inicio_andamento': _inicio!.toUtc().toIso8601String(),
            })
            .eq('id_solicitacao', widget.idSolicitacao);
      }
    } catch (e) {
      _mostrarErro('Não foi possível alterar a pausa: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _validarCodigo() async {
    final informado = _codigoControllers.map((c) => c.text).join();
    if (informado.length != 4 || _codigoRecDev.isEmpty) {
      _mostrarErro('Informe os 4 dígitos do código mostrado ao cliente.');
      return;
    }
    if (informado != _codigoRecDev) {
      _mostrarErro('Código inválido. Confira o código com o cliente.');
      return;
    }
    setState(() => _salvando = true);
    try {
      _inicio = DateTime.now();
      _codigoValidado = true;
      await _supabase
          .from('solicitacoes')
          .update({
            'data_inicio_andamento': _inicio!.toUtc().toIso8601String(),
            'duracao_atendimento': 0,
            'andamento_pausado': false,
            // Domicílio: o status 34 permanece durante todo o atendimento,
            // sempre na etapa 3 ("No Local"). A conclusão (6 / etapa 4)
            // acontece quando o cliente confirma.
            'fk_status': 34,
            'etapa_solicitacao': 3,
          })
          .eq('id_solicitacao', widget.idSolicitacao);
      _iniciarRelogios();
    } catch (e) {
      _codigoValidado = false;
      _inicio = null;
      _mostrarErro('Não foi possível iniciar o atendimento: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _adicionarFoto(bool antes) async {
    final lista = antes ? _arquivosAntes : _arquivosDepois;
    if (lista.length >= 2) return;
    final foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (foto != null && mounted) setState(() => lista.add(foto));
  }

  Future<List<String>> _enviarFotos(List<XFile> fotos, String bucket) async {
    final urls = <String>[];
    for (final foto in fotos) {
      final nome =
          'solicitacao/${widget.idSolicitacao}/${DateTime.now().microsecondsSinceEpoch}_${foto.name}';
      await _supabase.storage.from(bucket).upload(nome, File(foto.path));
      urls.add(_supabase.storage.from(bucket).getPublicUrl(nome));
    }
    return urls;
  }

  Future<void> _salvarAntes() async {
    if (_arquivosAntes.isEmpty) return;
    setState(() => _salvando = true);
    try {
      final urls = await _enviarFotos(
        _arquivosAntes,
        'Imagens Atendimento Antes',
      );
      _antes = [..._antes, ...urls];
      await _supabase
          .from('solicitacoes')
          .update({'imagens_atendimento_antes': _antes})
          .eq('id_solicitacao', widget.idSolicitacao);
      _arquivosAntes.clear();
      if (mounted) setState(() {});
    } catch (e) {
      _mostrarErro('Não foi possível enviar as fotos de antes: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _finalizarProfissional() async {
    if (_depois.isEmpty && _arquivosDepois.isEmpty) return;
    setState(() => _salvando = true);
    try {
      final urls = await _enviarFotos(
        _arquivosDepois,
        'Imagens Atendimento Depois',
      );
      _depois = [..._depois, ...urls];
      _segundos = _tempoAtual;
      await _supabase
          .from('solicitacoes')
          .update({
            'imagens_atendimento_depois': _depois,
            'duracao_atendimento': _segundos,
            'andamento_pausado': true,
            'profissional_finalizado_atendimento': true,
          })
          .eq('id_solicitacao', widget.idSolicitacao);
      _finalizado = true;
      _pausado = true;
      _timer?.cancel();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atendimento enviado para confirmação do cliente.'),
          ),
        );
      }
    } catch (e) {
      _mostrarErro('Não foi possível finalizar o atendimento: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _abrirFinalizacao() async {
    if (_antes.isEmpty || _tempoAtual < 600 || _finalizado) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 42, height: 4, color: Colors.black12),
              ),
              const SizedBox(height: 18),
              const Text(
                'Fotos depois do serviço',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Adicione pelo menos uma foto para enviar o atendimento ao cliente.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              _fotoSlots(false, setSheetState),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _arquivosDepois.isEmpty || _salvando
                      ? null
                      : () async {
                          await _finalizarProfissional();
                          if (ctx.mounted && _finalizado) Navigator.pop(ctx);
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Finalizar serviço'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _fotoSlots(bool antes, [StateSetter? setSheetState]) {
    final salvas = antes ? _antes : _depois;
    final arquivos = antes ? _arquivosAntes : _arquivosDepois;
    return Row(
      children: List.generate(2, (index) {
        final temSalva = index < salvas.length;
        final temArquivo = index < arquivos.length;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 0 ? 8 : 0),
            child: GestureDetector(
              onTap: temSalva || temArquivo
                  ? null
                  : () async {
                      await _adicionarFoto(antes);
                      setSheetState?.call(() {});
                      if (mounted) setState(() {});
                    },
              child: Container(
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: temSalva
                    ? Image.network(salvas[index], fit: BoxFit.cover)
                    : temArquivo
                    ? Image.file(File(arquivos[index].path), fit: BoxFit.cover)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: _azul),
                          SizedBox(height: 5),
                          Text(
                            'Adicionar',
                            style: TextStyle(
                              color: _azul,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _mostrarErro(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.isEmpresa
            ? const GestaoEquipePage()
            : const TelaMeuPerfilProfissionalPage(isVisitante: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final podeFinalizar =
        _antes.isNotEmpty && _tempoAtual >= 600 && !_finalizado;
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: _texto),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atendimento Em Andamento',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _texto,
              ),
            ),
            Text(
              widget.codigoPedido,
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'SOS',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _abrirPerfil,
            icon: CircleAvatar(
              radius: 15,
              backgroundImage: widget.fotoPerfilProfissional?.isNotEmpty == true
                  ? NetworkImage(widget.fotoPerfilProfissional!)
                  : null,
              child: widget.fotoPerfilProfissional?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.person, size: 18),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
        children: [
          _etapas(),
          if (!_codigoValidado) _codigoAtendimento(),
          _cliente(),
          _tempo(),
          _fotos(),
          _valor(),
          _finalizacao(podeFinalizar),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );

  Widget _etapas() => _card(
    Row(
      children: [
        for (final e in ['Aceito', 'A caminho', 'No Local', 'Concluído'])
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _azul,
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  e,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: _azul),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _codigoAtendimento() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONFIRMAÇÃO DE CHEGADA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _muted,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Digite o código mostrado no celular do cliente para iniciar o timer.',
          style: TextStyle(fontSize: 12, color: _texto),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            4,
            (index) => SizedBox(
              width: 48,
              child: TextField(
                controller: _codigoControllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 3) {
                    FocusScope.of(context).nextFocus();
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _salvando ? null : _validarCodigo,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Validar código e iniciar atendimento'),
          ),
        ),
      ],
    ),
  );

  Widget _cliente() => _card(
    Column(
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: _azul, size: 19),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${widget.enderecoPrincipal}\n${widget.enderecoComplementar}',
                style: const TextStyle(fontSize: 11, color: _texto),
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Check-in OK', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
        const Divider(height: 22),
        Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundImage: widget.fotoCliente?.isNotEmpty == true
                  ? NetworkImage(widget.fotoCliente!)
                  : null,
              child: widget.fotoCliente?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.person),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nomeCliente,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _texto,
                    ),
                  ),
                  Text(
                    widget.nomeServico,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaChatProfissional(
                nomeProfissional: widget.nomeCliente,
                fotoProfissional: widget.fotoCliente ?? '',
                oficioPrincipal: widget.nomeServico,
                idSolicitacao: widget.idSolicitacao,
              ),
            ),
          ),
          icon: const Icon(Icons.chat_outlined, size: 16),
          label: const Text('Chat com Cliente'),
        ),
      ],
    ),
  );

  Widget _tempo() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined, color: _azul),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'TEMPO DE ATENDIMENTO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _texto,
                ),
              ),
            ),
            Text(
              _formatar(_tempoAtual),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _azul,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: (_tempoAtual / 3600).clamp(0, 1).toDouble(),
          color: _azul,
          backgroundColor: Colors.black12,
        ),
        const SizedBox(height: 6),
        Text(
          _tempoAtual < 600
              ? 'Mínimo de 10 minutos para finalizar'
              : 'Tempo mínimo atingido',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    ),
  );

  Widget _fotos() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_camera_outlined, size: 19),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Fotos do Serviço (Antes / Depois)',
                style: TextStyle(fontWeight: FontWeight.w800, color: _texto),
              ),
            ),
            Text(
              _antes.isEmpty
                  ? 'Obrigatório 1 foto'
                  : '${_antes.length} foto(s)',
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _fotoSlots(true),
        if (_arquivosAntes.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvarAntes,
              child: const Text('Salvar fotos de antes'),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _valor() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Valor do Atendimento',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 4),
        Text(
          'R\$ ${_preco.toStringAsFixed(2).replaceAll('.', ',')}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _azul,
          ),
        ),
      ],
    ),
  );

  Widget _finalizacao(bool podeFinalizar) => _card(
    Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: podeFinalizar ? _abrirFinalizacao : null,
            icon: Icon(_finalizado ? Icons.timer_outlined : Icons.lock_outline),
            label: Text(
              _finalizado
                  ? 'Aguardando cliente'
                  : 'Finalizar Serviço (Disponível em ${_formatar((600 - _tempoAtual).clamp(0, 600))})',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _finalizado ? const Color(0xFFF59E0B) : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _finalizado || _salvando ? null : _alternarPausa,
                icon: Icon(_pausado ? Icons.play_arrow : Icons.pause),
                label: Text(
                  _pausado ? 'Retomar Atendimento' : 'Pausar Atendimento',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.flag_outlined, color: Colors.red),
                label: const Text(
                  'Relatar Problema',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
