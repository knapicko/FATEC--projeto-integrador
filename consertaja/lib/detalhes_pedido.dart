// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'meus_pedidos.dart';
import 'pagamento_pedido.dart';
import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'perguntas_frequentes.dart';
import 'tela_chat_profissional.dart';
import 'utils/iniciais.dart';
import 'widgets/avaliacao_bottom_sheet.dart';
import 'widgets/skeleton_loading.dart';

class DetalhesPedidoPage extends StatefulWidget {
  final int idSolicitacao;
  final PedidoCliente? pedidoResumo;

  const DetalhesPedidoPage({
    super.key,
    required this.idSolicitacao,
    this.pedidoResumo,
  });

  @override
  State<DetalhesPedidoPage> createState() => _DetalhesPedidoPageState();
}

class _EtapaVisualConfig {
  final String titulo;
  final IconData icone;
  final Color corFundo;
  final Color corIcone;
  final Color corTexto;
  final bool temSonar;
  final bool concluida;

  const _EtapaVisualConfig({
    required this.titulo,
    required this.icone,
    required this.corFundo,
    required this.corIcone,
    required this.corTexto,
    this.temSonar = false,
    this.concluida = false,
  });
}

class _DetalhesPedidoPageState extends State<DetalhesPedidoPage>
    with SingleTickerProviderStateMixin {
  static const Color azulPrincipal = Color(0xFF0FB3FF);
  static const Color azulFundoCard = Color(0xFFE0F2FE);
  static const Color fundoTela = Color(0xFFF6F8FB);
  static const Color textoEscuro = Color(0xFF0F172A);
  static const Color textoMuted = Color(0xFF64748B);
  static const Color laranjaEspera = Color(0xFFFB9263);

  final SupabaseClient _db = Supabase.instance.client;
  late final AnimationController _sonarController;

  bool _carregando = true;
  bool _carregandoCliente = true;
  bool _confirmandoConclusao = false;
  bool _avaliadoCliente = false;
  List<Map<String, dynamic>> _avaliacoesCliente = [];
  String? _erro;

  // Dados da Solicitação
  int _idSolicitacao = 0;
  String _codigoPedido = '';
  DateTime? _dataSolicitacao;
  DateTime? _dataFinalizacao;
  double _valorFinal = 0.0;
  String _tipoExecucao = 'Leva e Traz';
  String _detalhesObs = '';
  String? _dataAgendada;
  String? _horaAgendada;
  String? _horaAgendadaFim;
  int _etapaSolicitacao = 0;
  int _fkStatus = 1;
  String _statusTexto = 'Aberto';

  // Usuário Cliente Logado
  String? _fotoClienteLogado;
  String _nomeClienteLogado = '';
  int? _idUsuarioClienteLogado;

  // Prestador (Loja ou Profissional Independente)
  bool _ehLoja = false;
  int? _idGrupoEmpresa;
  int? _idProfissional;
  String _nomePrestador = 'Profissional';
  String? _fotoPrestador;
  String? _tagPrestador;
  String? _corTagPrestador;
  String? _categoriaPrestador;
  String _enderecoPrestador = '';

  // Endereço do Cliente
  String _enderecoCliente = '';

  // Serviço Selecionado
  String _tituloServico = 'Serviço';
  String? _imagemServico;
  double _valorServico = 0.0;
  String? _oficioFuncao;

  // Anexos da Solicitação
  List<Map<String, dynamic>> _anexos = [];

  bool get _podeCancelar {
    final s = _statusTexto.trim().toLowerCase();
    return s == 'aberto' ||
        s == 'aceito' ||
        s == 'novo' ||
        s == 'pendente' ||
        _fkStatus == 1 ||
        _fkStatus == 31;
  }

  @override
  void initState() {
    super.initState();
    _idSolicitacao = widget.idSolicitacao;
    _codigoPedido = '#PED-2026-${_idSolicitacao.toString().padLeft(4, '0')}';
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _carregarDadosCompletos();
  }

  @override
  void dispose() {
    _sonarController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosCompletos() async {
    setState(() {
      _carregando = true;
      _carregandoCliente = true;
      _erro = null;
    });

    try {
      // 1. Cliente logado
      final authUser = _db.auth.currentUser;
      if (authUser != null) {
        try {
          final uRow = await _db
              .from('usuarios')
              .select('id_usuario, nome, foto_perfil_url')
              .eq('auth_id', authUser.id)
              .maybeSingle();
          if (uRow != null) {
            _nomeClienteLogado = uRow['nome']?.toString() ?? '';
            _fotoClienteLogado = uRow['foto_perfil_url']?.toString();
            _idUsuarioClienteLogado = (uRow['id_usuario'] as num?)?.toInt();
          }
        } catch (_) {}
      }
      _carregandoCliente = false;

      // 2. Solicitação
      final sol = await _db
          .from('solicitacoes')
          .select('*')
          .eq('id_solicitacao', _idSolicitacao)
          .maybeSingle();

      if (sol == null) {
        throw Exception('Solicitação não encontrada');
      }

      _dataSolicitacao = sol['data_solicitacao'] != null
          ? DateTime.tryParse(sol['data_solicitacao'].toString())?.toLocal()
          : null;
      _dataFinalizacao = sol['data_finalizacao'] != null
          ? DateTime.tryParse(sol['data_finalizacao'].toString())?.toLocal()
          : null;
      _valorFinal =
          (sol['valor_final'] as num?)?.toDouble() ??
          widget.pedidoResumo?.valor ??
          0.0;
      _tipoExecucao =
          sol['tipo_execucao']?.toString().trim() ??
          widget.pedidoResumo?.titulo ??
          'Leva e Traz';
      if (_tipoExecucao.isEmpty) _tipoExecucao = 'Leva e Traz';

      _detalhesObs = (sol['detalhes'] ?? '').toString().trim();
      _dataAgendada = sol['data_agendada']?.toString();
      _horaAgendada = sol['hora_agendada']?.toString();
      _horaAgendadaFim = sol['hora_agendada_fim']?.toString();

      _etapaSolicitacao = (sol['etapa_solicitacao'] as num?)?.toInt() ?? 0;
      _fkStatus = (sol['fk_status'] as num?)?.toInt() ?? 1;

      // Buscar texto do status na tabela 'status'
      try {
        final stRow = await _db
            .from('status')
            .select('status')
            .eq('id_status', _fkStatus)
            .maybeSingle();
        if (stRow != null && stRow['status'] != null) {
          _statusTexto = stRow['status'].toString();
        } else if (widget.pedidoResumo?.status != null) {
          _statusTexto = widget.pedidoResumo!.status;
        }
      } catch (_) {
        if (widget.pedidoResumo?.status != null) {
          _statusTexto = widget.pedidoResumo!.status;
        }
      }

      if (_statusTexto.trim().toLowerCase() == 'em andamento' &&
          _etapaSolicitacao < 3) {
        _etapaSolicitacao = 3;
      }

      _avaliadoCliente = false;
        _avaliacoesCliente = [];
      if (_idUsuarioClienteLogado != null) {
        try {
          final avaliacoes = await _db
              .from('avaliacoes_solicitacao')
            .select('tipo_avaliacao, nota, comentario')
              .eq('fk_solicitacao', _idSolicitacao)
              .eq('fk_avaliador', _idUsuarioClienteLogado!)
              .inFilter('tipo_avaliacao', ['servico', 'profissional']);
          _avaliacoesCliente = List<Map<String, dynamic>>.from(avaliacoes);
          final tipos = _avaliacoesCliente
              .map((row) => row['tipo_avaliacao']?.toString())
              .toSet();
          _avaliadoCliente =
              tipos.contains('servico') && tipos.contains('profissional');
        } catch (_) {}
      }

      final fkProf = (sol['fk_profissional'] as num?)?.toInt();
      final fkGrupo = (sol['fk_grupo_empresa'] as num?)?.toInt();
      _idGrupoEmpresa = fkGrupo;
      _idProfissional = fkProf;

      // 3. Prestador de serviço (Loja ou Profissional independente)
      if (fkGrupo != null && fkGrupo > 0) {
        _ehLoja = true;
        try {
          final gRow = await _db
              .from('grupo_empresa')
              .select('*')
              .eq('id_grupo_empresa', fkGrupo)
              .maybeSingle();
          if (gRow != null) {
            _nomePrestador = (gRow['nome_empresa'] ?? 'Empresa').toString();
            _fotoPrestador = gRow['foto_url_empresa']?.toString();
            _tagPrestador = gRow['tag_empresa']?.toString();
            _corTagPrestador = gRow['cor_tag_empresa']?.toString();
            _categoriaPrestador = gRow['descricao_empresa']?.toString();
          }
        } catch (_) {}

        _enderecoPrestador = await _buscarEnderecoLoja(fkGrupo);
      } else if (fkProf != null && fkProf > 0) {
        _ehLoja = false;
        try {
          final pRow = await _db
              .from('dados_profissionais')
              .select('id_profissional, fk_usuario, fk_grupo_empresa')
              .eq('id_profissional', fkProf)
              .maybeSingle();

          final idU = (pRow?['fk_usuario'] as num?)?.toInt();
          if (idU != null) {
            final uRow = await _db
                .from('usuarios')
                .select('nome, foto_perfil_url')
                .eq('id_usuario', idU)
                .maybeSingle();
            if (uRow != null) {
              _nomePrestador = (uRow['nome'] ?? 'Profissional').toString();
              _fotoPrestador = uRow['foto_perfil_url']?.toString();
            }
          }
        } catch (_) {}

        _enderecoPrestador = await _buscarEnderecoProfissional(fkProf);
      }

      // Se ainda não tiver foto ou nome do prestador, aproveita do resumo
      if (widget.pedidoResumo != null) {
        if (_nomePrestador == 'Profissional' &&
            widget.pedidoResumo!.prestador.isNotEmpty) {
          _nomePrestador = widget.pedidoResumo!.prestador;
        }
        _fotoPrestador ??= widget.pedidoResumo!.fotoPrest;
        _tagPrestador ??= widget.pedidoResumo!.tagEmp;
        _corTagPrestador ??= widget.pedidoResumo!.corTag;
        _categoriaPrestador ??= widget.pedidoResumo!.funcao;
      }

      // 4. Endereço do Cliente
      final fkEndCliente = (sol['fk_endereco'] as num?)?.toInt();
      if (fkEndCliente != null) {
        _enderecoCliente = await _formatarEnderecoPorId(fkEndCliente);
      }
      if (_enderecoCliente.isEmpty) {
        final idUsuarioCliente = (sol['fk_usuario'] as num?)?.toInt();
        if (idUsuarioCliente != null) {
          _enderecoCliente = await _buscarEnderecoPadraoCliente(
            idUsuarioCliente,
          );
        }
      }
      if (_enderecoCliente.isEmpty) {
        _enderecoCliente = 'Endereço não informado pelo cliente';
      }

      // 5. Serviço Selecionado
      final fkServProf = (sol['fk_servico_prof'] as num?)?.toInt();
      final fkServTemp = (sol['fk_servico_temp'] as num?)?.toInt();

      if (fkServProf != null) {
        try {
          final sRow = await _db
              .from('servicos_profissional')
              .select('titulo, descricao, valor, imagem_url, fk_oficios')
              .eq('id_servico_prof', fkServProf)
              .maybeSingle();
          if (sRow != null) {
            _tituloServico = (sRow['titulo'] ?? 'Serviço').toString();
            _imagemServico = sRow['imagem_url']?.toString();
            _valorServico = (sRow['valor'] as num?)?.toDouble() ?? _valorFinal;
            final fkOf = (sRow['fk_oficios'] as num?)?.toInt();
            if (fkOf != null) {
              final ofRow = await _db
                  .from('oficios')
                  .select('funcao, categoria, cod_cor')
                  .eq('id_oficio', fkOf)
                  .maybeSingle();
              if (ofRow != null) {
                _oficioFuncao = ofRow['funcao']?.toString();
                _categoriaPrestador ??=
                    ofRow['categoria']?.toString() ??
                    ofRow['funcao']?.toString();
              }
            }
          }
        } catch (_) {}
      } else if (fkServTemp != null) {
        try {
          final sRow = await _db
              .from('servicos_chat_temporario')
              .select('titulo, descricao, valor, imagem_url, fk_oficios')
              .eq('id_servico_temp', fkServTemp)
              .maybeSingle();
          if (sRow != null) {
            _tituloServico = (sRow['titulo'] ?? 'Serviço').toString();
            _imagemServico = sRow['imagem_url']?.toString();
            _valorServico = (sRow['valor'] as num?)?.toDouble() ?? _valorFinal;
          }
        } catch (_) {}
      }

      if (_tituloServico == 'Serviço' && widget.pedidoResumo != null) {
        _tituloServico = widget.pedidoResumo!.titulo;
        _imagemServico ??= widget.pedidoResumo!.img;
        _valorServico = widget.pedidoResumo!.valor;
      }
      if (_valorServico <= 0) {
        _valorServico = _valorFinal;
      }

      // 6. Anexos da Solicitação (reais do banco de dados)
      try {
        final rows = await _db
            .from('solicitacoes_anexos')
            .select('*')
            .eq('fk_solicitacao', _idSolicitacao)
            .order('ordem', ascending: true);
        _anexos = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}

      if (mounted) {
        setState(() => _carregando = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar detalhes: $e';
          _carregando = false;
        });
      }
    }
  }

  Future<String> _buscarEnderecoPadraoCliente(int idUsuario) async {
    try {
      final vinculos = await _db
          .from('ass_usuario_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_usuario', idUsuario);
      int? fkEnd;
      for (final v in vinculos) {
        if (v['endereco_ativo'] == true) {
          fkEnd = (v['fk_endereco'] as num?)?.toInt();
          break;
        }
      }
      fkEnd ??= (vinculos.firstOrNull?['fk_endereco'] as num?)?.toInt();
      if (fkEnd != null) {
        return await _formatarEnderecoPorId(fkEnd);
      }
    } catch (_) {}
    return '';
  }

  Future<String> _buscarEnderecoLoja(int idGrupo) async {
    try {
      final vinculos = await _db
          .from('ass_grupo_empresa_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_grupo_empresa', idGrupo);
      int? fkEnd;
      for (final v in vinculos) {
        if (v['endereco_ativo'] == true) {
          fkEnd = (v['fk_endereco'] as num?)?.toInt();
          break;
        }
      }
      fkEnd ??= (vinculos.firstOrNull?['fk_endereco'] as num?)?.toInt();
      if (fkEnd != null) {
        final endFormatado = await _formatarEnderecoPorId(fkEnd);
        if (endFormatado.trim().isNotEmpty) {
          return endFormatado;
        }
      }
    } catch (_) {}
    return 'O profissional não possui um endereço cadastrado';
  }

  Future<String> _buscarEnderecoProfissional(int idProfissional) async {
    try {
      final vinculos = await _db
          .from('ass_profissional_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_profissional', idProfissional);
      int? fkEnd;
      for (final v in vinculos) {
        if (v['endereco_ativo'] == true) {
          fkEnd = (v['fk_endereco'] as num?)?.toInt();
          break;
        }
      }
      fkEnd ??= (vinculos.firstOrNull?['fk_endereco'] as num?)?.toInt();
      if (fkEnd != null) {
        final endFormatado = await _formatarEnderecoPorId(fkEnd);
        if (endFormatado.trim().isNotEmpty) {
          return endFormatado;
        }
      }
    } catch (_) {}
    return 'O profissional não possui um endereço cadastrado';
  }

  Future<String> _formatarEnderecoPorId(int idEndereco) async {
    try {
      final end = await _db
          .from('enderecos')
          .select('logradouro, numero, complemento, bairro, cep, fk_cidade')
          .eq('id_endereco', idEndereco)
          .maybeSingle();
      if (end != null) {
        final log = end['logradouro']?.toString().trim() ?? '';
        final numStr = end['numero']?.toString().trim() ?? 'S/N';
        final comp = end['complemento']?.toString().trim() ?? '';
        final bai = end['bairro']?.toString().trim() ?? '';
        final cep = end['cep']?.toString().trim() ?? '';

        var cidNome = 'São Paulo';
        var estSigla = 'SP';
        final idCid = (end['fk_cidade'] as num?)?.toInt();
        if (idCid != null) {
          final cid = await _db
              .from('cidades')
              .select('nome_cidade, fk_estado')
              .eq('id_cidade', idCid)
              .maybeSingle();
          if (cid != null) {
            cidNome = cid['nome_cidade']?.toString().trim() ?? cidNome;
            final idEst = (cid['fk_estado'] as num?)?.toInt();
            if (idEst != null) {
              final est = await _db
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

        final linha1 = comp.isNotEmpty
            ? '$log, $numStr - $comp'
            : '$log, $numStr';
        final linha2 = bai.isNotEmpty
            ? '$bai - $cidNome - $estSigla'
            : '$cidNome - $estSigla';
        final cepStr = cep.isNotEmpty ? ' • CEP $cep' : '';
        return '$linha1\n$linha2$cepStr';
      }
    } catch (_) {}
    return '';
  }

  // ===========================================================================
  // Regras de Situação do Pedido
  // ===========================================================================
  ({String titulo, String subtitulo}) _obterSituacaoPedido() {
    final s = _statusTexto.trim().toLowerCase();
    final modalidade = _tipoExecucao.trim().toLowerCase();

    final isDomicilioOuLeva =
        modalidade.contains('domic') ||
        (modalidade.contains('leva') && modalidade.contains('traz'));
    final isRetiradaOuReceba =
        modalidade.contains('retirad') ||
        (modalidade.contains('receba') && modalidade.contains('casa'));

    if (s.contains('cancel')) {
      return (titulo: 'Pedido cancelado', subtitulo: 'O pedido foi cancelado');
    }
    if (s.contains('recus')) {
      return (
        titulo: 'Pedido recusado',
        subtitulo: 'O profissional recusou sua solicitação',
      );
    }
    if (s.contains('conclu') || s.contains('finaliz')) {
      String dataFmt = '';
      if (_dataFinalizacao != null) {
        dataFmt =
            ' no dia ${_dataFinalizacao!.day.toString().padLeft(2, '0')}/${_dataFinalizacao!.month.toString().padLeft(2, '0')}/${_dataFinalizacao!.year}';
      }
      return (
        titulo: 'Pedido concluído',
        subtitulo: 'O serviço foi concluído$dataFmt',
      );
    }
    if (s.contains('andamento') || s.contains('execu')) {
      if (isDomicilioOuLeva && _etapaSolicitacao == 1) {
        return (
          titulo: 'Pedido em andamento',
          subtitulo: 'O profissional está a caminho do seu endereço',
        );
      }
      if (isRetiradaOuReceba && _etapaSolicitacao == 1) {
        return (
          titulo: 'Pedido em andamento',
          subtitulo: 'O profissional está aguardando você iniciar o trajeto',
        );
      }
      return (
        titulo: 'Pedido em andamento',
        subtitulo: 'O serviço está sendo realizado pelo profissional',
      );
    }
    if (s.contains('aguardando cliente')) {
      return (
        titulo: 'Aguardando cliente',
        subtitulo: 'Confirme a entrega ou a conclusão do serviço',
      );
    }
    if (s == 'pago') {
      return (titulo: 'Pedido pago', subtitulo: 'O seu pagamento foi validado');
    }
    if (s.contains('pagamento')) {
      return (
        titulo: 'Pagamento em processo',
        subtitulo: 'Aguarde enquanto processamos o seu pagamento',
      );
    }
    if (s.contains('aceito') || s.contains('aprovado')) {
      return (
        titulo: 'Pedido aceito',
        subtitulo: 'O profissional aceitou sua solicitação',
      );
    }
    if (s.contains('aberto') || s.contains('pendente') || s.contains('novo')) {
      return (
        titulo: 'Pedido em avaliação',
        subtitulo: 'Aguardando a resposta do profissional',
      );
    }

    return (
      titulo: 'Pedido em avaliação',
      subtitulo: 'Aguardando a resposta do profissional',
    );
  }

  // ===========================================================================
  // Regras das Etapas por Modalidade de Execução
  // ===========================================================================
  List<_EtapaVisualConfig> _gerarEtapas() {
    final mod = _tipoExecucao.trim().toLowerCase();

    if (mod.contains('domic')) {
      return _gerarEtapasDomicilio();
    } else if (mod.contains('receba') && mod.contains('casa')) {
      return _gerarEtapasRecebaEmCasa();
    } else if (mod.contains('retirad') ||
        (mod.contains('retirada') && mod.contains('local'))) {
      return _gerarEtapasRetiradaNoLocal();
    } else {
      return _gerarEtapasLevaETraz();
    }
  }

  /// 1. Atendimento em Domicílio (4 etapas)
  List<_EtapaVisualConfig> _gerarEtapasDomicilio() {
    final e = _etapaSolicitacao;
    final st = _fkStatus;

    late _EtapaVisualConfig etapa1;
    if (e >= 1 || st >= 31) {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Aceito',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Solicitado',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa2;
    if (e > 2 || (e == 2 && st == 34) || st == 4 || st == 6) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'No local',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 2 && st == 33) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.two_wheeler,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 1 && st == 32) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.two_wheeler,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa3;
    if (e >= 4 && st == 6) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 3 && st == 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 3 && st == 34) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa4;
    if (e >= 4 && st == 6) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Conclusão',
        icone: Icons.check_circle_outline,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    return [etapa1, etapa2, etapa3, etapa4];
  }

  /// 2. Leva e Traz (5 etapas)
  List<_EtapaVisualConfig> _gerarEtapasLevaETraz() {
    final e = _etapaSolicitacao;
    final st = _fkStatus;

    late _EtapaVisualConfig etapa1;
    if (e >= 1 || st >= 31) {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Aceito',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Solicitado',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa2;
    if (e > 2 || (e == 2 && st == 34) || (e >= 3)) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'No local',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 2 && st == 33) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.two_wheeler,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 1 && st == 32) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Busca',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Busca',
        icone: Icons.two_wheeler,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa3;
    if (e > 3 || (e == 3 && st == 32) || e >= 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Serviço completo',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 3 && st == 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 3 && st == 34) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa4;
    if (e > 4 || (e == 4 && st == 34) || (e == 5 && st == 6)) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'No local',
        icone: Icons.person_outline,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 4 && st == 33) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.local_shipping_outlined,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 4 && st == 32) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Entrega',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Entrega',
        icone: Icons.local_shipping_outlined,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa5;
    if (e >= 5 && st == 6) {
      etapa5 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa5 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check_circle_outline,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    return [etapa1, etapa2, etapa3, etapa4, etapa5];
  }

  /// 3. Receba em Casa (5 etapas)
  List<_EtapaVisualConfig> _gerarEtapasRecebaEmCasa() {
    final e = _etapaSolicitacao;
    final st = _fkStatus;

    late _EtapaVisualConfig etapa1;
    if (e >= 1 || st >= 31) {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Aceito',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Solicitado',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa2;
    if (e > 2 || (e == 2 && st == 34) || e >= 3) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Produto recebido',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 2 && st == 33) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.two_wheeler,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 1 && st == 32) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Recebimento',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Recebimento',
        icone: Icons.two_wheeler,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa3;
    if (e > 3 || (e == 3 && st == 6) || e >= 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Serviço completo',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 3 && st == 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 3 && st == 34) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa4;
    if (e > 4 || (e == 4 && st == 34) || (e == 5 && st == 6)) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'No local',
        icone: Icons.person_outline,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 4 && st == 33) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Deslocamento',
        icone: Icons.local_shipping_outlined,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 4 && st == 32) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Entrega',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Entrega',
        icone: Icons.local_shipping_outlined,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa5;
    if (e >= 5 && st == 6) {
      etapa5 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa5 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check_circle_outline,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    return [etapa1, etapa2, etapa3, etapa4, etapa5];
  }

  /// 4. Retirada no Local (5 etapas)
  List<_EtapaVisualConfig> _gerarEtapasRetiradaNoLocal() {
    final e = _etapaSolicitacao;
    final st = _fkStatus;

    late _EtapaVisualConfig etapa1;
    if (e >= 1 || st >= 31) {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Aceito',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa1 = const _EtapaVisualConfig(
        titulo: 'Solicitado',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa2;
    if (e > 2 || (e == 2 && st == 34) || e >= 3) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Produto recebido',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 2 && st == 33) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'A caminho',
        icone: Icons.directions_walk,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 1 && st == 32) {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Entrega do produto',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa2 = const _EtapaVisualConfig(
        titulo: 'Entrega do produto',
        icone: Icons.directions_walk,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa3;
    if (e > 3 || (e == 3 && st == 6) || e >= 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Serviço completo',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 3 && st == 4) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 3 && st == 34) {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa3 = const _EtapaVisualConfig(
        titulo: 'Em andamento',
        icone: Icons.handyman_outlined,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa4;
    if (e > 4 || (e == 4 && st == 34) || (e == 5 && st == 6)) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'No local',
        icone: Icons.person_outline,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else if (e == 4 && st == 33) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'A caminho',
        icone: Icons.directions_walk,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        temSonar: true,
        concluida: false,
      );
    } else if (e == 4 && st == 32) {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Retirada',
        icone: Icons.hourglass_top_outlined,
        corFundo: laranjaEspera,
        corIcone: Colors.white,
        corTexto: laranjaEspera,
        concluida: false,
      );
    } else {
      etapa4 = const _EtapaVisualConfig(
        titulo: 'Retirada',
        icone: Icons.directions_walk,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    late _EtapaVisualConfig etapa5;
    if (e >= 5 && st == 6) {
      etapa5 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check,
        corFundo: azulPrincipal,
        corIcone: Colors.white,
        corTexto: azulPrincipal,
        concluida: true,
      );
    } else {
      etapa5 = const _EtapaVisualConfig(
        titulo: 'Concluído',
        icone: Icons.check_circle_outline,
        corFundo: Color(0xFFF1F5F9),
        corIcone: Color(0xFF94A3B8),
        corTexto: Color(0xFF64748B),
        concluida: false,
      );
    }

    return [etapa1, etapa2, etapa3, etapa4, etapa5];
  }

  // ===========================================================================
  // Navegação e Ações
  // ===========================================================================
  void _abrirChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: _nomePrestador,
          fotoProfissional: _fotoPrestador ?? '',
          oficioPrincipal: _categoriaPrestador ?? 'Atendimento',
          idProfissional: _ehLoja ? null : _idProfissional,
          idGrupoEmpresa: _ehLoja ? _idGrupoEmpresa : null,
          idSolicitacao: _idSolicitacao,
        ),
      ),
    );
  }

  void _abrirPerfilPrestador() {
    if (_ehLoja && _idGrupoEmpresa != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PerfilLoja(
            idGrupoEmpresa: _idGrupoEmpresa,
            nomeEmpresa: _nomePrestador,
            fotoUrlEmpresa: _fotoPrestador,
            tagEmpresa: _tagPrestador,
            corTagEmpresa: _corTagPrestador,
          ),
        ),
      );
    } else if (_idProfissional != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PerfilProfissionalPage(
            nomeInicial: _nomePrestador,
            imagemInicial: _fotoPrestador ?? '',
            idProfissional: _idProfissional,
            profissao: _categoriaPrestador ?? 'Profissional independente',
          ),
        ),
      );
    }
  }

  void _abrirAjuda() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PerguntasFrequentesPage()));
  }

  Future<void> _abrirPagamento() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PagamentoPedidoPage(
          idSolicitacao: _idSolicitacao,
          tituloServico: _tituloServico,
          profissional: _nomePrestador,
          valor: _valorFinal,
          dataAgendada: _dataAgendada,
          horaAgendada: _horaAgendada,
        ),
      ),
    );
    if (mounted) await _carregarDadosCompletos();
  }

  Future<void> _confirmarConclusao() async {
    if (_confirmandoConclusao ||
        _statusTexto.trim().toLowerCase() != 'aguardando cliente') {
      return;
    }
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF168A52),
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Confirmar conclusão?',
                style: TextStyle(
                  color: textoEscuro,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confirme que recebeu o serviço e que ele foi finalizado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textoMuted, fontSize: 14),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF168A52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Confirmar entrega/final'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Voltar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _confirmandoConclusao = true);
    try {
      await _db.rpc(
        'confirmar_conclusao_solicitacao',
        params: {'p_id_solicitacao': _idSolicitacao},
      );
      await _carregarDadosCompletos();
      if (mounted) await _avaliarPedidoCliente();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmandoConclusao = false);
    }
  }

  Future<void> _avaliarPedidoCliente() async {
    if (_avaliadoCliente ||
        !_statusTexto.trim().toLowerCase().contains('conclu')) {
      return;
    }
    final resposta = await mostrarAvaliacaoBottomSheet(
      context,
      avaliandoCliente: true,
    );
    if (resposta == null || !mounted) return;
    try {
      await _db.rpc(
        'registrar_avaliacoes_cliente',
        params: {
          'p_id_solicitacao': _idSolicitacao,
          'p_nota_servico': resposta.notaServico,
          'p_comentario_servico': resposta.comentarioServico,
          'p_nota_profissional': resposta.notaProfissional,
          'p_comentario_profissional': resposta.comentarioProfissional,
        },
      );
      if (mounted) {
        setState(() {
          _avaliadoCliente = true;
          _avaliacoesCliente = [
            {
              'tipo_avaliacao': 'servico',
              'nota': resposta.notaServico,
              'comentario': resposta.comentarioServico,
            },
            {
              'tipo_avaliacao': 'profissional',
              'nota': resposta.notaProfissional,
              'comentario': resposta.comentarioProfissional,
            },
          ];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avaliações enviadas. Obrigado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelarSolicitacao() async {
    if (!_podeCancelar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta solicitação não pode ser cancelada no momento.'),
        ),
      );
      return;
    }

    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cancelar solicitação?',
              style: TextStyle(
                color: textoEscuro,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta ação cancelará o serviço e apagará este pedido do sistema. Tem certeza de que deseja continuar?',
              textAlign: TextAlign.center,
              style: TextStyle(color: textoMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sim, cancelar e apagar pedido',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textoEscuro,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Voltar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      // Remove apenas os anexos e a solicitação. A conversa permanece intacta.
      await _db
          .from('solicitacoes_anexos')
          .delete()
          .eq('fk_solicitacao', _idSolicitacao);

      await _db
          .from('solicitacoes')
          .delete()
          .eq('id_solicitacao', _idSolicitacao);

      final solicitacaoRestante = await _db
          .from('solicitacoes')
          .select('id_solicitacao')
          .eq('id_solicitacao', _idSolicitacao)
          .maybeSingle();
      if (solicitacaoRestante != null) {
        throw Exception(
          'A solicitação não foi excluída. Verifique a política de exclusão no Supabase.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido cancelado e excluído com sucesso.'),
            backgroundColor: Colors.black87,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _compartilharPedido() {
    Clipboard.setData(
      ClipboardData(text: 'Pedido $_codigoPedido no ConsertaJá'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código do pedido copiado para a área de transferência!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatarDataSolicitacao() {
    if (_dataSolicitacao == null) return 'Solicitado recentemente';
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dataData = DateTime(
      _dataSolicitacao!.year,
      _dataSolicitacao!.month,
      _dataSolicitacao!.day,
    );

    final horaMin =
        '${_dataSolicitacao!.hour.toString().padLeft(2, '0')}:${_dataSolicitacao!.minute.toString().padLeft(2, '0')}';

    if (dataData == hoje) {
      return 'Solicitado hoje às $horaMin';
    } else if (dataData == hoje.subtract(const Duration(days: 1))) {
      return 'Solicitado ontem às $horaMin';
    } else {
      return 'Solicitado em ${_dataSolicitacao!.day.toString().padLeft(2, '0')}/${_dataSolicitacao!.month.toString().padLeft(2, '0')} às $horaMin';
    }
  }

  String _formatarDataAgendada() {
    if (_dataAgendada == null || _dataAgendada!.isEmpty) return 'A combinar';
    try {
      final d = DateTime.parse(_dataAgendada!);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return _dataAgendada!;
    }
  }

  String _formatarJanelaHoraria() {
    if (_horaAgendada == null || _horaAgendada!.isEmpty)
      return 'Horário comercial';
    final h1 = _horaAgendada!.length >= 5
        ? _horaAgendada!.substring(0, 5)
        : _horaAgendada!;
    final h2 = (_horaAgendadaFim != null && _horaAgendadaFim!.length >= 5)
        ? _horaAgendadaFim!.substring(0, 5)
        : '';
    return h2.isNotEmpty ? '$h1 - $h2' : h1;
  }

  String _formatarPreco(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final ip = parts[0];
    final b = StringBuffer();
    for (var i = 0; i < ip.length; i++) {
      final pos = ip.length - i;
      b.write(ip[i]);
      if (pos > 1 && pos % 3 == 1) b.write('.');
    }
    return 'R\$ ${b.toString()},${parts[1]}';
  }

  // ===========================================================================
  // Build Principal
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: fundoTela,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _carregando
                    ? const SkeletonPage(layout: SkeletonLayout.cards)
                    : _erro != null
                    ? _buildErro()
                    : _buildConteudo(),
              ),
              if (!_carregando && _erro == null) _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Cabeçalho com Voltar, Título, Pedido, Ajuda e Foto do Usuário
  // ===========================================================================
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: textoEscuro, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Detalhes Do Pedido',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textoEscuro,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _codigoPedido.isNotEmpty ? _codigoPedido : '#PED-2026-8491',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textoMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _abrirAjuda,
            icon: const Icon(Icons.help_outline, color: textoEscuro, size: 23),
            tooltip: 'Dúvidas',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // Foto de perfil do usuário cliente logado (somente azul puro enquanto carrega)
          GestureedAvatar(
            fotoUrl: _fotoClienteLogado,
            nome: _nomeClienteLogado,
            tamanho: 38,
            carregando: _carregandoCliente,
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _erro ?? 'Erro ao carregar detalhes',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: textoEscuro),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarDadosCompletos,
              style: ElevatedButton.styleFrom(backgroundColor: azulPrincipal),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Conteúdo Rolável
  // ===========================================================================
  Widget _buildConteudo() {
    return RefreshIndicator(
      color: azulPrincipal,
      onRefresh: _carregarDadosCompletos,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _buildCardSituacaoPedido(),
          const SizedBox(height: 14),
          _buildCardIdEtapas(),
          const SizedBox(height: 14),
          _buildCardOferecidoPor(),
          const SizedBox(height: 14),
          _buildCardServicoSelecionado(),
          const SizedBox(height: 14),
          _buildCardModalidadeServico(),
          const SizedBox(height: 14),
          _buildCardAgendamentoPrazos(),
          const SizedBox(height: 14),
          _buildCardObservacoesCliente(),
          const SizedBox(height: 14),
          _buildCardResumoValores(),
          if (_avaliacoesCliente.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCardAvaliacoesCliente(),
          ],
          const SizedBox(height: 20),
          _buildAcoesRodape(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. Card de Situação do Pedido (Card Destaque Azul Claro com Sino)
  // ===========================================================================
  Widget _buildCardSituacaoPedido() {
    final situacao = _obterSituacaoPedido();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: azulFundoCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: azulPrincipal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  situacao.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textoEscuro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  situacao.subtitulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: textoMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: textoMuted, size: 22),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. Card ID do Pedido e Etapas Animadas com Efeito Sonar
  // ===========================================================================
  Widget _buildCardIdEtapas() {
    final etapas = _gerarEtapas();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              _buildBadgeStatus(),
              IconButton(
                onPressed: _compartilharPedido,
                icon: const Icon(
                  Icons.share_outlined,
                  color: textoEscuro,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
                tooltip: 'Compartilhar',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Pedido $_codigoPedido',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textoEscuro,
                ),
              ),
              const SizedBox(width: 6),
              const Text('•', style: TextStyle(color: textoMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatarDataSolicitacao(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: textoMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStepperEtapas(etapas),
        ],
      ),
    );
  }

  Widget _buildBadgeStatus() {
    final s = _statusTexto.trim().toLowerCase();
    String texto = 'Aguardando profissional';
    IconData icone = Icons.hourglass_top_outlined;
    Color fundo = const Color(0xFFE0F2FE);
    Color textoCor = const Color(0xFF0284C7);
    Color borda = const Color(0xFFBAE6FD);

    if (s.contains('recus')) {
      texto = 'Recusado';
      icone = Icons.close_outlined;
      fundo = const Color(0xFFFEE2E2);
      textoCor = const Color(0xFFB91C1C);
      borda = const Color(0xFFFECACA);
    } else if (s.contains('cancel')) {
      texto = 'Cancelado';
      icone = Icons.cancel_outlined;
      fundo = const Color(0xFFFEE2E2);
      textoCor = const Color(0xFFB91C1C);
      borda = const Color(0xFFFECACA);
    } else if (s.contains('conclu') || s.contains('finaliz')) {
      texto = 'Concluído';
      icone = Icons.check_circle_outline;
      fundo = const Color(0xFFF1F5F9);
      textoCor = const Color(0xFF334155);
      borda = const Color(0xFFE2E8F0);
    } else if (s.contains('andamento') || s.contains('execu')) {
      texto = 'Em andamento';
      icone = Icons.autorenew;
      fundo = const Color(0xFF0B3B5B);
      textoCor = Colors.white;
      borda = const Color(0xFF0B3B5B);
    } else if (s.contains('aceito') || s.contains('aprovado')) {
      texto = 'Aceito';
      icone = Icons.check_circle_outline;
      fundo = const Color(0xFFDCFCE7);
      textoCor = const Color(0xFF15803D);
      borda = const Color(0xFFBBF7D0);
    } else if (s.contains('pagamento') || s == 'pago') {
      texto = s == 'pago' ? 'Pago' : 'Aguardando Pagamento';
      icone = Icons.payments_outlined;
      fundo = const Color(0xFFFEF9C3);
      textoCor = const Color(0xFF854D0E);
      borda = const Color(0xFFFDE68A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: textoCor),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textoCor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperEtapas(List<_EtapaVisualConfig> etapas) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int qtd = etapas.length;
        // Largura dedicada para cada coluna de texto e bolinha
        final double itemWidth = (constraints.maxWidth / qtd).clamp(48.0, 70.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < qtd; i++) ...[
              SizedBox(
                width: itemWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBolinhaSonar(etapas[i]),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: itemWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: Text(
                          etapas[i].titulo,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: etapas[i].corTexto,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < qtd - 1)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Container(
                      height: 2.5,
                      color: etapas[i].concluida
                          ? azulPrincipal
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBolinhaSonar(_EtapaVisualConfig etapa) {
    const double tamanho = 36.0;

    if (!etapa.temSonar) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: etapa.corFundo,
          shape: BoxShape.circle,
        ),
        child: Icon(etapa.icone, color: etapa.corIcone, size: 18),
      );
    }

    // Com efeito sonar animado
    return AnimatedBuilder(
      animation: _sonarController,
      builder: (context, child) {
        final double t = _sonarController.value;
        return SizedBox(
          width: tamanho + 16,
          height: tamanho + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Onda do sonar 1
              Opacity(
                opacity: (1.0 - t).clamp(0.0, 0.7),
                child: Container(
                  width: tamanho + (16 * t),
                  height: tamanho + (16 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: etapa.corFundo, width: 2.5),
                  ),
                ),
              ),
              // Onda do sonar 2
              Opacity(
                opacity: (1.0 - ((t + 0.5) % 1.0)).clamp(0.0, 0.5),
                child: Container(
                  width: tamanho + (12 * ((t + 0.5) % 1.0)),
                  height: tamanho + (12 * ((t + 0.5) % 1.0)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: etapa.corFundo.withOpacity(0.18),
                  ),
                ),
              ),
              // Bolinha central
              Container(
                width: tamanho,
                height: tamanho,
                decoration: BoxDecoration(
                  color: etapa.corFundo,
                  shape: BoxShape.circle,
                ),
                child: Icon(etapa.icone, color: etapa.corIcone, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 4. Card "OFERECIDO POR" (Loja ou Profissional Independente)
  // ===========================================================================
  Widget _buildCardOferecidoPor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                'OFERECIDO POR',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: textoMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Color(0xFF0284C7), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Verificado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child:
                      (_fotoPrestador != null &&
                          _fotoPrestador!.trim().isNotEmpty)
                      ? Image.network(
                          _fotoPrestador!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderPrestador(),
                        )
                      : _placeholderPrestador(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nomePrestador,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textoEscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if ((_tagPrestador ?? '').trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${_tagPrestador!.trim()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        if ((_categoriaPrestador ?? '').trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _categoriaPrestador!.trim(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                        SizedBox(width: 3),
                        Text(
                          '4.7',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: textoEscuro,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(3.248 avaliações)',
                          style: TextStyle(fontSize: 12, color: textoMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Box de Endereço do Prestador (dinâmico, sem dados fictícios)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: textoMuted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ehLoja
                            ? 'Endereço - Oficina'
                            : 'Endereço - Atendimento',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textoMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _enderecoPrestador,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _enderecoPrestador.contains('não possui')
                              ? textoMuted
                              : textoEscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _abrirChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Conversar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulPrincipal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _abrirPerfilPrestador,
                  icon: Icon(
                    _ehLoja ? Icons.storefront_outlined : Icons.person_outline,
                    size: 16,
                  ),
                  label: Text(_ehLoja ? 'Ver Loja' : 'Ver Perfil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: textoEscuro,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  Widget _placeholderPrestador() {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(_nomePrestador),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. Card "SERVIÇO SELECIONADO"
  // ===========================================================================
  Widget _buildCardServicoSelecionado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do serviço ou Placeholder da Caixa de Ferramentas
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (_imagemServico != null && _imagemServico!.trim().isNotEmpty)
                      ? Image.network(
                          _imagemServico!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderServico(),
                        )
                      : _placeholderServico(),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '1 item',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tituloServico,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: textoEscuro,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if ((_tagPrestador ?? '').trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${_tagPrestador!.trim()}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    if ((_oficioFuncao ?? '').trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _oficioFuncao!.trim(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.qr_code_2_outlined, size: 15, color: textoMuted),
                    SizedBox(width: 4),
                    Text(
                      'Pagamento via PIX',
                      style: TextStyle(
                        fontSize: 12,
                        color: textoMuted,
                        fontWeight: FontWeight.w600,
                      ),
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

  /// Placeholder do serviço idêntico ao tela_home (caixa de ferramentas)
  Widget _placeholderServico() {
    return Container(
      color: const Color(0xFFEAF4FB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.home_repair_service_rounded,
        color: Color(0xFF0A6E9D),
        size: 32,
      ),
    );
  }

  // ===========================================================================
  // 6. Card "MODALIDADE DO SERVIÇO"
  // ===========================================================================
  Widget _buildCardModalidadeServico() {
    final mod = _tipoExecucao.trim().toLowerCase();

    String tituloMod = 'Serviço Leva e Traz';
    String descMod =
        'O profissional fará a retirada na sua casa e devolverá o item consertado.';
    IconData iconeMod = Icons.two_wheeler;
    bool mostrarEnderecoCliente = true;

    if (mod.contains('domic')) {
      tituloMod = 'Atendimento em Domicílio';
      descMod =
          'O profissional irá até o seu endereço para realizar o serviço.';
      iconeMod = Icons.home_repair_service_outlined;
      mostrarEnderecoCliente = true;
    } else if (mod.contains('receba') && mod.contains('casa')) {
      tituloMod = 'Receba em Casa';
      descMod =
          'Você leva o produto até a oficina e o profissional entrega em sua casa.';
      iconeMod = Icons.local_shipping_outlined;
      mostrarEnderecoCliente = false;
    } else if (mod.contains('retirad') ||
        (mod.contains('retirada') && mod.contains('local'))) {
      tituloMod = 'Retirada no Local';
      descMod =
          'Você entrega e retira o item diretamente no endereço da oficina.';
      iconeMod = Icons.storefront_outlined;
      mostrarEnderecoCliente = false;
    }

    final enderecoExibido = mostrarEnderecoCliente
        ? _enderecoCliente
        : _enderecoPrestador;
    final tituloEndereco = mostrarEnderecoCliente
        ? 'Meu endereço'
        : (_ehLoja ? 'Endereço da Loja' : 'Endereço do Profissional');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MODALIDADE DO SERVIÇO',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textoMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF7FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: azulPrincipal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconeMod, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tituloMod,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textoEscuro,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descMod,
                        style: const TextStyle(
                          fontSize: 12,
                          color: textoMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    mostrarEnderecoCliente
                        ? Icons.home_outlined
                        : Icons.storefront_outlined,
                    color: azulPrincipal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tituloEndereco,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textoEscuro,
                            ),
                          ),
                          if (mostrarEnderecoCliente &&
                              !_enderecoCliente.contains('não informado'))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Casa',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: textoMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        enderecoExibido,
                        style: TextStyle(
                          fontSize: 12,
                          color: enderecoExibido.contains('não')
                              ? textoMuted
                              : const Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. Card "AGENDAMENTO & PRAZOS"
  // ===========================================================================
  Widget _buildCardAgendamentoPrazos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGENDAMENTO & PRAZOS',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textoMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month_outlined,
                          color: azulPrincipal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DATA DO SERVIÇO',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: textoMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatarDataAgendada(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textoEscuro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.access_time_outlined,
                          color: azulPrincipal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'JANELA HORÁRIA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: textoMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatarJanelaHoraria(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textoEscuro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withOpacity(0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: azulPrincipal,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prazo estimado: Entregue em até 5 dias após a coleta.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
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

  // ===========================================================================
  // 8. Card "OBSERVAÇÕES DO CLIENTE" (Sem mock estático de panela/imagem)
  // ===========================================================================
  Widget _buildCardObservacoesCliente() {
    final bool temObs = _detalhesObs.isNotEmpty;
    final String relato = temObs
        ? (_detalhesObs.startsWith('"') ? _detalhesObs : '"$_detalhesObs"')
        : 'O cliente não forneceu detalhes do serviço';

    final bool temAnexos = _anexos.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                'OBSERVAÇÕES DO CLIENTE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: textoMuted,
                  letterSpacing: 0.5,
                ),
              ),
              if (temAnexos)
                Text(
                  _anexos.length > 1 ? '${_anexos.length} anexos' : '1 anexo',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textoMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relato,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: temObs ? FontStyle.italic : FontStyle.normal,
                    color: temObs ? const Color(0xFF334155) : textoMuted,
                    height: 1.45,
                  ),
                ),
                // Exibe imagem APENAS se houver anexos reais no banco
                if (temAnexos) ...[
                  const SizedBox(height: 14),
                  for (final anexo in _anexos) ...[
                    _buildItemAnexo(anexo),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemAnexo(Map<String, dynamic> anexo) {
    final anexoUrl = anexo['anexo_url']?.toString().trim() ?? '';
    final anexoNome = anexo['nome_arquivo']?.toString().trim() ?? 'Anexo';

    return GestureDetector(
      onTap: () {
        if (anexoUrl.isNotEmpty) {
          _abrirVisualizadorImagem(anexoUrl);
        }
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: anexoUrl.isNotEmpty
                      ? Image.network(
                          anexoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderAnexo(),
                        )
                      : _placeholderAnexo(),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anexoNome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textoEscuro,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Foto enviada para prévia da peça',
                  style: TextStyle(fontSize: 11.5, color: textoMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderAnexo() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(Icons.image, color: Colors.grey, size: 28),
    );
  }

  void _abrirVisualizadorImagem(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 9. Card "RESUMO DOS VALORES"
  // ===========================================================================
  Widget _buildCardResumoValores() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMO DOS VALORES',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textoMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal do Serviço',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
              ),
              Text(
                _formatarPreco(_valorServico),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textoEscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Taxa de Coleta e Devolução',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
              ),
              const Text(
                'Grátis',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: azulPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Orçado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textoEscuro,
                ),
              ),
              Text(
                _formatarPreco(_valorFinal),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: azulPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: azulPrincipal, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cobrança realizada apenas após a aceite do Profissional.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
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

  Widget _buildCardAvaliacoesCliente() {
    const titulos = {
      'servico': 'Avaliação do serviço',
      'profissional': 'Avaliação do profissional',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUAS AVALIAÇÕES',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textoMuted,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _avaliacoesCliente.length; index++) ...[
            if (index > 0) const Divider(height: 20),
            _buildLinhaAvaliacaoCliente(_avaliacoesCliente[index], titulos),
          ],
        ],
      ),
    );
  }

  Widget _buildLinhaAvaliacaoCliente(
    Map<String, dynamic> avaliacao,
    Map<String, String> titulos,
  ) {
    final tipo = avaliacao['tipo_avaliacao']?.toString() ?? '';
    final nota = (avaliacao['nota'] as num?)?.toInt() ?? 0;
    final comentario = avaliacao['comentario']?.toString().trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulos[tipo] ?? 'Avaliação',
          style: const TextStyle(
            color: textoEscuro,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var estrela = 1; estrela <= 5; estrela++)
              Icon(
                estrela <= nota ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFF5A623),
                size: 19,
              ),
            const SizedBox(width: 6),
            Text('$nota/5', style: const TextStyle(color: textoMuted)),
          ],
        ),
        if (comentario.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comentario, style: const TextStyle(color: Color(0xFF475569))),
        ],
      ],
    );
  }

  // ===========================================================================
  // 10. Links de Rodapé: Um embaixo do outro + Cancelar dinâmico
  // ===========================================================================
  Widget _buildAcoesRodape() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão Ajuda
        GestureDetector(
          onTap: _abrirAjuda,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.support_agent_outlined,
                  size: 18,
                  color: Color(0xFF475569),
                ),
                SizedBox(width: 8),
                Text(
                  'Ajuda com este pedido',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Botão Cancelar Pedido (Aparece SOMENTE se o status for Aberto ou Aceito)
        if (_podeCancelar) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _cancelarSolicitacao,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cancelar Pedido',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 11. Barra Inferior Fixa (Total + Botão Enviar Mensagem)
  // ===========================================================================
  Widget _buildBottomBar() {
    final status = _statusTexto.trim().toLowerCase();
    final aguardandoCliente = status == 'aguardando cliente';
    final aceito = status == 'aceito';
    final precisaAvaliarCliente =
        status.contains('conclu') && !_avaliadoCliente;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textoMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _formatarPreco(_valorFinal),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: azulPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: aguardandoCliente
                    ? (_confirmandoConclusao ? null : _confirmarConclusao)
                    : aceito
                    ? _abrirPagamento
                  : precisaAvaliarCliente
                  ? _avaliarPedidoCliente
                    : _abrirChat,
                icon: _confirmandoConclusao
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        aguardandoCliente
                            ? Icons.check_circle_outline
                            : aceito
                            ? Icons.payments_outlined
                          : precisaAvaliarCliente
                          ? Icons.star_outline_rounded
                            : Icons.chat_bubble_outline,
                        size: 18,
                      ),
                label: Text(
                  _confirmandoConclusao
                      ? 'Confirmando...'
                      : aguardandoCliente
                      ? 'Confirmar entrega/final'
                      : aceito
                      ? 'Realizar pagamento'
                      : precisaAvaliarCliente
                      ? 'Avaliar'
                      : 'Enviar Mensagem',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulPrincipal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
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

class GestureedAvatar extends StatelessWidget {
  final String? fotoUrl;
  final String nome;
  final double tamanho;
  final bool carregando;

  const GestureedAvatar({
    super.key,
    required this.fotoUrl,
    required this.nome,
    required this.tamanho,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: const BoxDecoration(
          color: Color(0xFF0FB3FF),
          shape: BoxShape.circle,
        ),
      );
    }

    final url = (fotoUrl ?? '').trim();
    return ClipOval(
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: tamanho,
                    height: tamanho,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0FB3FF),
                      shape: BoxShape.circle,
                    ),
                  );
                },
                errorBuilder: (_, _, _) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF0FB3FF),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(nome.isNotEmpty ? nome : 'Cliente'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: tamanho * 0.4,
        ),
      ),
    );
  }
}
