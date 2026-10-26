import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/iniciais.dart';

class PedidoPagoPage extends StatefulWidget {
  final int idSolicitacao;

  const PedidoPagoPage({super.key, required this.idSolicitacao});

  @override
  State<PedidoPagoPage> createState() => _PedidoPagoPageState();
}

class _PedidoPagoPageState extends State<PedidoPagoPage> {
  static const _azul = Color(0xFF12B5F5);
  static const _texto = Color(0xFF20242A);
  static const _muted = Color(0xFF626B76);
  static const _fundo = Color(0xFFF8F9FB);

  final _db = Supabase.instance.client;
  bool _carregando = true;
  String? _erro;
  String _servico = 'Serviço';
  String _profissional = 'Profissional';
  String? _fotoProfissional;
  String _dataHora = 'Agora';
  double _valor = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  double _numero(dynamic valor) => valor is num
      ? valor.toDouble()
      : double.tryParse(valor?.toString() ?? '') ?? 0;

  Future<void> _carregar() async {
    try {
      final sol = await _db
          .from('solicitacoes')
          .select(
            'fk_profissional, fk_grupo_empresa, fk_servico_prof, fk_servico_temp, valor_final, data_agendada, hora_agendada',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();
      if (sol == null) throw Exception('Pedido não encontrado.');

      _valor = _numero(sol['valor_final']);
      final data = sol['data_agendada']?.toString() ?? '';
      final hora = sol['hora_agendada']?.toString() ?? '';
      if (data.isNotEmpty && hora.isNotEmpty) {
        final partes = data.split('-');
        final dataBr = partes.length == 3
            ? '${partes[2]}/${partes[1]}/${partes[0]}'
            : data;
        _dataHora = '$dataBr, ${hora.substring(0, hora.length.clamp(0, 5))}';
      }

      final fkServico = (sol['fk_servico_prof'] as num?)?.toInt();
      final fkTemporario = (sol['fk_servico_temp'] as num?)?.toInt();
      if (fkServico != null) {
        final servico = await _db
            .from('servicos_profissional')
            .select('titulo, valor')
            .eq('id_servico_prof', fkServico)
            .maybeSingle();
        _servico = servico?['titulo']?.toString() ?? _servico;
        if (_valor <= 0) _valor = _numero(servico?['valor']);
      } else if (fkTemporario != null) {
        final servico = await _db
            .from('servicos_chat_temporario')
            .select('titulo, valor')
            .eq('id_servico_temp', fkTemporario)
            .maybeSingle();
        _servico = servico?['titulo']?.toString() ?? _servico;
        if (_valor <= 0) _valor = _numero(servico?['valor']);
      }

      final grupo = (sol['fk_grupo_empresa'] as num?)?.toInt();
      if (grupo != null && grupo > 0) {
        final empresa = await _db
            .from('grupo_empresa')
            .select('nome_empresa, foto_url_empresa')
            .eq('id_grupo_empresa', grupo)
            .maybeSingle();
        _profissional = empresa?['nome_empresa']?.toString() ?? _profissional;
        _fotoProfissional = empresa?['foto_url_empresa']?.toString();
      } else {
        final profissional = (sol['fk_profissional'] as num?)?.toInt();
        if (profissional != null) {
          final dados = await _db
              .from('dados_profissionais')
              .select('fk_usuario')
              .eq('id_profissional', profissional)
              .maybeSingle();
          final usuario = (dados?['fk_usuario'] as num?)?.toInt();
          if (usuario != null) {
            final pessoa = await _db
                .from('usuarios')
                .select('nome, foto_perfil_url')
                .eq('id_usuario', usuario)
                .maybeSingle();
            _profissional = pessoa?['nome']?.toString() ?? _profissional;
            _fotoProfissional = pessoa?['foto_perfil_url']?.toString();
          }
        }
      }
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _valorFormatado() {
    final partes = _valor.toStringAsFixed(2).split('.');
    return 'R\$ ${partes[0].replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => '.')},${partes[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: _azul))
            : _erro != null
            ? Center(
                child: Text(_erro!, style: const TextStyle(color: Colors.red)),
              )
            : Column(
                children: [
                  _cabecalho(),
                  Expanded(child: _conteudo()),
                ],
              ),
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EBEF))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: _azul),
          ),
          const Expanded(
            child: Text(
              'Pagamento Confirmado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azul,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _conteudo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 36, 14, 28),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pagamento Realizado com\nSucesso!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _azul,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Seu pedido de serviço foi enviado ao\nprofissional e em breve ele entrará em contato.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 28),
          _resumo(),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Extrato disponível em breve.')),
              ),
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('Gerar Extrato do Pagamento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF17436D),
                side: const BorderSide(color: Color(0xFFB7C2D0), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text('Ver Meus Pedidos'),
              style: FilledButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumo() {
    final foto = (_fotoProfissional ?? '').trim();
    final iniciais = obterIniciais(_profissional);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E4E8)),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '▣  Resumo do Serviço',
              style: TextStyle(
                color: _texto,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 26),
          _linha('Serviço', _servico),
          _linha(
            'Profissional',
            _profissional,
            trailing: foto.startsWith('http')
                ? CircleAvatar(radius: 10, backgroundImage: NetworkImage(foto))
                : CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFFE4F4FC),
                    child: Text(
                      iniciais,
                      style: const TextStyle(color: _azul, fontSize: 8),
                    ),
                  ),
          ),
          _linha('Data e Hora', _dataHora),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F6FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Valor Total',
                  style: TextStyle(
                    color: Color(0xFF0795D4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _valorFormatado(),
                  style: const TextStyle(
                    color: _azul,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(String titulo, String valor, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              titulo,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ),
          ?trailing,
          if (trailing != null) const SizedBox(width: 6),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _texto,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
