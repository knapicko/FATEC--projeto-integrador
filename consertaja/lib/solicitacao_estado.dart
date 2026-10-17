import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gestao_equipe.dart';
import 'meus_servicos_solicitados.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';

/// Modalidades suportadas de acordo com o design
enum ModalidadeExecucao {
  levaETraz,
  atendimentoDomicilio,
  retiradaNoLocal,
  recebaEmCasa;

  static ModalidadeExecucao fromString(String? raw) {
    final s = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('õ', 'o');

    if (s.contains('leva') && s.contains('traz')) {
      return ModalidadeExecucao.levaETraz;
    }
    if (s.contains('retirad') || (s.contains('retirada') && s.contains('local'))) {
      return ModalidadeExecucao.retiradaNoLocal;
    }
    if (s.contains('receba') || (s.contains('receba') && s.contains('casa'))) {
      return ModalidadeExecucao.recebaEmCasa;
    }
    // Domicílio / Presencial / Local / Execução padrão
    return ModalidadeExecucao.atendimentoDomicilio;
  }
}

class ItemChecklist {
  final String titulo;
  bool marcado;

  ItemChecklist(this.titulo, {this.marcado = false});
}

class SolicitacaoEstadoPage extends StatefulWidget {
  final int idSolicitacao;
  final SolicitacaoRecebida? solicitacao;
  final bool recemAceito;

  const SolicitacaoEstadoPage({
    super.key,
    required this.idSolicitacao,
    this.solicitacao,
    this.recemAceito = false,
  });

  @override
  State<SolicitacaoEstadoPage> createState() => _SolicitacaoEstadoPageState();
}

