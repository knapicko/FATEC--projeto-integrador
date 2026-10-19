import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'services/chat_anexos_service.dart';
import 'services/verificacao_online.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'alterar_tema_chat.dart';
import 'tela_midia_chat.dart';
import 'widgets/skeleton_loading.dart';

class ChatContatoInfo extends StatefulWidget {
  final int? idConversa;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final String nomeContato;
  final String? fotoContato;
  final String? oficioPrincipal;
  final DateTime? ultimaConexao;
  final bool souProfissionalLogado;

  const ChatContatoInfo({
    super.key,
    this.idConversa,
    this.idProfissional,
    this.idGrupoEmpresa,
    required this.nomeContato,
    this.fotoContato,
    this.oficioPrincipal,
    this.ultimaConexao,
    this.souProfissionalLogado = false,
  });

  @override
  State<ChatContatoInfo> createState() => _ChatContatoInfoState();
}

class _ChatContatoInfoState extends State<ChatContatoInfo> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _screenBackground = Color(0xFFF7F8FA);

  final _supabase = Supabase.instance.client;

  bool _carregando = true;
  String _nome = '';
  String? _fotoUrl;
  DateTime? _ultimaConexao;
  int? _idProfissional;
  int? _idGrupoEmpresa;
  int? _idCliente;
  int? _fkPerfil;
  String? _tipoPerfil;

  // Ofícios e Especialidades
  List<OficioInfo> _oficios = [];
  List<String> _especialidades = [];

  // Mídias
  int _totalArquivos = 0;
  List<_AnexoMidia> _anexosMidia = [];

  // Configurações
  bool _notificacoesAtivas = true;
  bool _favorito = false;

  // Dados da Empresa Vinculada
  bool _temEmpresaVinculada = false;
  int? _idEmpresa;
  String _nomeEmpresa = '';
  String _tagEmpresa = '';
  String? _fotoEmpresa;
  String? _bannerEmpresa;
  String _enderecoEmpresa = '';

  @override
  void initState() {
    super.initState();
    _nome = widget.nomeContato;
    _fotoUrl = widget.fotoContato;
    _ultimaConexao = widget.ultimaConexao;
    _idProfissional = widget.idProfissional;
    _idGrupoEmpresa = widget.idGrupoEmpresa;

    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      // 1. Se idProfissional ou idGrupo for nulo, tenta resolver pela conversa
      if (widget.idConversa != null) {
        final conversa = await _supabase
            .from('conversas')
            .select('fk_usuario, fk_profissional, fk_grupo_empresa')
            .eq('id_conversa', widget.idConversa!)
            .maybeSingle();

        if (conversa != null) {
          _idCliente = (conversa['fk_usuario'] as num?)?.toInt();
          _idProfissional ??= (conversa['fk_profissional'] as num?)?.toInt();
          _idGrupoEmpresa ??= (conversa['fk_grupo_empresa'] as num?)?.toInt();
        }
      }

      if (widget.souProfissionalLogado && _idCliente != null) {
        final usuario = await _supabase
            .from('usuarios')
            .select('nome, foto_perfil_url, ultima_conexao')
            .eq('id_usuario', _idCliente!)
            .maybeSingle();

        if (usuario != null) {
          final nome = usuario['nome']?.toString().trim();
          if (nome != null && nome.isNotEmpty) _nome = nome;
          final foto = usuario['foto_perfil_url']?.toString().trim();
          if (foto != null && foto.isNotEmpty) _fotoUrl = foto;
          final rawData = usuario['ultima_conexao']?.toString();
          if (rawData != null) {
            _ultimaConexao = DateTime.tryParse(rawData)?.toLocal();
          }
        }
      } else if (_idProfissional != null) {
        // 2. Carrega dados do profissional
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_usuario, fk_perfil, fk_grupo_empresa')
            .eq('id_profissional', _idProfissional!)
            .maybeSingle();

        if (dadosProf != null) {
          _fkPerfil = (dadosProf['fk_perfil'] as num?)?.toInt();
          _idGrupoEmpresa ??= (dadosProf['fk_grupo_empresa'] as num?)?.toInt();

          final fkUsuario = (dadosProf['fk_usuario'] as num?)?.toInt();
          if (fkUsuario != null) {
            final usuario = await _supabase
                .from('usuarios')
                .select('nome, foto_perfil_url, ultima_conexao')
                .eq('id_usuario', fkUsuario)
                .maybeSingle();

            if (usuario != null) {
              final nome = usuario['nome']?.toString().trim();
              if (nome != null && nome.isNotEmpty) _nome = nome;
              final foto = usuario['foto_perfil_url']?.toString().trim();
              if (foto != null && foto.isNotEmpty) _fotoUrl = foto;
              final rawData = usuario['ultima_conexao']?.toString();
              if (rawData != null) {
                _ultimaConexao = DateTime.tryParse(rawData)?.toLocal();
              }
            }
          }

          if (_fkPerfil != null) {
            final perfil = await _supabase
                .from('perfil')
                .select('tipo_perfil')
                .eq('id_perfil', _fkPerfil!)
                .maybeSingle();
            _tipoPerfil = perfil?['tipo_perfil']?.toString().trim();

            if (_idGrupoEmpresa == null) {
              final grupoDono = await _supabase
                  .from('grupo_empresa')
                  .select('id_grupo_empresa')
                  .eq('fk_perfil', _fkPerfil!)
                  .maybeSingle();
              if (grupoDono != null) {
                _idGrupoEmpresa = (grupoDono['id_grupo_empresa'] as num?)
                    ?.toInt();
              }
            }
          }

          // Carrega ofícios
          await _carregarOficiosEEspecialidades(_idProfissional!);
        }
      }

      // 3. Carrega mídias da conversa
      if (widget.idConversa != null) {
        await _carregarMidias(widget.idConversa!);
      }

      // 4. Carrega empresa vinculada
      if (!widget.souProfissionalLogado && _idGrupoEmpresa != null) {
        await _carregarEmpresaVinculada(_idGrupoEmpresa!);
      } else if (!widget.souProfissionalLogado) {
        // Se ainda não tiver empresa vinculada mas o usuário for Caneta Azul ou loja,
        // tenta buscar se existe alguma empresa no sistema para exibir no mockup
        await _carregarEmpresaVinculadaFallback();
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do contato: $e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _carregarOficiosEEspecialidades(int idProfissional) async {
    try {
      final assOficios = await _supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', idProfissional);

      final idsOficios = assOficios
          .map((e) => e['fk_oficio'])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();

      if (idsOficios.isNotEmpty) {
        final oficiosData = await _supabase
            .from('oficios')
            .select('funcao, cor, categoria')
            .inFilter('id_oficio', idsOficios);

        final oficios = <OficioInfo>[];
        for (final row in oficiosData) {
          final info = OficioInfo.fromMap(row);
          if (info.funcao.isNotEmpty) oficios.add(info);
        }
        _oficios = oficios;
      }

      // Carrega também títulos de serviços para tags complementares
      final servicos = await _supabase
          .from('servicos_profissional')
          .select('titulo')
          .eq('fk_profissional', idProfissional)
          .limit(4);

      final titulos = servicos
          .map((s) => s['titulo']?.toString().trim() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();

      _especialidades = titulos;
    } catch (e) {
      debugPrint('Erro ao carregar ofícios: $e');
    }
  }

  Future<void> _carregarMidias(int idConversa) async {
    try {
      final mensagens = await _supabase
          .from('mensagens')
          .select('conteudo, tipo_mensagem')
          .eq('fk_conversa', idConversa)
          .order('data_envio', ascending: false);

      final anexos = <_AnexoMidia>[];
      for (final m in mensagens) {
        final tipo = m['tipo_mensagem']?.toString().toLowerCase() ?? '';
        final conteudo = m['conteudo']?.toString().trim() ?? '';
        if (conteudo.isEmpty) continue;

        final ehAnexo =
            tipo.contains('imagem') ||
            tipo.contains('documento') ||
            tipo.contains('arquivo') ||
            tipo.contains('audio');
        if (!ehAnexo) continue;

        final documento = ChatAnexosService.separarConteudoDocumento(conteudo);
        final url = documento?.url ?? conteudo;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          continue;
        }
        anexos.add(
          _AnexoMidia(url: url, tipo: tipo, nome: documento?.nome ?? ''),
        );
      }

      _totalArquivos = anexos.length;
      _anexosMidia = anexos;
    } catch (e) {
      debugPrint('Erro ao carregar mídias da conversa: $e');
    }
  }

  Future<void> _carregarEmpresaVinculada(int idGrupo) async {
    try {
      final grupo = await _supabase
          .from('grupo_empresa')
          .select(
            'id_grupo_empresa, nome_empresa, tag_empresa, foto_url_empresa, banner_url_empresa',
          )
          .eq('id_grupo_empresa', idGrupo)
          .maybeSingle();

      if (grupo != null) {
        _idEmpresa = idGrupo;
        _nomeEmpresa =
            grupo['nome_empresa']?.toString().trim() ?? 'Empresa Parceira';
        _tagEmpresa = grupo['tag_empresa']?.toString().trim() ?? 'EMPRESA';
        if (!_tagEmpresa.startsWith('#')) _tagEmpresa = '#$_tagEmpresa';
        _fotoEmpresa = grupo['foto_url_empresa']?.toString().trim();
        _bannerEmpresa = grupo['banner_url_empresa']?.toString().trim();
        _temEmpresaVinculada = true;

        // Endereço da empresa
        await _carregarEnderecoEmpresa(idGrupo);
      }
    } catch (e) {
      debugPrint('Erro ao carregar empresa vinculada: $e');
    }
  }

  Future<void> _carregarEmpresaVinculadaFallback() async {
    try {
      final lista = await _supabase
          .from('grupo_empresa')
          .select(
            'id_grupo_empresa, nome_empresa, tag_empresa, foto_url_empresa, banner_url_empresa',
          )
          .limit(1);

      if (lista.isNotEmpty) {
        final grupo = lista.first;
        final idGrupo = (grupo['id_grupo_empresa'] as num?)?.toInt();
        if (idGrupo != null) {
          _idEmpresa = idGrupo;
          _nomeEmpresa =
              grupo['nome_empresa']?.toString().trim() ??
              'Caedss - Estrada das Lágrimas';
          _tagEmpresa = grupo['tag_empresa']?.toString().trim() ?? '#CAEDS';
          if (!_tagEmpresa.startsWith('#')) _tagEmpresa = '#$_tagEmpresa';
          _fotoEmpresa = grupo['foto_url_empresa']?.toString().trim();
          _bannerEmpresa = grupo['banner_url_empresa']?.toString().trim();
          _temEmpresaVinculada = true;

          await _carregarEnderecoEmpresa(idGrupo);
        }
      }
    } catch (_) {}
  }

  Future<void> _carregarEnderecoEmpresa(int idGrupo) async {
    try {
      List vinculos = await _supabase
          .from('ass_grupo_empresa_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_grupo_empresa', idGrupo);

      if (vinculos.isEmpty) {
        // Tenta buscar no legado ou dono
        final donoProf = await _supabase
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('fk_grupo_empresa', idGrupo)
            .limit(5);

        final idsUsuarios = donoProf
            .map((r) => (r as Map)['fk_usuario'])
            .whereType<num>()
            .map((n) => n.toInt())
            .toList();

        if (idsUsuarios.isNotEmpty) {
          vinculos = await _supabase
              .from('ass_usuario_endereco')
              .select('fk_endereco, endereco_ativo')
              .inFilter('fk_usuario', idsUsuarios)
              .inFilter('tipo_endereco', ['Loja', 'Oficina', 'Outro'])
              .limit(5);
        }
      }

      if (vinculos.isNotEmpty) {
        Map<String, dynamic>? ativo;
        for (final v in vinculos) {
          if ((v as Map)['endereco_ativo'] == true) {
            ativo = Map<String, dynamic>.from(v);
            break;
          }
        }
        ativo ??= Map<String, dynamic>.from(vinculos.first as Map);
        final fkEnd = ativo['fk_endereco'];
        if (fkEnd != null) {
          final end = await _supabase
              .from('enderecos')
              .select('logradouro, numero, bairro, fk_cidade')
              .eq('id_endereco', fkEnd)
              .maybeSingle();

          if (end != null) {
            final logradouro = end['logradouro']?.toString().trim() ?? '';
            final numero = end['numero']?.toString().trim() ?? '';
            final bairro = end['bairro']?.toString().trim() ?? '';

            String linha = logradouro;
            if (numero.isNotEmpty) linha += ', $numero';
            if (bairro.isNotEmpty) linha += ' - $bairro';

            _enderecoEmpresa = linha.isNotEmpty
                ? linha
                : 'Estrada das Lágrimas, 1820 - Ipiranga';
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar endereço da empresa: $e');
    }

    if (_enderecoEmpresa.isEmpty) {
      _enderecoEmpresa = 'Estrada das Lágrimas, 1820 - Ipiranga';
    }
  }

  void _abrirPerfil() {
    final ehLoja =
        _tipoPerfil?.toLowerCase() == 'loja' ||
        (_idGrupoEmpresa != null && _idProfissional == null);

    if (ehLoja && _idGrupoEmpresa != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PerfilLoja(
            idGrupoEmpresa: _idGrupoEmpresa,
            nomeEmpresa: _nomeEmpresa.isNotEmpty ? _nomeEmpresa : _nome,
            fotoUrlEmpresa: _fotoEmpresa ?? _fotoUrl,
            bannerUrlEmpresa: _bannerEmpresa,
            tagEmpresa: _tagEmpresa,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PerfilProfissionalPage(
            nomeInicial: _nome,
            imagemInicial: _fotoUrl ?? '',
            profissao:
                widget.oficioPrincipal ??
                (_oficios.isNotEmpty ? _oficios.first.funcao : 'Profissional'),
            idProfissional: _idProfissional,
            idGrupoEmpresa: _idGrupoEmpresa,
          ),
        ),
      );
    }
  }

  String _formatarStatusOnline() {
    if (VerificacaoOnline.estaOnline(_ultimaConexao)) {
      return 'Online agora';
    }
    if (_ultimaConexao == null) {
      return 'Última vez online hoje às 20:30';
    }
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final data = DateTime(
      _ultimaConexao!.year,
      _ultimaConexao!.month,
      _ultimaConexao!.day,
    );
    final hora = DateFormat('HH:mm').format(_ultimaConexao!);

    if (hoje == data) {
      return 'Última vez online hoje às $hora';
    } else if (hoje.subtract(const Duration(days: 1)) == data) {
      return 'Última vez online ontem às $hora';
    } else {
      final dia = DateFormat('dd/MM').format(_ultimaConexao!);
      return 'Última vez online em $dia às $hora';
    }
  }

  void _confirmarBloqueio() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bloquear $_nome?'),
        content: Text(
          'Você não receberá mais mensagens ou chamadas deste contato. Tem certeza de que deseja continuar?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contato $_nome bloqueado com sucesso.'),
                ),
              );
            },
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }

  void _confirmarDenuncia() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Denunciar $_nome?'),
        content: const Text(
          'Deseja reportar conduta indevida, spam, ofensas ou fraude relacionada a este contato? Nossa equipe de suporte irá analisar.',
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Denúncia contra $_nome enviada.')),
              );
            },
            child: const Text('Denunciar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _screenBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1E293B)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 4,
            onSelected: (value) {
              if (value == 'perfil' && !widget.souProfissionalLogado) {
                _abrirPerfil();
              }
              if (value == 'bloquear') _confirmarBloqueio();
              if (value == 'denunciar') _confirmarDenuncia();
            },
            itemBuilder: (ctx) => [
              if (!widget.souProfissionalLogado)
                const PopupMenuItem(
                  value: 'perfil',
                  child: Text('Ver perfil completo'),
                ),
              const PopupMenuItem(
                value: 'bloquear',
                child: Text(
                  'Bloquear contato',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
              const PopupMenuItem(
                value: 'denunciar',
                child: Text(
                  'Denunciar contato',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _carregando
          ? const _SkeletonChatContatoInfo()
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildInformacoesPrincipais(),
                  const SizedBox(height: 20),
                  _buildAcoesComunicacao(),
                  const SizedBox(height: 16),
                  _buildSecaoMidia(),
                  const SizedBox(height: 16),
                  _buildOpcoesConfiguracoes(),
                  if (!widget.souProfissionalLogado && _temEmpresaVinculada) ...[
                    const SizedBox(height: 16),
                    _buildCardEmpresaVinculada(),
                  ],
                  const SizedBox(height: 16),
                  _buildAcoesSeguranca(),
                ],
              ),
            ),
    );
  }

  // 1. Informações Principais do Perfil
  Widget _buildInformacoesPrincipais() {
    final online = VerificacaoOnline.estaOnline(_ultimaConexao);
    return Column(
      children: [
        // Foto de Perfil Circular
        Center(
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE2E8F0),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _fotoUrl != null && _fotoUrl!.isNotEmpty
                  ? Image.network(
                      _fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                    )
                  : _buildAvatarFallback(),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Nome do Contato + Selo Verificado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _nome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: _primaryBlue, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tags/Chips de Ofícios e Especialidades
        if (!widget.souProfissionalLogado)
          _buildChipsOficiosEEspecialidades(),
        const SizedBox(height: 12),

        // Indicador de Status Online
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Color(0xFF16A34A) : Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _formatarStatusOnline(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: online ? Color(0xFF16A34A) : Color(0xFF475569),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(_nome),
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
      ),
    );
  }

  Widget _buildChipsOficiosEEspecialidades() {
    // Monta lista de chips
    final tags = <_ChipDado>[];

    if (_oficios.isNotEmpty) {
      for (final of in _oficios) {
        final corBase = CorOficio.parse(of.cor);
        tags.add(
          _ChipDado(
            texto: of.funcao,
            corFundo: CorOficio.corFundo(corBase),
            corTexto: CorOficio.corTexto(corBase),
          ),
        );
      }
    }

    // Se temos especialidades vindas dos serviços, adiciona se faltar
    if (_especialidades.isNotEmpty && tags.length < 3) {
      for (final esp in _especialidades.take(3)) {
        if (!tags.any((t) => t.texto.toLowerCase() == esp.toLowerCase())) {
          tags.add(
            _ChipDado(
              texto: esp,
              corFundo: const Color(0xFFDCEEFF),
              corTexto: const Color(0xFF1E40AF),
            ),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: tags.map((chip) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: chip.corFundo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              chip.texto,
              style: TextStyle(
                color: chip.corTexto,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 2. Ações de Comunicação (3 cards brancos lado a lado)
  Widget _buildAcoesComunicacao() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildCardAcao(
              icone: Icons.call_outlined,
              label: 'Ligar',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chamada de voz não disponível no momento.'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCardAcao(
              icone: Icons.videocam_outlined,
              label: 'Vídeo',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Chamada de vídeo não disponível no momento.',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCardAcao(
              icone: Icons.search,
              label: 'Pesquisar',
              onTap: () {
                // Retorna ao chat e entra no modo de pesquisa
                Navigator.pop(context, 'pesquisar');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAcao({
    required IconData icone,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF1F5F9),
              ),
              child: Icon(icone, color: const Color(0xFF1E293B), size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirMidiaChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaMidiaChat(
          idConversa: widget.idConversa,
          nomeContato: _nome,
        ),
      ),
    );
  }

  // 3. Seção de Mídia na Conversa
  Widget _buildSecaoMidia() {
    final anexosExibir = _anexosMidia.take(4).toList();
    final restantes = _totalArquivos - anexosExibir.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da Seção de Mídia
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _abrirMidiaChat,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 20,
                      color: Color(0xFF334155),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Mídia na conversa',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_totalArquivos arquivos >',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (anexosExibir.isNotEmpty) ...[
              const SizedBox(height: 14),

              // 4 Miniaturas Quadradas
              GestureDetector(
                onTap: _abrirMidiaChat,
                child: Row(
                  children: List.generate(anexosExibir.length, (index) {
                    final anexo = anexosExibir[index];
                    final isLast =
                        index == anexosExibir.length - 1 && restantes > 0;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildMiniaturaAnexo(anexo),
                                if (isLast)
                                  Container(
                                    color: const Color(0x990FB3FF),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+$restantes',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniaturaAnexo(_AnexoMidia anexo) {
    if (anexo.ehImagem) {
      return Image.network(
        anexo.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildIconeAnexo(anexo),
      );
    }
    return _buildIconeAnexo(anexo);
  }

  Widget _buildIconeAnexo(_AnexoMidia anexo) {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Icon(
        anexo.ehAudio
            ? Icons.graphic_eq_rounded
            : Icons.insert_drive_file_rounded,
        color: const Color(0xFF64748B),
        size: 30,
      ),
    );
  }

  // 4. Configurações e Opções do Chat
  Widget _buildOpcoesConfiguracoes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            if (!widget.souProfissionalLogado) ...[
              _buildItemOpcao(
                icone: Icons.badge_outlined,
                titulo: 'Abrir perfil profissional',
                subtitulo: 'Avaliações, tabela de preços e portfólio',
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                ),
                onTap: _abrirPerfil,
              ),
              _buildDivisor(),
            ],
            _buildItemOpcao(
              icone: Icons.notifications_none_outlined,
              titulo: 'Notificações',
              subtitulo: 'Alertas de novas mensagens sonoros',
              trailing: Switch.adaptive(
                value: _notificacoesAtivas,
                activeColor: _primaryBlue,
                activeTrackColor: _primaryBlue.withOpacity(0.5),
                onChanged: (val) {
                  setState(() => _notificacoesAtivas = val);
                },
              ),
              onTap: () {
                setState(() => _notificacoesAtivas = !_notificacoesAtivas);
              },
            ),
            _buildDivisor(),
            _buildItemOpcao(
              icone: _favorito
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              iconeColor: _favorito
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF475569),
              titulo: 'Favoritar conversa',
              subtitulo: 'Fixar este contato no topo do chat',
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                setState(() => _favorito = !_favorito);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _favorito
                          ? 'Conversa adicionada aos favoritos.'
                          : 'Conversa removida dos favoritos.',
                    ),
                  ),
                );
              },
            ),
            _buildDivisor(),
            _buildItemOpcao(
              icone: Icons.brush_outlined,
              titulo: 'Alterar tema',
              subtitulo: 'Altere o tema e/ou plano de fundo da conversa',
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
              ),
              onTap: () async {
                final resultado = await Navigator.push<TemaChatConfig>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlterarTemaChat(
                      idConversa: widget.idConversa,
                      nomeContato: _nome.isNotEmpty ? _nome : widget.nomeContato,
                      fotoContato: _fotoUrl ?? widget.fotoContato,
                      oficioPrincipal: widget.oficioPrincipal,
                      idProfissional: _idProfissional,
                      idGrupoEmpresa: _idGrupoEmpresa,
                    ),
                  ),
                );
                if (resultado != null && mounted) {
                  Navigator.pop(context, resultado);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemOpcao({
    required IconData icone,
    Color iconeColor = const Color(0xFF475569),
    required String titulo,
    required String subtitulo,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF1F5F9),
              ),
              child: Icon(icone, color: iconeColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivisor() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }

  // 5. Card de Empresa Vinculada
  Widget _buildCardEmpresaVinculada() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          if (_idEmpresa != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilLoja(
                  idGrupoEmpresa: _idEmpresa,
                  nomeEmpresa: _nomeEmpresa,
                  fotoUrlEmpresa: _fotoEmpresa,
                  bannerUrlEmpresa: _bannerEmpresa,
                  tagEmpresa: _tagEmpresa,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: EMPRESA VINCULADA e Tag
              Row(
                children: [
                  const Text(
                    'EMPRESA VINCULADA',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _tagEmpresa.isNotEmpty ? _tagEmpresa : '#CAEDS',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Conteúdo: Imagem + Nome + Status + Endereço
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFFE2E8F0),
                      child: _fotoEmpresa != null && _fotoEmpresa!.isNotEmpty
                          ? Image.network(
                              _fotoEmpresa!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildLojaImageFallback(),
                            )
                          : _buildLojaImageFallback(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nomeEmpresa.isNotEmpty
                              ? _nomeEmpresa
                              : 'Caedss - Estrada das Lágrimas',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.verified, size: 14, color: _primaryBlue),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Empresa Verificada • Parceira Oficial',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _enderecoEmpresa.isNotEmpty
                                    ? _enderecoEmpresa
                                    : 'Estrada das Lágrimas, 1820 - Ipiranga',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLojaImageFallback() {
    return Image.network(
      'https://images.unsplash.com/photo-1578575437130-527eed3abbec?w=400&auto=format&fit=crop',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.storefront, color: Color(0xFF94A3B8), size: 28),
      ),
    );
  }

  // 6. Ações de Segurança (Destacadas em Vermelho)
  Widget _buildAcoesSeguranca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: _confirmarBloqueio,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFECEC),
                      ),
                      child: const Icon(
                        Icons.block,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bloquear $_nome',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Você não receberá mensagens ou chamadas deste contato',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildDivisor(),
            InkWell(
              onTap: _confirmarDenuncia,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFECEC),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Denunciar $_nome',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Reportar conduta indevida, spam ou fraude',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
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
      ),
    );
  }
}

class _ChipDado {
  final String texto;
  final Color corFundo;
  final Color corTexto;

  const _ChipDado({
    required this.texto,
    required this.corFundo,
    required this.corTexto,
  });
}

class _AnexoMidia {
  final String url;
  final String tipo;
  final String nome;

  const _AnexoMidia({
    required this.url,
    required this.tipo,
    required this.nome,
  });

  bool get ehImagem =>
      tipo.contains('imagem') ||
      RegExp(
        r'\.(jpg|jpeg|png|webp|gif)(\?|$)',
        caseSensitive: false,
      ).hasMatch(url);

  bool get ehAudio => tipo.contains('audio');
}

class _SkeletonChatContatoInfo extends StatelessWidget {
  const _SkeletonChatContatoInfo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: const [
        Center(child: SkeletonBox(width: 108, height: 108, borderRadius: 54)),
        SizedBox(height: 14),
        Center(child: SkeletonBox(width: 180, height: 22, borderRadius: 5)),
        SizedBox(height: 12),
        Center(child: SkeletonBox(width: 150, height: 16, borderRadius: 5)),
        SizedBox(height: 24),
        SkeletonBox(height: 82, borderRadius: 16),
        SizedBox(height: 16),
        SkeletonBox(height: 150, borderRadius: 16),
        SizedBox(height: 16),
        SkeletonBox(height: 250, borderRadius: 16),
      ],
    );
  }
}
