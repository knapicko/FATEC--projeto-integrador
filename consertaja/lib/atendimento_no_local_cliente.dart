import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'detalhes_pedido.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_cliente.dart';

class AtendimentoNoLocalClientePage extends StatefulWidget {
  final int idSolicitacao;

  const AtendimentoNoLocalClientePage({super.key, required this.idSolicitacao});

  @override
  State<AtendimentoNoLocalClientePage> createState() =>
      _AtendimentoNoLocalClientePageState();
}

class _AtendimentoNoLocalClientePageState
    extends State<AtendimentoNoLocalClientePage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF253042);
  static const _muted = Color(0xFF687386);
  final _db = Supabase.instance.client;

  bool _carregando = true;
  bool _confirmando = false;
  String _codigoPedido = '';
  String _nomeCliente = 'Cliente';
  String? _fotoCliente;
  String _nomeProfissional = 'Profissional';
  String? _fotoProfissional;
  String _titulo = 'Atendimento';
  String _endereco = 'Endereço do cliente';
  String _tipoPrestador = 'Independente';
  String _metodoPagamento = 'PIX Seguro';
  double _valor = 0;
  int _duracao = 0;
  DateTime? _inicio;
  bool _profissionalFinalizou = false;
  String _codigoRecDev = '';
  Timer? _polling;
  List<String> _antes = [];
  List<String> _depois = [];

  @override
  void initState() {
    super.initState();
    _carregar();
    // Mantém a tela sincronizada com o profissional: início do atendimento
    // (código validado) e finalização (profissional_finalizado_atendimento).
    _polling = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _atualizarEstado(),
    );
  }

  @override
  void dispose() {
    _polling?.cancel();
    super.dispose();
  }

  Future<void> _atualizarEstado() async {
    if (!mounted || _confirmando) return;
    try {
      final row = await _db
          .from('solicitacoes')
          .select(
            'fk_status, profissional_finalizado_atendimento, '
            'data_inicio_andamento, duracao_atendimento, '
            'imagens_atendimento_antes, imagens_atendimento_depois',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();
      if (row == null || !mounted) return;
      if ((row['fk_status'] as num?)?.toInt() == 6) {
        _polling?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                DetalhesPedidoPage(idSolicitacao: widget.idSolicitacao),
          ),
        );
        return;
      }
      setState(() {
        _profissionalFinalizou =
            row['profissional_finalizado_atendimento'] == true;
        _inicio = DateTime.tryParse(
          row['data_inicio_andamento']?.toString() ?? '',
        );
        _duracao = (row['duracao_atendimento'] as num?)?.toInt() ?? _duracao;
        _antes = _lista(row['imagens_atendimento_antes']);
        _depois = _lista(row['imagens_atendimento_depois']);
      });
    } catch (_) {}
  }

  List<String> _lista(dynamic value) => value is List
      ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : [];

  Future<void> _carregar() async {
    try {
      final row = await _db
          .from('solicitacoes')
          .select('*')
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      _codigoPedido =
          '#PED-2026-${widget.idSolicitacao.toString().padLeft(4, '0')}';
      _valor = (row['valor_final'] as num?)?.toDouble() ?? 0;
      _duracao = (row['duracao_atendimento'] as num?)?.toInt() ?? 0;
      _inicio = DateTime.tryParse(
        row['data_inicio_andamento']?.toString() ?? '',
      );
      _profissionalFinalizou =
          row['profissional_finalizado_atendimento'] == true;
      _codigoRecDev = row['codigo_rec_dev']?.toString().trim() ?? '';
      _antes = _lista(row['imagens_atendimento_antes']);
      _depois = _lista(row['imagens_atendimento_depois']);
      final fkGrupo = (row['fk_grupo_empresa'] as num?)?.toInt();
      final fkProf = (row['fk_profissional'] as num?)?.toInt();
      final fkUsuario = (row['fk_usuario'] as num?)?.toInt();
      final fkEndereco = (row['fk_endereco'] as num?)?.toInt();
      final fkServico = (row['fk_servico_prof'] as num?)?.toInt();
      _tipoPrestador = fkGrupo == null ? 'Independente' : 'Empresa / Loja';

      if (fkUsuario != null) {
        final user = await _db
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', fkUsuario)
            .maybeSingle();
        _nomeCliente = user?['nome']?.toString() ?? _nomeCliente;
        _fotoCliente = user?['foto_perfil_url']?.toString();
      }
      if (fkGrupo != null) {
        final group = await _db
            .from('grupo_empresa')
            .select('nome_empresa, foto_url_empresa')
            .eq('id_grupo_empresa', fkGrupo)
            .maybeSingle();
        _nomeProfissional =
            group?['nome_empresa']?.toString() ?? _nomeProfissional;
        _fotoProfissional = group?['foto_url_empresa']?.toString();
      } else if (fkProf != null) {
        final prof = await _db
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', fkProf)
            .maybeSingle();
        final idUsuarioProf = (prof?['fk_usuario'] as num?)?.toInt();
        if (idUsuarioProf != null) {
          final user = await _db
              .from('usuarios')
              .select('nome, foto_perfil_url')
              .eq('id_usuario', idUsuarioProf)
              .maybeSingle();
          _nomeProfissional = user?['nome']?.toString() ?? _nomeProfissional;
          _fotoProfissional = user?['foto_perfil_url']?.toString();
        }
      }
      if (fkServico != null) {
        final service = await _db
            .from('servicos_profissional')
            .select('titulo')
            .eq('id_servico_prof', fkServico)
            .maybeSingle();
        _titulo = service?['titulo']?.toString() ?? _titulo;
      }
      if (fkEndereco != null) {
        final address = await _db
            .from('enderecos')
            .select('logradouro, numero, complemento, bairro, fk_cidade')
            .eq('id_endereco', fkEndereco)
            .maybeSingle();
        if (address != null) {
          _endereco =
              '${address['logradouro'] ?? ''}, ${address['numero'] ?? ''}'
              '${address['complemento'] == null ? '' : ' - ${address['complemento']}'}'
              ', ${address['bairro'] ?? ''}';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar atendimento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _tempo(int segundos) =>
      '${(segundos ~/ 60).toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}';

  Future<void> _confirmarConclusao() async {
    if (!_profissionalFinalizou || _confirmando) return;
    setState(() => _confirmando = true);
    try {
      await _db
          .from('solicitacoes')
          .update({'fk_status': 6, 'etapa_solicitacao': 4})
          .eq('id_solicitacao', widget.idSolicitacao);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DetalhesPedidoPage(idSolicitacao: widget.idSolicitacao),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _confirmando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $e')),
        );
      }
    }
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _avatar(String? url, {double size = 42}) => CircleAvatar(
    radius: size / 2,
    backgroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
    child: url?.isNotEmpty == true ? null : const Icon(Icons.person),
  );

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
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
            const Text(
              'Atendimento no Local',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              _codigoPedido,
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline)),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.emergency_outlined, color: Colors.red),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TelaMeuPerfilClientePage(),
              ),
            ),
            icon: _avatar(_fotoCliente, size: 30),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _etapas(),
          if (_inicio == null && _codigoRecDev.isNotEmpty) _codigoCard(),
          _enderecoCard(),
          _profissionalCard(),
          _duracaoCard(),
          _fotosCard(),
          _servicoCard(),
          _confirmacaoCard(),
        ],
      ),
    );
  }

  Widget _etapas() {
    const etapas = ['Aceito', 'A caminho', 'No Local', 'Concluído'];
    // Esta tela só é aberta com status 34 / etapa 3: as duas primeiras
    // etapas já foram cumpridas, "No Local" está em andamento.
    return _card(
      Row(
        children: [
          for (var i = 0; i < etapas.length; i++)
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i < 2
                        ? _azul
                        : i == 2
                        ? const Color(0xFFFB9263)
                        : const Color(0xFFE2E8F0),
                    child: Icon(
                      i < 2
                          ? Icons.check
                          : i == 2
                          ? Icons.place_outlined
                          : Icons.check_circle_outline,
                      color: i < 3 ? Colors.white : const Color(0xFF94A3B8),
                      size: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    etapas[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: i < 3 ? _azul : _muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Código que o cliente mostra ao profissional para iniciar o atendimento.
  Widget _codigoCard() => _card(
    Column(
      children: [
        const Text(
          'Código de início do atendimento',
          style: TextStyle(fontWeight: FontWeight.w800, color: _texto),
        ),
        const SizedBox(height: 4),
        const Text(
          'Informe este código ao profissional para ele iniciar o atendimento.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in _codigoRecDev.padRight(4, '-').split('').take(4))
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _azul,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _enderecoCard() => _card(
    Row(
      children: [
        const Icon(Icons.location_on_outlined, color: _azul),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profissional no seu endereço',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                _endereco,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              if (_inicio != null)
                Text(
                  'Chegou às ${_inicio!.toLocal().hour.toString().padLeft(2, '0')}:${_inicio!.toLocal().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _profissionalCard() => _card(
    Column(
      children: [
        Row(
          children: [
            _avatar(_fotoProfissional),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nomeProfissional,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _tipoPrestador,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  const Text(
                    '★ 4,9 · 148 atendimentos realizados',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Honda CG 160 Cargo · Preta · ABC-4398',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaChatProfissional(
                  nomeProfissional: _nomeProfissional,
                  fotoProfissional: _fotoProfissional ?? '',
                  oficioPrincipal: _titulo,
                  idSolicitacao: widget.idSolicitacao,
                ),
              ),
            ),
            icon: const Icon(Icons.chat_outlined, size: 17),
            label: Text('Conversar com $_nomeProfissional'),
          ),
        ),
      ],
    ),
  );

  Widget _duracaoCard() => _card(
    Row(
      children: [
        const Icon(Icons.timer_outlined, color: _azul),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'DURAÇÃO DO SERVIÇO',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          _tempo(_duracao),
          style: const TextStyle(
            color: _azul,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _fotosCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REGISTRO FOTOGRÁFICO TÉCNICO',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _foto(_antes, 'Antes')),
            const SizedBox(width: 8),
            Expanded(child: _foto(_depois, 'Depois')),
          ],
        ),
      ],
    ),
  );

  Widget _foto(List<String> fotos, String titulo) => Column(
    children: [
      Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: fotos.isEmpty
            ? const Center(child: Icon(Icons.photo_outlined, color: _muted))
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  fotos.first,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
      ),
      Text(titulo, style: const TextStyle(fontSize: 10, color: _muted)),
    ],
  );

  Widget _servicoCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PEDIDO $_codigoPedido',
          style: const TextStyle(fontSize: 10, color: _muted),
        ),
        const SizedBox(height: 4),
        Text(_titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
          'Método de pagamento: $_metodoPagamento',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 4),
        Text(
          'Valor total: R\$ ${_valor.toStringAsFixed(2).replaceAll('.', ',')}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _confirmacaoCard() => _card(
    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _profissionalFinalizou && !_confirmando
            ? _confirmarConclusao
            : null,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(
          _profissionalFinalizou
              ? 'Confirmar conclusão do serviço'
              : 'Aguardando conclusão do profissional',
        ),
      ),
    ),
  );
}
