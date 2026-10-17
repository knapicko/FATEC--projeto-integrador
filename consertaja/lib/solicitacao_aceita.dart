import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'meus_servicos_solicitados.dart';

class SolicitacaoAceitaPage extends StatefulWidget {
  const SolicitacaoAceitaPage({super.key, required this.solicitacao});

  final SolicitacaoRecebida solicitacao;

  @override
  State<SolicitacaoAceitaPage> createState() => _SolicitacaoAceitaPageState();
}

class _SolicitacaoAceitaPageState extends State<SolicitacaoAceitaPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _fundo = Color(0xFFF8FAFC);
  static const _muted = Color(0xFF64748B);
  final _supabase = Supabase.instance.client;

  String? _endereco;
  List<String> _anexos = [];
  bool _carregandoDados = true;

  String get _tipo => widget.solicitacao.tipoExecucao.trim().toLowerCase();
  bool get _levaTraz => _tipo.contains('leva') || _tipo.contains('traz');
  bool get _retirada => _tipo.contains('retirad');
  bool get _receba => _tipo.contains('receba') || _tipo.contains('casa');

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final idEndereco = widget.solicitacao.fkEndereco;
      if (idEndereco != null) {
        final end = await _supabase
            .from('enderecos')
            .select('logradouro, numero, complemento, bairro, fk_cidade')
            .eq('id_endereco', idEndereco)
            .maybeSingle();
        if (end != null) {
          var cidadeEstado = '';
          final idCidade = (end['fk_cidade'] as num?)?.toInt();
          if (idCidade != null) {
            final cidade = await _supabase
                .from('cidades')
                .select('nome_cidade, fk_estado')
                .eq('id_cidade', idCidade)
                .maybeSingle();
            final estadoId = (cidade?['fk_estado'] as num?)?.toInt();
            var sigla = '';
            if (estadoId != null) {
              final estado = await _supabase
                  .from('estados')
                  .select('sigla_estado')
                  .eq('id_estado', estadoId)
                  .maybeSingle();
              sigla = estado?['sigla_estado']?.toString() ?? '';
            }
            final cidadeNome = cidade?['nome_cidade']?.toString() ?? '';
            cidadeEstado = [
              cidadeNome,
              sigla,
            ].where((part) => part.trim().isNotEmpty).join(' - ');
          }
          final rua = end['logradouro']?.toString() ?? '';
          final numero = end['numero']?.toString() ?? '';
          final complemento = end['complemento']?.toString() ?? '';
          final bairro = end['bairro']?.toString() ?? '';
          _endereco = [
            [rua, numero].where((part) => part.trim().isNotEmpty).join(', '),
            complemento,
            bairro,
            cidadeEstado,
          ].where((part) => part.trim().isNotEmpty).join(' - ');
        }
      }
      final anexos = await _supabase
          .from('solicitacoes_anexos')
          .select('anexo_url')
          .eq('fk_solicitacao', widget.solicitacao.idSolicitacao);
      _anexos = anexos
          .map((row) => row['anexo_url']?.toString().trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Não foi possível carregar detalhes da solicitação: $e');
    } finally {
      if (mounted) setState(() => _carregandoDados = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.solicitacao;
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _azul,
        elevation: 0,
        title: Text(
          item.tituloServico,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.account_circle, color: _azul, size: 27),
          ),
        ],
      ),
      body: _carregandoDados
          ? const Center(child: CircularProgressIndicator(color: _azul))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
              children: [
                _confirmacao(),
                _andamento(),
                _cliente(),
                _servico(),
                _modalidade(),
                _agendamento(),
                _localizacao(),
                _estimativa(),
                if (_receba) _checklist(),
                _acoes(),
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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .035),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _confirmacao() {
    final item = widget.solicitacao;
    return _card(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: _azul,
            child: Icon(Icons.check, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _tag('Confirmado'),
                    const Spacer(),
                    Text(
                      '#PED-${item.idSolicitacao}',
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'Você aceitou este serviço!',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'A cliente ${item.nomeCliente} foi notificada. '
                  'Os detalhes do atendimento estão abaixo.',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _andamento() {
    final etapas = _retirada
        ? ['Aceito', 'Cliente', 'Processo', 'Cliente', 'Concluído']
        : _levaTraz
        ? ['Aceito', 'Busca', 'Processo', 'Entrega', 'Concluído']
        : _receba
        ? ['Aceito', 'Cliente', 'Processo', 'Entrega', 'Concluído']
        : ['Aceito', 'Deslocamento', 'No Local', 'Concluído'];
    final info = _retirada || _receba
        ? 'Aguarde o cliente iniciar o trajeto e entregar o produto.'
        : 'Você aceitou o pedido. O próximo passo é iniciar o deslocamento até o cliente.';
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Andamento do Pedido',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              _tag(
                _retirada || _receba
                    ? 'A Caminho (Próximo)'
                    : 'Etapa 1 de ${etapas.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(etapas.length, (index) {
              final ultimo = index == etapas.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: index == 0
                              ? _azul
                              : const Color(0xFFE2E8F0),
                          child: Icon(
                            index == 0 ? Icons.check : Icons.circle,
                            size: 10,
                            color: index == 0 ? Colors.white : _muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          etapas[index],
                          style: const TextStyle(fontSize: 8, color: _muted),
                        ),
                      ],
                    ),
                    if (!ultimo)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          _infoBox(info),
        ],
      ),
    );
  }

  Widget _cliente() {
    final item = widget.solicitacao;
    return _card(
      Row(
        children: [
          _avatar(item),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nomeCliente,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  item.tituloServico,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, size: 14),
            label: const Text('Conversar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _azul,
              side: const BorderSide(color: _azul),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const SizedBox(width: 5),
          IconButton(
            onPressed: _ligar,
            icon: const Icon(Icons.phone_outlined, size: 19),
            color: _muted,
            tooltip: 'Ligar para cliente',
          ),
        ],
      ),
    );
  }

  Widget _servico() {
    final item = widget.solicitacao;
    final descricao = item.detalhes?.isNotEmpty == true
        ? item.detalhes!
        : item.descricaoServico ?? 'Descrição não informada.';
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: _azul,
                child: Icon(
                  Icons.handyman_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SERVIÇO SELECIONADO',
                  style: TextStyle(fontSize: 10, color: _muted),
                ),
              ),
              _tag('${_anexos.length} anexo${_anexos.length == 1 ? '' : 's'}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.tituloServico,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          _infoBox(descricao),
          if (_anexos.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _anexos.first,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder('Anexo indisponível'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modalidade() {
    final titulo = widget.solicitacao.tipoExecucao.isEmpty
        ? 'Modalidade não informada'
        : widget.solicitacao.tipoExecucao;
    final descricao = _retirada
        ? 'O cliente irá trazer o produto até você e depois irá buscá-lo de volta.'
        : _receba
        ? 'O cliente irá trazer o produto até você e depois você irá entregar o produto no endereço do cliente.'
        : _levaTraz
        ? 'O profissional irá buscar o produto e entregá-lo de volta ao cliente.'
        : 'O profissional irá até o endereço cadastrado para vistoria e conserto.';
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: _azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _tag('Inclusa'),
            ],
          ),
          const SizedBox(height: 10),
          _infoBox(descricao),
          const SizedBox(height: 8),
          const Text(
            'Taxa de deslocamento inclusa na estimativa',
            style: TextStyle(fontSize: 10, color: _azul),
          ),
        ],
      ),
    );
  }

  Widget _agendamento() {
    final data = widget.solicitacao.dataAgendada;
    final hora = widget.solicitacao.horaAgendada;
    return _card(
      Row(
        children: [
          Expanded(
            child: _dataBox(
              Icons.calendar_month_outlined,
              'Data',
              _formatarData(data),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dataBox(
              Icons.access_time,
              'Horário',
              hora?.isNotEmpty == true ? hora! : 'Não informado',
            ),
          ),
        ],
      ),
    );
  }

  Widget _localizacao() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: _azul, size: 20),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _endereco ?? 'Endereço não disponível',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Distância e rota não disponíveis para esta solicitação.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9)),
            child: _placeholder(
              _endereco == null
                  ? 'Mapa indisponível'
                  : 'Coordenadas do endereço não disponíveis para traçar a rota',
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimativa() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimativa Combinada', style: TextStyle(color: _muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _formatarPreco(widget.solicitacao.valorFinal),
                style: const TextStyle(
                  color: _azul,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _tag('Pagamento não informado'),
            ],
          ),
          const SizedBox(height: 10),
          _infoBox('Pagamento garantido após a conclusão técnica do serviço.'),
        ],
      ),
    );
  }

  Widget _checklist() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Checklist do Especialista',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Recomendado',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Checklist não configurado para esta categoria.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _acoes() {
    final esperaCliente = _retirada || _receba;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: esperaCliente ? null : () {},
            icon: Icon(
              esperaCliente ? Icons.hourglass_empty : Icons.near_me_outlined,
            ),
            label: Text(
              esperaCliente
                  ? (_receba
                        ? 'Aguarde a entrega do cliente'
                        : 'Aguarde o cliente iniciar o trajeto')
                  : 'Iniciar Deslocamento / Rota',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              disabledBackgroundColor: _azul,
              disabledForegroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('Salvar na Agenda'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.warning_amber_outlined, size: 17),
                label: const Text('Relatar Imprevisto'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _azul.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _azul,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _infoBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: _muted, height: 1.35),
    ),
  );

  Widget _dataBox(IconData icon, String title, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F7F7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _azul),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _avatar(SolicitacaoRecebida item) {
    final foto = item.fotoCliente?.trim() ?? '';
    if (foto.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          foto,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarFallback(item.nomeCliente),
        ),
      );
    }
    return _avatarFallback(item.nomeCliente);
  }

  Widget _avatarFallback(String nome) => CircleAvatar(
    backgroundColor: _azul,
    child: Text(
      nome.isEmpty ? '?' : nome.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );

  Widget _placeholder(String text) => Container(
    color: const Color(0xFFE2E8F0),
    alignment: Alignment.center,
    child: Text(text, style: const TextStyle(color: _muted)),
  );

  String _formatarData(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Não informada';
    final partes = valor.split('-');
    if (partes.length == 3) return '${partes[2]}/${partes[1]}/${partes[0]}';
    return valor;
  }

  String _formatarPreco(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _ligar() async {
    final uri = Uri(scheme: 'tel', path: '');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