class _SolicitacaoEstadoPageState extends State<SolicitacaoEstadoPage>
    with SingleTickerProviderStateMixin {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _azulEscuro = Color(0xFF0284C7);
  static const Color _fundoCinza = Color(0xFFF8FAFC);
  static const Color _textoEscuro = Color(0xFF0F172A);
  static const Color _textoMuted = Color(0xFF64748B);
  static const Color _cinzaBorda = Color(0xFFE2E8F0);
  static const Color _cinzaCardInterno = Color(0xFFF1F5F9);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  String? _erro;

  // Dados carregados do Supabase
  late int _idSolicitacao;
  String _codigoPedido = '';
  String _categoriaTitulo = 'Conserto e Reparo';
  String _nomeCliente = 'Cliente';
  String? _fotoCliente;
  String? _telefoneCliente;
  String _modeloEquipamento = '';
  String _tituloServico = 'Serviço Solicitado';
  String _relatoCliente = '';
  int _quantidadeAnexos = 1;
  String? _imagemAnexoUrl;
  String _legendaAnexo = '';
  ModalidadeExecucao _modalidade = ModalidadeExecucao.levaETraz;
  String _tipoExecucaoOriginal = 'Leva e Traz';

  String _dataExibicao = '15 de Outubro';
  String _periodoExibicao = 'Hoje à tarde';
  String _horaExibicao = '14:00';
  String _janelaExibicao = 'Janela: 14h - 16h';

  String _enderecoLinha1 = 'Rua das Acácias, 452 - Apto 82';
  String _enderecoLinha2 = 'Mooca, São Paulo - SP';
  String _distanciaTexto = 'Aproximadamente 2.5 km (9 min de carro)';
  String _trajetoOverlayTexto = 'Trajeto mais rápido via Av. Paes de Barros';
  LatLng _coordenadas = const LatLng(-23.5605, -46.5983);

  String _valorExibicao = 'R\$ 150,00 - 250,00';
  final String _metodoPagamento = 'Pix ou Cartão';

  // Checklist do Especialista (específico de Receba em casa / serviços técnicos)
  List<ItemChecklist> _checklistItens = [];

  // IDs para chat e contatos
  int? _fkGrupoEmpresa;
  int _fkProfissional = 0;

  // Perfil logado do usuário (diferenciando empresa x profissional)
  bool _ehContaEmpresa = false;
  String? _fotoPerfilLogado;
  String? _nomePerfilLogado;
  int? _idGrupoEmpresaLogado;

  late AnimationController _sonarController;
  late Animation<double> _sonarAnimation;

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _sonarAnimation = CurvedAnimation(
      parent: _sonarController,
      curve: Curves.easeOut,
    );

    _idSolicitacao = widget.idSolicitacao;
    _codigoPedido = '#PED-${DateTime.now().year}-${_idSolicitacao.toString().padLeft(4, '0')}';

    // Preenche com dados iniciais se disponíveis
    if (widget.solicitacao != null) {
      _aplicarDadosIniciais(widget.solicitacao!);
    }

    _carregarPerfilLogado();
    _carregarDadosCompletos();
  }

  @override
  void dispose() {
    _sonarController.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfilLogado() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      bool ehEmpresa = BottomNavigationBarProfissional.leituraSincronaContaEmpresa();

      final usuarioRow = await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .eq('auth_id', user.id)
          .maybeSingle();

      final idUsuario = (usuarioRow?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return;

      final dp = await _supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();

      final idGrupo = (dp?['fk_grupo_empresa'] as num?)?.toInt();

      String? foto;
      String? nome = usuarioRow?['nome']?.toString().trim();

      if (ehEmpresa && idGrupo != null) {
        final grupo = await _supabase
            .from('grupo_empresa')
            .select('id_grupo_empresa, nome_empresa, foto_url_empresa')
            .eq('id_grupo_empresa', idGrupo)
            .maybeSingle();
        if (grupo != null) {
          final fEmp = grupo['foto_url_empresa']?.toString().trim();
          if (fEmp != null && fEmp.isNotEmpty) foto = fEmp;
          final nEmp = grupo['nome_empresa']?.toString().trim() ?? '';
          if (nEmp.isNotEmpty) nome = nEmp;
        }
      } else {
        ehEmpresa = false;
        final fUsu = usuarioRow?['foto_perfil_url']?.toString().trim();
        if (fUsu != null && fUsu.isNotEmpty) foto = fUsu;
      }

      if (mounted) {
        setState(() {
          _ehContaEmpresa = ehEmpresa;
          _fotoPerfilLogado = foto;
          _nomePerfilLogado = nome;
          _idGrupoEmpresaLogado = idGrupo;
        });
      }
    } catch (_) {}
  }

  void _navegarParaPerfilLogado() {
    if (_ehContaEmpresa && _idGrupoEmpresaLogado != null) {
      Navigator.of(context).push(
        AppNavigationUtil.rotaSemAnimacao(
          const GestaoEquipePage(),
          nome: 'GestaoEquipePage',
        ),
      );
    } else {
      AppNavigationUtil.navegarAba(
        context,
        const TelaMeuPerfilProfissionalPage(isVisitante: false),
        isHome: false,
      );
    }
  }

  void _aplicarDadosIniciais(SolicitacaoRecebida s) {
    _nomeCliente = s.nomeCliente;
    _fotoCliente = s.fotoCliente;
    _tituloServico = s.tituloServico;
    _categoriaTitulo = s.funcao?.isNotEmpty == true ? s.funcao! : s.tituloServico;
    _modeloEquipamento = s.tituloServico;
    if (s.detalhes?.isNotEmpty == true) {
      _relatoCliente = s.detalhes!;
    } else if (s.descricaoServico?.isNotEmpty == true) {
      _relatoCliente = s.descricaoServico!;
    }
    _imagemAnexoUrl = s.imagemAnexoUrl ?? s.imagemServicoUrl;
    _tipoExecucaoOriginal = s.tipoExecucao;
    _modalidade = ModalidadeExecucao.fromString(s.tipoExecucao);
    _fkGrupoEmpresa = s.fkGrupoEmpresa;
    _fkProfissional = s.fkProfissional;

    _formatarDataHora(s.dataAgendada, s.horaAgendada);
    _formatarPrecoValor(s.valorFinal);
    _gerarChecklistParaServico(_categoriaTitulo);
  }

  void _formatarPrecoValor(double valor) {
    if (valor <= 0) {
      _valorExibicao = 'R\$ 150,00 - 250,00';
    } else {
      final min = (valor * 0.85).round();
      final max = (valor * 1.25).round();
      if (min != max) {
        _valorExibicao = 'R\$ $min,00 - $max,00';
      } else {
        _valorExibicao = 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
      }
    }
  }

  void _formatarDataHora(String? data, String? hora) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    if (data != null && data.isNotEmpty) {
      try {
        final partes = data.split('-');
        if (partes.length == 3) {
          final ano = int.tryParse(partes[0]) ?? DateTime.now().year;
          final mes = int.tryParse(partes[1]) ?? 1;
          final dia = int.tryParse(partes[2]) ?? 1;
          _dataExibicao = '$dia de ${meses[(mes - 1).clamp(0, 11)]}';

          final dtAgendada = DateTime(ano, mes, dia);
          final hoje = DateTime.now();
          final diff = DateTime(dtAgendada.year, dtAgendada.month, dtAgendada.day)
              .difference(DateTime(hoje.year, hoje.month, hoje.day))
              .inDays;

          if (diff == 0) {
            _periodoExibicao = 'Hoje à tarde';
          } else if (diff == 1) {
            _periodoExibicao = 'Amanhã';
          } else if (diff == -1) {
            _periodoExibicao = 'Ontem';
          } else {
            _periodoExibicao = 'Data agendada';
          }
        }
      } catch (_) {}
    }

    if (hora != null && hora.isNotEmpty) {
      try {
        final partesH = hora.split(':');
        if (partesH.isNotEmpty) {
          final h = int.tryParse(partesH[0]) ?? 14;
          final m = partesH.length > 1 ? partesH[1] : '00';
          _horaExibicao = '${h.toString().padLeft(2, '0')}:${m.padLeft(2, '0')}';
          final hFim = (h + 2) % 24;
          _janelaExibicao = 'Janela: ${h}h - ${hFim}h';
        }
      } catch (_) {}
    }
  }

  void _gerarChecklistParaServico(String categoria) {
    final cat = categoria.toLowerCase();
    if (cat.contains('ar') || cat.contains('clima') || cat.contains('split')) {
      _checklistItens = [
        ItemChecklist('Multímetro e manômetro de teste', marcado: true),
        ItemChecklist('EPIs adequados (luvas, óculos de proteção)', marcado: true),
        ItemChecklist('Gás refrigerante e bomba de vácuo', marcado: true),
        ItemChecklist('Kit de chaves isoladas e alicates', marcado: false),
        ItemChecklist('Recipiente para drenagem de água', marcado: false),
      ];
    } else if (cat.contains('celular') || cat.contains('comput') || cat.contains('noteb') || cat.contains('eletron')) {
      _checklistItens = [
        ItemChecklist('Manta e pulseira antiestática', marcado: true),
        ItemChecklist('Kit chaves de precisão Torx e Phillips', marcado: true),
        ItemChecklist('Estação de solda e soprador térmico', marcado: true),
        ItemChecklist('Álcool isopropílico 99% e pincel antiestático', marcado: false),
      ];
    } else if (cat.contains('eletric') || cat.contains('fiacao')) {
      _checklistItens = [
        ItemChecklist('Alicate amperímetro / multímetro True-RMS', marcado: true),
        ItemChecklist('EPIs de isolamento 1000V', marcado: true),
        ItemChecklist('Fita isolante antichama e conectores Wago', marcado: true),
        ItemChecklist('Passa-fios de nylon / aço', marcado: false),
      ];
    } else {
      _checklistItens = [
        ItemChecklist('Conjunto de ferramentas manuais e chaves', marcado: true),
        ItemChecklist('EPIs adequados de segurança', marcado: true),
        ItemChecklist('Peças de reposição e vedações de teste', marcado: true),
        ItemChecklist('Pano de limpeza e lubrificante técnico', marcado: false),
      ];
    }
  }

  Future<void> _carregarDadosCompletos() async {
    try {
      final row = await _supabase
          .from('solicitacoes')
          .select(
            'id_solicitacao, data_solicitacao, valor_final, detalhes, '
            'data_agendada, hora_agendada, tipo_execucao, fk_grupo_empresa, '
            'fk_status, fk_profissional, fk_usuario, fk_endereco, fk_servico_prof',
          )
          .eq('id_solicitacao', _idSolicitacao)
          .maybeSingle();

      if (row == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final idSolicitacao = (row['id_solicitacao'] as num).toInt();
      _codigoPedido = '#PED-2026-${idSolicitacao.toString().padLeft(4, '0')}';
      _tipoExecucaoOriginal = row['tipo_execucao']?.toString().trim() ?? 'Leva e Traz';
      _modalidade = ModalidadeExecucao.fromString(_tipoExecucaoOriginal);
      _fkGrupoEmpresa = (row['fk_grupo_empresa'] as num?)?.toInt();
      _fkProfissional = (row['fk_profissional'] as num?)?.toInt() ?? 0;

      final valorFinal = double.tryParse(row['valor_final']?.toString() ?? '0') ?? 0.0;
      _formatarPrecoValor(valorFinal);

      final detalhes = row['detalhes']?.toString().trim() ?? '';
      if (detalhes.isNotEmpty) {
        _relatoCliente = detalhes;
      }

      _formatarDataHora(row['data_agendada']?.toString(), row['hora_agendada']?.toString());

      // 1. Dados do Cliente
      final idCliente = (row['fk_usuario'] as num?)?.toInt();
      if (idCliente != null) {
        try {
          final u = await _supabase
              .from('usuarios')
              .select('nome, foto_perfil_url, telefone')
              .eq('id_usuario', idCliente)
              .maybeSingle();
          if (u != null) {
            final n = u['nome']?.toString().trim() ?? '';
            if (n.isNotEmpty) _nomeCliente = n;
            final f = u['foto_perfil_url']?.toString().trim() ?? '';
            if (f.isNotEmpty) _fotoCliente = f;
            final tel = u['telefone']?.toString().trim() ?? '';
            if (tel.isNotEmpty) _telefoneCliente = tel;
          }
        } catch (_) {}
      }

      // 2. Serviço e Categoria
      final idServico = (row['fk_servico_prof'] as num?)?.toInt();
      if (idServico != null) {
        try {
          final s = await _supabase
              .from('servicos_profissional')
              .select('titulo, descricao, imagem_url, oficios(funcao, cor)')
              .eq('id_servico_prof', idServico)
              .maybeSingle();
          if (s != null) {
            final t = s['titulo']?.toString().trim() ?? '';
            if (t.isNotEmpty) {
              _tituloServico = t;
              _modeloEquipamento = t;
            }
            if (_relatoCliente.isEmpty) {
              final d = s['descricao']?.toString().trim() ?? '';
              if (d.isNotEmpty) _relatoCliente = d;
            }
            final img = s['imagem_url']?.toString().trim() ?? '';
            if (img.isNotEmpty && _imagemAnexoUrl == null) {
              _imagemAnexoUrl = img;
            }
            final dynamic ofRaw = s['oficios'];
            final Map<String, dynamic>? ofMap = ofRaw is Map<String, dynamic>
                ? ofRaw
                : (ofRaw is List && ofRaw.isNotEmpty
                    ? Map<String, dynamic>.from(ofRaw.first as Map)
                    : null);
            if (ofMap != null) {
              final func = ofMap['funcao']?.toString().trim() ?? '';
              if (func.isNotEmpty) {
                _categoriaTitulo = func;
              }
            }
          }
        } catch (_) {}
      }

      if (_categoriaTitulo == 'Conserto e Reparo') {
        _categoriaTitulo = _tituloServico;
      }
      _gerarChecklistParaServico(_categoriaTitulo);

      // 3. Anexos da solicitação
      try {
        final anexos = await _supabase
            .from('solicitacoes_anexos')
            .select('anexo_url, nome_arquivo')
            .eq('fk_solicitacao', _idSolicitacao)
            .order('ordem', ascending: true);

        if (anexos.isNotEmpty) {
          _quantidadeAnexos = anexos.length;
          final primeiro = anexos.first;
          final url = primeiro['anexo_url']?.toString().trim() ?? '';
          if (url.isNotEmpty) {
            _imagemAnexoUrl = url;
          }
          final nomeArq = primeiro['nome_arquivo']?.toString().trim() ?? '';
          if (nomeArq.isNotEmpty) {
            _legendaAnexo = nomeArq;
          }
        }
      } catch (_) {}

      if (_legendaAnexo.isEmpty) {
        _legendaAnexo = _modeloEquipamento.isNotEmpty
            ? _modeloEquipamento
            : 'Foto anexada pela cliente';
      }

      // 4. Endereço do cliente
      final idEndereco = (row['fk_endereco'] as num?)?.toInt();
      if (idEndereco != null) {
        try {
          final end = await _supabase
              .from('enderecos')
              .select('logradouro, numero, complemento, bairro, cep, fk_cidade')
              .eq('id_endereco', idEndereco)
              .maybeSingle();

          if (end != null) {
            final log = end['logradouro']?.toString().trim() ?? 'Rua';
            final numStr = end['numero']?.toString().trim() ?? 'S/N';
            final comp = end['complemento']?.toString().trim() ?? '';
            final bai = end['bairro']?.toString().trim() ?? '';

            var cidNome = 'São Paulo';
            var estSigla = 'SP';
            final idCid = (end['fk_cidade'] as num?)?.toInt();
            if (idCid != null) {
              final cid = await _supabase
                  .from('cidades')
                  .select('nome_cidade, fk_estado')
                  .eq('id_cidade', idCid)
                  .maybeSingle();
              if (cid != null) {
                cidNome = cid['nome_cidade']?.toString().trim() ?? cidNome;
                final idEst = (cid['fk_estado'] as num?)?.toInt();
                if (idEst != null) {
                  final est = await _supabase
                      .from('estados')
                      .select('sigla_estado')
                      .eq('id_estado', idEst)
                      .maybeSingle();
                  if (est != null) {
                    estSigla = est['sigla_estado']?.toString().trim() ?? estSigla;
                  }
                }
              }
            }

            _enderecoLinha1 = comp.isNotEmpty ? '$log, $numStr - $comp' : '$log, $numStr';
            _enderecoLinha2 = bai.isNotEmpty ? '$bai, $cidNome - $estSigla' : '$cidNome - $estSigla';
            _trajetoOverlayTexto = 'Trajeto mais rápido via $log';
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _carregando = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _carregando = false;
        });
      }
    }
  }

  void _abrirChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: _nomeCliente,
          fotoProfissional: _fotoCliente ?? '',
          oficioPrincipal: _categoriaTitulo,
          idProfissional: _fkGrupoEmpresa == null ? _fkProfissional : null,
          idGrupoEmpresa: _fkGrupoEmpresa,
        ),
      ),
    );
  }

  Future<void> _ligarCliente() async {
    final tel = _telefoneCliente?.replaceAll(RegExp(r'\D'), '');
    if (tel != null && tel.isNotEmpty) {
      final uri = Uri.parse('tel:$tel');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ligar para Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          _telefoneCliente != null && _telefoneCliente!.isNotEmpty
              ? 'Telefone da cliente: $_telefoneCliente'
              : 'O número de telefone da cliente $_nomeCliente não está disponível no momento. Utilize o chat para conversar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: _azul, fontWeight: FontWeight.bold)),
          ),
          if (_telefoneCliente == null || _telefoneCliente!.isEmpty)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _abrirChat();
              },
              style: FilledButton.styleFrom(backgroundColor: _azul),
              child: const Text('Abrir Chat'),
            ),
        ],
      ),
    );
  }

  Future<void> _iniciarRota() async {
    final enderecoBusca = Uri.encodeComponent('$_enderecoLinha1, $_enderecoLinha2');
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$enderecoBusca');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o aplicativo de mapas';
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navegando para: $_enderecoLinha1'),
          backgroundColor: _azul,
        ),
      );
    }
  }

  void _salvarNaAgenda() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Serviço agendado para $_dataExibicao às $_horaExibicao salvo na sua agenda!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _relatarImprevisto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _cinzaBorda,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Relatar Imprevisto',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textoEscuro,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Selecione o motivo ou descreva o que ocorreu para atualizarmos o cliente:',
                style: TextStyle(color: _textoMuted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              ...[
                'Trânsito intenso / Atraso no trajeto',
                'Cliente ausente ou não atende',
                'Problema no veículo / transporte',
                'Necessidade de ferramenta ou peça adicional',
                'Outro imprevisto',
              ].map(
                (motivo) => InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Imprevisto registrado: "$motivo". Notificando cliente.'),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _fundoCinza,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cinzaBorda),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            motivo,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textoEscuro,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: _textoMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _carregando && widget.solicitacao == null
                    ? const Center(child: CircularProgressIndicator(color: _azul))
                    : _erro != null && widget.solicitacao == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _erro!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: _textoMuted),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: _carregarDadosCompletos,
                                    style: FilledButton.styleFrom(backgroundColor: _azul),
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                        color: _azul,
                        onRefresh: _carregarDadosCompletos,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.recemAceito) ...[
                                _buildCardConfirmacaoAceite(),
                                const SizedBox(height: 14),
                              ],
                              _buildCardAndamentoPedido(),
                              const SizedBox(height: 14),
                              _buildCardPerfilCliente(),
                              const SizedBox(height: 14),
                              _buildCardServicoSelecionado(),
                              const SizedBox(height: 14),
                              _buildCardModalidadeAtendimento(),
                              const SizedBox(height: 14),
                              _buildCardsAgendamento(),
                              const SizedBox(height: 14),
                              _buildCardLocalizacao(),
                              const SizedBox(height: 14),
                              _buildCardEstimativaCombinada(),
                              if (_modalidade == ModalidadeExecucao.recebaEmCasa) ...[
                                const SizedBox(height: 14),
                                _buildCardChecklistEspecialista(),
                              ],
                              const SizedBox(height: 20),
                              _buildBotoesAcao(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. HEADER
  // ==========================================
  Widget _buildHeader() {
    final titulo = _tituloServico.isNotEmpty ? _tituloServico : _categoriaTitulo;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _azul, size: 26),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: _azul,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _navegarParaPerfilLogado,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _azul,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _azul.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: _fotoPerfilLogado != null && _fotoPerfilLogado!.isNotEmpty
                    ? Image.network(
                        _fotoPerfilLogado!,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _iconeAvatarLogadoFallback(),
                      )
                    : _iconeAvatarLogadoFallback(),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _iconeAvatarLogadoFallback() {
    if (_nomePerfilLogado != null && _nomePerfilLogado!.isNotEmpty) {
      return Center(
        child: Text(
          obterIniciais(_nomePerfilLogado!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const Icon(Icons.person, color: Colors.white, size: 22);
  }

  // ==========================================
  // 2. CARD DE CONFIRMAÇÃO DE ACEITE
  // ==========================================
  Widget _buildCardConfirmacaoAceite() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _azul.withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _azul.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _azul,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 7),
                          SizedBox(width: 5),
                          Text(
                            'Confirmado',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _codigoPedido,
                      style: const TextStyle(
                        color: _textoMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Você aceitou este serviço!',
                  style: TextStyle(
                    color: _textoEscuro,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A cliente $_nomeCliente foi notificada. Seu horário está reservado com exclusividade.',
                  style: const TextStyle(
                    color: _textoMuted,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. CARD DE ANDAMENTO DO PEDIDO
  // ==========================================
  Widget _buildCardAndamentoPedido() {
    late final List<String> etapas;
    late final List<IconData> icones;
    late final String instrucaoTexto;

    switch (_modalidade) {
      case ModalidadeExecucao.levaETraz:
        etapas = ['Aceito', 'Busca', 'Processo', 'Entrega', 'Concluído'];
        icones = [
          Icons.check,
          Icons.radio_button_checked,
          Icons.business_center_outlined,
          Icons.local_shipping_outlined,
          Icons.check_circle_outline,
        ];
        instrucaoTexto =
            'Você aceitou o pedido. O próximo passo é iniciar o deslocamento até o cliente para buscar o produto.';
        break;

      case ModalidadeExecucao.atendimentoDomicilio:
        etapas = ['Aceito', 'Deslocamento', 'No Local', 'Concluído'];
        icones = [
          Icons.check,
          Icons.radio_button_checked,
          Icons.business_center_outlined,
          Icons.check_circle_outline,
        ];
        instrucaoTexto =
            'Você aceitou o pedido. O próximo passo é iniciar o deslocamento até o cliente para cumprir o horário agendado.';
        break;

      case ModalidadeExecucao.retiradaNoLocal:
        etapas = ['Aceito', 'Cliente', 'Processo', 'Cliente', 'Concluído'];
        icones = [
          Icons.check,
          Icons.radio_button_checked,
          Icons.business_center_outlined,
          Icons.local_shipping_outlined,
          Icons.check_circle_outline,
        ];
        instrucaoTexto =
            'Você aceitou o pedido. O próximo passo é aguardar o cliente para receber o produto.';
        break;

      case ModalidadeExecucao.recebaEmCasa:
        etapas = ['Aceito', 'Cliente', 'Processo', 'Entrega', 'Concluído'];
        icones = [
          Icons.check,
          Icons.radio_button_checked,
          Icons.business_center_outlined,
          Icons.local_shipping_outlined,
          Icons.check_circle_outline,
        ];
        instrucaoTexto =
            'Você aceitou o pedido. O próximo passo é aguardar o cliente para receber o produto.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          const Row(
            children: [
              Icon(Icons.show_chart, color: _textoEscuro, size: 22),
              SizedBox(width: 8),
              Text(
                'Andamento do Pedido',
                style: TextStyle(
                  color: _textoEscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Stepper Horizontal com alinhamento perfeito de linhas e círculos
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(etapas.length, (index) {
              final isFirst = index == 0;
              final isLast = index == etapas.length - 1;
              final isDone = index == 0; // Aceito
              final isCurrent = index == 1; // Próximo passo
              final isLineDone = index == 0; // Linha entre Aceito e próximo passo em azul

              return Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Linhas de conexão que tocam exatamente os círculos e ficam perfeitamente centralizadas
                          Row(
                            children: [
                              Expanded(
                                child: isFirst
                                    ? const SizedBox()
                                    : Container(
                                        height: 3,
                                        color: index == 1
                                            ? _azul
                                            : const Color(0xFFCBD5E1),
                                      ),
                              ),
                              const SizedBox(width: 36),
                              Expanded(
                                child: isLast
                                    ? const SizedBox()
                                    : Container(
                                        height: 3,
                                        color: isLineDone
                                            ? _azul
                                            : const Color(0xFFCBD5E1),
                                      ),
                              ),
                            ],
                          ),
                          // Círculo com animação sonar no passo atual (em azul)
                          if (isDone)
                            _buildCirculoSonar(icones[index])
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrent
                                    ? Colors.white
                                    : const Color(0xFFF1F5F9),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFFCBD5E1),
                                  width: isCurrent ? 2.5 : 1.5,
                                ),
                              ),
                              child: Icon(
                                icones[index],
                                size: 18,
                                color: isCurrent ? _textoEscuro : _textoMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etapas[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                        color: isDone ? _azul : _textoMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Caixa cinza de instruções
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cinzaCardInterno,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline, color: _textoEscuro, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    instrucaoTexto,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCirculoSonar(IconData icone) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _sonarAnimation,
            builder: (context, _) {
              final val = _sonarAnimation.value;
              final ringSize = 36.0 + (val * 14.0);
              final opacity = ((1.0 - val) * 0.6).clamp(0.0, 1.0);
              return Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _azul.withValues(alpha: opacity),
                    width: 2.0,
                  ),
                  color: _azul.withValues(alpha: opacity * 0.25),
                ),
              );
            },
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _azul,
            ),
            child: Icon(icone, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. CARD DE PERFIL DO CLIENTE
  // ==========================================
  Widget _buildCardPerfilCliente() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            children: [
              Stack(
                children: [
                  ClipOval(
                    child: _fotoCliente != null && _fotoCliente!.isNotEmpty
                        ? Image.network(
                            _fotoCliente!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarFallback(_nomeCliente),
                          )
                        : _avatarFallback(_nomeCliente),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _azul,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nomeCliente,
                      style: const TextStyle(
                        color: _textoEscuro,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _modeloEquipamento.isNotEmpty
                          ? _modeloEquipamento
                          : _tituloServico,
                      style: const TextStyle(
                        color: _textoMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _abrirChat,
                    icon: const Icon(Icons.chat_bubble_outline, color: _azul, size: 18),
                    label: const Text(
                      'Conversar no Chat',
                      style: TextStyle(
                        color: _azul,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _azul, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _ligarCliente,
                    icon: const Icon(Icons.phone_outlined, color: _textoEscuro, size: 18),
                    label: const Text(
                      'Ligar para Cliente',
                      style: TextStyle(
                        color: _textoEscuro,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String nome) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _azul,
        shape: BoxShape.circle,
      ),
      child: Text(
        obterIniciais(nome),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // 5. CARD DE SERVIÇO SELECIONADO
  // ==========================================
  Widget _buildCardServicoSelecionado() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.toys_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SERVIÇO SELECIONADO',
                      style: TextStyle(
                        color: _textoMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tituloServico,
                      style: const TextStyle(
                        color: _textoEscuro,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, color: _textoMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_quantidadeAnexos anexo${_quantidadeAnexos > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: _textoMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_relatoCliente.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cinzaCardInterno,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '“$_relatoCliente”',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 13.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: _imagemAnexoUrl != null && _imagemAnexoUrl!.isNotEmpty
                      ? Image.network(
                          _imagemAnexoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imagemAnexoFallback(),
                        )
                      : _imagemAnexoFallback(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Foto anexada pela cliente ($_legendaAnexo)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagemAnexoFallback() {
    return Container(
      color: const Color(0xFFCBD5E1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_circle_outlined, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(
              _tituloServico,
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 6. CARD DE MODALIDADE DE ATENDIMENTO
  // ==========================================
  Widget _buildCardModalidadeAtendimento() {
    late final IconData iconeModalidade;
    late final String tituloModalidade;
    late final String descricaoModalidade;
    final bool mostrarTaxaDeslocamento =
        _modalidade == ModalidadeExecucao.levaETraz ||
        _modalidade == ModalidadeExecucao.atendimentoDomicilio;

    switch (_modalidade) {
      case ModalidadeExecucao.levaETraz:
        iconeModalidade = Icons.local_shipping_outlined;
        tituloModalidade = 'Leva e Traz';
        descricaoModalidade =
            'O profissional irá buscar o produto e depois entregá-lo de volta ao cliente.';
        break;

      case ModalidadeExecucao.atendimentoDomicilio:
        iconeModalidade = Icons.business_center_outlined;
        tituloModalidade = 'Atendimento no Local\n(Presencial / Em Domicílio)';
        descricaoModalidade =
            'O profissional irá até o endereço cadastrado pelo cliente para realizar a vistoria técnica, diagnóstico presencial e conserto do equipamento.';
        break;

      case ModalidadeExecucao.retiradaNoLocal:
        iconeModalidade = Icons.storefront_outlined;
        tituloModalidade = 'Retirada no Local';
        descricaoModalidade =
            'O cliente irá trazer o produto até você e depois irá buscá-lo de volta.';
        break;

      case ModalidadeExecucao.recebaEmCasa:
        iconeModalidade = Icons.home_outlined;
        tituloModalidade = 'Receba em casa';
        descricaoModalidade =
            'O cliente irá trazer o produto até você e depois você irá entregar o produto no endereço do cliente.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconeModalidade, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MODALIDADE DE ATENDIMENTO',
                      style: TextStyle(
                        color: _textoMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tituloModalidade,
                      style: const TextStyle(
                        color: _textoEscuro,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Inclusa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cinzaCardInterno,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              descricaoModalidade,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (mostrarTaxaDeslocamento) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: _azul, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Taxa de deslocamento inclusa na estimativa',
                    style: TextStyle(
                      color: _textoMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  'Presencial',
                  style: TextStyle(
                    color: _azul,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 7. CARDS DE AGENDAMENTO (DATA E HORÁRIO)
  // ==========================================
  Widget _buildCardsAgendamento() {
    return Row(
      children: [
        // Bloco de Data
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                const Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: _textoEscuro, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Data',
                      style: TextStyle(
                        color: _textoEscuro,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _dataExibicao,
                  style: const TextStyle(
                    color: _textoEscuro,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _periodoExibicao,
                  style: const TextStyle(
                    color: _textoMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Bloco de Horário
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                const Row(
                  children: [
                    Icon(Icons.access_time, color: _textoEscuro, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Horário',
                      style: TextStyle(
                        color: _textoEscuro,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _horaExibicao,
                  style: const TextStyle(
                    color: _textoEscuro,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _janelaExibicao,
                  style: const TextStyle(
                    color: _textoMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 8. SEÇÃO DE LOCALIZAÇÃO (ENDEREÇO + MAPA)
  // ==========================================
  Widget _buildCardLocalizacao() {
    final bool rotaIniciada =
        _modalidade == ModalidadeExecucao.levaETraz ||
        _modalidade == ModalidadeExecucao.atendimentoDomicilio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on, color: _azul, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _enderecoLinha1,
                      style: const TextStyle(
                        color: _textoEscuro,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _enderecoLinha2,
                      style: const TextStyle(
                        color: _textoMuted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _distanciaTexto,
            style: const TextStyle(
              color: Color(0xFF0369A1),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          // MAPA INTERATIVO COM FLUTTER_MAP
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 170,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _coordenadas,
                      initialZoom: 13.5,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'br.com.consertaja',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _coordenadas,
                            radius: 1200,
                            useRadiusInMeter: true,
                            color: _azul.withValues(alpha: 0.2),
                            borderColor: _azul,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _coordenadas,
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_pin,
                              color: _azul,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Overlay informativo sobre o mapa
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            rotaIniciada ? Icons.directions_car : Icons.info_outline,
                            size: 16,
                            color: _textoEscuro,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rotaIniciada
                                  ? _trajetoOverlayTexto
                                  : 'O cliente ainda não iniciou o trajeto',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _textoEscuro,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. CARD DE ESTIMATIVA COMBINADA
  // ==========================================
  Widget _buildCardEstimativaCombinada() {
    final bool mostrarTaxaVisita =
        _modalidade == ModalidadeExecucao.atendimentoDomicilio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimativa Combinada',
                style: TextStyle(
                  color: _textoMuted,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (mostrarTaxaVisita)
                const Text(
                  'Taxa de visita inclusa',
                  style: TextStyle(
                    color: _textoMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _valorExibicao,
                  style: const TextStyle(
                    color: _azul,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _metodoPagamento,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cinzaCardInterno,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.verified_user_outlined, color: _azul, size: 20),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pagamento garantido após sua conclusão técnica do serviço.',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 10. CHECKLIST DO ESPECIALISTA (Receba em casa)
  // ==========================================
  Widget _buildCardChecklistEspecialista() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Checklist do Especialista',
                style: TextStyle(
                  color: _textoEscuro,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _azul.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Recomendado',
                  style: TextStyle(
                    color: _azulEscuro,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._checklistItens.map((item) {
            return InkWell(
              onTap: () {
                setState(() => item.marcado = !item.marcado);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: item.marcado,
                        activeColor: _azul,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() => item.marcado = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: item.marcado ? FontWeight.w700 : FontWeight.w500,
                          color: item.marcado ? _textoEscuro : _textoMuted,
                          decoration: item.marcado ? TextDecoration.none : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 11. BOTÕES DE AÇÃO INFERIORES
  // ==========================================
  Widget _buildBotoesAcao() {
    late final Widget botaoPrincipal;

    switch (_modalidade) {
      case ModalidadeExecucao.levaETraz:
      case ModalidadeExecucao.atendimentoDomicilio:
        botaoPrincipal = SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _iniciarRota,
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text(
              'Iniciar Deslocamento / Rota',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
          ),
        );
        break;

      case ModalidadeExecucao.retiradaNoLocal:
        botaoPrincipal = SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aguardando cliente se deslocar até seu estabelecimento.'),
                  backgroundColor: _azul,
                ),
              );
            },
            icon: const Icon(Icons.hourglass_top_outlined, size: 20),
            label: const Text(
              'Aguarde o cliente iniciar o trajeto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
          ),
        );
        break;

      case ModalidadeExecucao.recebaEmCasa:
        botaoPrincipal = SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aguardando o cliente realizar a entrega do item.'),
                  backgroundColor: _azul,
                ),
              );
            },
            icon: const Icon(Icons.hourglass_top_outlined, size: 20),
            label: const Text(
              'Aguarde a entrega do cliente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
          ),
        );
        break;
    }

    return Column(
      children: [
        botaoPrincipal,
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _salvarNaAgenda,
                  icon: const Icon(Icons.calendar_today_outlined, color: _textoEscuro, size: 18),
                  label: const Text(
                    'Salvar na Agenda',
                    style: TextStyle(
                      color: _textoEscuro,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _relatarImprevisto,
                  icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                  label: const Text(
                    'Relatar Imprevisto',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
