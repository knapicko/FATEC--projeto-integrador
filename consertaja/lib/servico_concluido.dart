import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tela_home_profissional.dart';

class ServicoConcluidoPage extends StatefulWidget {
  final int idSolicitacao;

  const ServicoConcluidoPage({super.key, required this.idSolicitacao});

  @override
  State<ServicoConcluidoPage> createState() => _ServicoConcluidoPageState();
}

class _ServicoConcluidoPageState extends State<ServicoConcluidoPage> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _solicitacao;
  String _nomeCliente = 'Cliente';
  String _titulo = 'Serviço concluído';
  String? _fotoCliente;
  String _endereco = '';
  List<_FotoConclusao> _fotos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
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
      _solicitacao = row;
      final idCliente = (row['fk_usuario'] as num?)?.toInt();
      final idServico = (row['fk_servico_prof'] as num?)?.toInt();
      final idEndereco = (row['fk_endereco'] as num?)?.toInt();
      if (idCliente != null) {
        final user = await _db
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', idCliente)
            .maybeSingle();
        _nomeCliente = user?['nome']?.toString() ?? _nomeCliente;
        _fotoCliente = user?['foto_perfil_url']?.toString();
      }
      if (idServico != null) {
        final service = await _db
            .from('servicos_profissional')
            .select('titulo')
            .eq('id_servico_prof', idServico)
            .maybeSingle();
        _titulo = service?['titulo']?.toString() ?? _titulo;
      }
      if (idEndereco != null) {
        final address = await _db
            .from('enderecos')
            .select('logradouro, numero, complemento, bairro')
            .eq('id_endereco', idEndereco)
            .maybeSingle();
        if (address != null) {
          _endereco =
              '${address['logradouro'] ?? ''}, ${address['numero'] ?? ''}, '
              '${address['bairro'] ?? ''}';
        }
      }
      final domicilio =
          row['tipo_execucao']?.toString().toLowerCase().contains('domic') ==
          true;
      final grupos = domicilio
          ? <(String, String)>[
              ('Antes', 'imagens_atendimento_antes'),
              ('Depois', 'imagens_atendimento_depois'),
            ]
          : <(String, String)>[
              ('Recebimento', 'imagens_recebimento'),
              ('Em andamento', 'imagens_em_andamento'),
              ('Devolução', 'imagens_devolucao'),
            ];
      for (final grupo in grupos) {
        for (final url in _lista(row[grupo.$2])) {
          _fotos.add(_FotoConclusao(grupo.$1, url));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar conclusão: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  String _duracao() {
    final domicilio =
        _solicitacao?['tipo_execucao']?.toString().toLowerCase().contains(
          'domic',
        ) ==
        true;
    final seconds =
        (_solicitacao?[domicilio ? 'duracao_atendimento' : 'duracao_servico']
                as num?)
            ?.toInt() ??
        0;
    return '${seconds ~/ 60} minutos';
  }

  @override
  Widget build(BuildContext context) {
    final id = '#PED-2026-${widget.idSolicitacao.toString().padLeft(4, '0')}';
    final valor = (_solicitacao?['valor_final'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serviço Concluído E Recebimento',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(id, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(_etapas()),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAGAMENTO LIBERADO',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('Valor total do serviço'),
                Text(
                  'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    color: Color(0xFF0FB3FF),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Taxas: conforme processamento do pagamento',
                  style: TextStyle(color: Colors.grey),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Ver extrato'),
                  ),
                ),
              ],
            ),
          ),
          _card(
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: _fotoCliente?.isNotEmpty == true
                      ? NetworkImage(_fotoCliente!)
                      : null,
                  child: _fotoCliente?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nomeCliente,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _titulo,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _endereco,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Duração do serviço: ${_duracao()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Text(
                        'Pagamento: PIX Seguro',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VISTORIA E COMPROVANTES',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (_fotos.isEmpty)
                  const Text(
                    'Nenhuma imagem registrada',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _fotos
                        .map(
                          (foto) => SizedBox(
                            width: 145,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.network(
                                  foto.url,
                                  height: 100,
                                  width: 145,
                                  fit: BoxFit.cover,
                                ),
                                Text(
                                  foto.tipo,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const TelaHomeProfissional(isVisitante: false),
              ),
              (route) => false,
            ),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Voltar para o início'),
          ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_outlined),
            label: const Text('Baixar comprovante de conclusão (PDF)'),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _etapas() => Row(
    children: [
      for (final etapa in [
        'Aceito',
        'Busca',
        'Processo',
        'Entrega',
        'Concluído',
      ])
        Expanded(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF0FB3FF),
                child: Icon(Icons.check, color: Colors.white, size: 14),
              ),
              const SizedBox(height: 4),
              Text(
                etapa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
    ],
  );
}

class _FotoConclusao {
  final String tipo;
  final String url;
  const _FotoConclusao(this.tipo, this.url);
}
