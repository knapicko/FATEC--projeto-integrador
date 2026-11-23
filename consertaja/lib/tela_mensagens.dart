import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/skeleton_loading.dart';

import 'gestao_equipe.dart';
import 'meus_pedidos.dart';
import 'solicitacao_geografica_cliente.dart';
import 'services/chat_anexos_service.dart';
import 'services/verificacao_online.dart';
import 'tela_chat_profissional.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'meus_servicos_solicitados.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';
import 'utils/app_navigation_util.dart';
import 'utils/funcao_servico.dart';
import 'solicitacao_geografica_profissional.dart';
import 'utils/cor_status.dart';
import 'utils/cor_oficio.dart';
import 'widgets/borda_gradiente_animada.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_da_tela.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';

/// Tela "Mensagens": lista de conversas do usuário logado (cliente ou profissional),
/// com visual moderno, atualização em tempo real, indicador de presença online,
/// badge com contador de não lidas e tipografia fiel ao design.
class TelaMensagensPage extends StatefulWidget {
  final bool isVisitante;
  final bool isProfissional;

  const TelaMensagensPage({
    super.key,
    this.isVisitante = false,
    this.isProfissional = false,
  });

  @override
  State<TelaMensagensPage> createState() => _TelaMensagensPageState();
}

class _TelaMensagensPageState extends State<TelaMensagensPage>
    with TutorialDaTela<TelaMensagensPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _titleDark = Color(0xFF111827);
  static const Color _unreadAccent = Color(0xFF1D4F91);
  static const Color _textMuted = Color(0xFF6B7280);

  final _supabase = Supabase.instance.client;
  final _buscaController = TextEditingController();

  List<_ConversaResumo> _conversas = [];
  bool _carregando = true;
  String? _erro;
  String _termoBusca = '';
  int? _idUsuarioLogado;
  bool _isProfissional = false;

  /// Conta ativa: false = profissional independente (CNPJ), true = empresa.
  /// Mesma preferência usada na home (consertaja_conta_empresa_ativa_<uid>).
  static const String _prefContaAtivaKey = 'consertaja_conta_empresa_ativa';
  bool _contaEmpresaAtiva = false;

  /// Foto/nome da MINHA conta (empresa ou profissional) — avatar no topo.
  String? _minhaFotoConta;
  String _meuNomeConta = '';
  bool _souDonoEmpresa = false;

  RealtimeChannel? _canalLista;
  Timer? _pollingLista;
  Timer? _timerOnlineTicker;
  Timer? _debounceReload;

  @override
  void initState() {
    super.initState();
    _isProfissional = widget.isProfissional;
    _carregarContaAtivaEMinhaFoto().then((_) {
      if (!mounted) return;
      _carregarConversas(mostrarLoading: true).then((_) {
        if (mounted) _assinarAtualizacoes();
      });
    });

    // Reavalia a cada 15 segundos para atualizar a bolinha azul de online visualmente
    _timerOnlineTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Lê a conta ativa (mesma flag da home) e a foto/nome da minha conta:
  /// empresa (grupo_empresa.foto_url_empresa) ou profissional
  /// (usuarios.foto_perfil_url).
  Future<void> _carregarContaAtivaEMinhaFoto() async {
    // Aquece o cache da bottom bar para o primeiro frame não piscar.
    final ativaCache =
        await BottomNavigationBarProfissional.precarregarContaEmpresa();
    if (mounted && ativaCache != _contaEmpresaAtiva) {
      setState(() => _contaEmpresaAtiva = ativaCache);
    }
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;
      final prefs = await SharedPreferences.getInstance();
      final ativa =
          prefs.getBool('${_prefContaAtivaKey}_${authUser.id}') ?? false;

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url, tipo_conta')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();

      bool ehProfissional =
          widget.isProfissional ||
          (usuario?['tipo_conta'] ?? '').toString().trim().toLowerCase() ==
              'profissional';

      String? fotoEmpresa;
      String nomeEmpresa = '';
      var souDono = false;
      var empresa = false;
      if (idUsuario != null) {
        final dadosProf = await _supabase
            .from('dados_profissionais')
            .select('id_profissional, fk_grupo_empresa, fk_perfil')
            .eq('fk_usuario', idUsuario)
            .maybeSingle();
        if (dadosProf != null) {
          ehProfissional = true;
          if (ativa) {
            // Dono do CNPJ (mesmo perfil) ou funcionário (fk_grupo_empresa).
            Map<String, dynamic>? grupo;
            if (dadosProf['fk_perfil'] != null) {
              grupo = await _supabase
                  .from('grupo_empresa')
                  .select('nome_empresa, foto_url_empresa')
                  .eq('fk_perfil', dadosProf['fk_perfil'])
                  .maybeSingle();
              souDono = grupo != null;
            }
            final idGrupo = (dadosProf['fk_grupo_empresa'] as num?)?.toInt();
            if (grupo == null && idGrupo != null) {
              grupo = await _supabase
                  .from('grupo_empresa')
                  .select('nome_empresa, foto_url_empresa')
                  .eq('id_grupo_empresa', idGrupo)
                  .maybeSingle();
            }
            empresa = grupo != null;
            fotoEmpresa = (grupo?['foto_url_empresa'] as String?)?.trim();
            if (fotoEmpresa != null && fotoEmpresa.isEmpty) fotoEmpresa = null;
            nomeEmpresa = (grupo?['nome_empresa'] as String?)?.trim() ?? '';
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isProfissional = ehProfissional;
        _contaEmpresaAtiva = ativa;
        _souDonoEmpresa = souDono;
        if (ativa && empresa) {
          // Conta de empresa: foto da empresa ou iniciais dela (nunca a
          // foto pessoal do profissional).
          _minhaFotoConta = fotoEmpresa;
          _meuNomeConta = nomeEmpresa.isNotEmpty ? nomeEmpresa : 'Empresa';
        } else {
          final fotoProf = (usuario?['foto_perfil_url'] as String?)?.trim();
          _minhaFotoConta = (fotoProf != null && fotoProf.isNotEmpty)
              ? fotoProf
              : null;
          _meuNomeConta = (usuario?['nome'] as String?)?.trim() ?? '';
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceReload?.cancel();
    _pollingLista?.cancel();
    _timerOnlineTicker?.cancel();
    if (_canalLista != null) {
      _supabase.removeChannel(_canalLista!);
    }
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarConversas({bool mostrarLoading = false}) async {
    if (mostrarLoading && mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _aplicarLista([]);
        return;
      }

      final usuario = await _supabase
          .from('usuarios')
          .select('id_usuario, tipo_conta')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) {
        _aplicarLista([]);
        return;
      }
      _idUsuarioLogado = idUsuario;

      // 1) Identifica se é profissional por prop, por tipo_conta ou por presença em dados_profissionais
      bool isProfissional =
          widget.isProfissional ||
          (usuario?['tipo_conta'] ?? '').toString().trim().toLowerCase() ==
              'profissional';

      bool temColunaGrupo = true;
      try {
        await _supabase
            .from('conversas')
            .select(
              'id_conversa, fk_usuario, fk_profissional, fk_grupo_empresa',
            )
            .limit(0);
      } catch (_) {
        temColunaGrupo = false;
      }

      Map<String, dynamic>? dadosProfMeu;
      try {
        dadosProfMeu = await _supabase
            .from('dados_profissionais')
            .select(
              temColunaGrupo
                  ? 'id_profissional, fk_grupo_empresa'
                  : 'id_profissional',
            )
            .eq('fk_usuario', idUsuario)
            .maybeSingle();
        if (dadosProfMeu != null) {
          isProfissional = true;
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _isProfissional = isProfissional);
      } else {
        _isProfissional = isProfissional;
      }

      final List<Map<String, dynamic>> conversas;
      var idsGrupos = <int>[];
      // Para separar as conversas da conta independente e da loja.
      int? idProfSeparar;
      int? idGrupoSeparar;

      if (isProfissional) {
        final idProf = (dadosProfMeu?['id_profissional'] as num?)?.toInt();
        var idGrupoMeu = (dadosProfMeu?['fk_grupo_empresa'] as num?)?.toInt();
        // Dono do CNPJ: a empresa é a do mesmo perfil (fk_perfil).
        if (idGrupoMeu == null && _contaEmpresaAtiva) {
          try {
            final dp = await _supabase
                .from('dados_profissionais')
                .select('fk_perfil')
                .eq('fk_usuario', idUsuario)
                .maybeSingle();
            final perfil = dp?['fk_perfil'];
            if (perfil != null) {
              final g = await _supabase
                  .from('grupo_empresa')
                  .select('id_grupo_empresa')
                  .eq('fk_perfil', perfil)
                  .maybeSingle();
              idGrupoMeu = (g?['id_grupo_empresa'] as num?)?.toInt();
            }
          } catch (_) {}
        }
        // A loja do dono também vale na conta independente (para esconder
        // os contatos que são só da loja).
        if (idGrupoMeu == null) {
          try {
            final dp = await _supabase
                .from('dados_profissionais')
                .select('fk_perfil')
                .eq('fk_usuario', idUsuario)
                .limit(1)
                .maybeSingle();
            final perfil = dp?['fk_perfil'];
            if (perfil != null) {
              final g = await _supabase
                  .from('grupo_empresa')
                  .select('id_grupo_empresa')
                  .eq('fk_perfil', perfil)
                  .limit(1)
                  .maybeSingle();
              idGrupoSeparar = (g?['id_grupo_empresa'] as num?)?.toInt();
            }
          } catch (_) {}
        } else {
          idGrupoSeparar = idGrupoMeu;
        }
        idProfSeparar = idProf;
        if (idProf == null && idGrupoMeu == null) {
          _aplicarLista([]);
          return;
        }
        final todas = <Map<String, dynamic>>[];
        if (_contaEmpresaAtiva) {
          if (temColunaGrupo && idGrupoMeu != null) {
            final daEmpresa = await _supabase
                .from('conversas')
                .select()
                .eq('fk_grupo_empresa', idGrupoMeu);
            todas.addAll(
              (daEmpresa as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            );
          }
        } else {
          // Chats individuais do profissional
          if (idProf != null) {
            final query = _supabase.from('conversas').select();
            dynamic q = query.eq('fk_profissional', idProf);
            // Conta independente: nunca as conversas da loja.
            if (temColunaGrupo) {
              q = q.isFilter('fk_grupo_empresa', null);
            }
            todas.addAll(
              (await q as List).map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        }
        conversas = todas;
      } else {
        conversas = await _supabase
            .from('conversas')
            .select()
            .eq('fk_usuario', idUsuario);
      }

      if (conversas.isEmpty) {
        _aplicarLista([]);
        return;
      }

      final idsConversas = {
        ...conversas
            .map((row) => (row['id_conversa'] as num?)?.toInt())
            .whereType<int>(),
      }.toList();

      final ultimaPorConversa = <int, Map<String, dynamic>>{};
      final naoLidasPorConversa = <int, int>{};
      final remetentesOutrosPorConversa = <int, Set<int>>{};
      try {
        final mensagens = await _buscarMensagens(idsConversas);
        for (final mensagem in mensagens) {
          final id = (mensagem['fk_conversa'] as num?)?.toInt();
          if (id == null) continue;
          if (!ultimaPorConversa.containsKey(id)) {
            ultimaPorConversa[id] = Map<String, dynamic>.from(mensagem);
          }
          final remetente = (mensagem['fk_remitente_usuario'] as num?)?.toInt();
          if (remetente != null && remetente != idUsuario) {
            remetentesOutrosPorConversa
                .putIfAbsent(id, () => <int>{})
                .add(remetente);
            if (mensagem['lida'] != true) {
              naoLidasPorConversa[id] = (naoLidasPorConversa[id] ?? 0) + 1;
            }
          }
        }
      } catch (_) {}

      // Contato da OUTRA conta (loja x independente): a conversa desta conta
      // só aparece se tiver mensagens (antes aparecia o contato vazio).
      if (isProfissional && temColunaGrupo) {
        try {
          final outrosClientes = <int>{};
          if (_contaEmpresaAtiva) {
            if (idProfSeparar != null) {
              final r = await _supabase
                  .from('conversas')
                  .select('fk_usuario')
                  .eq('fk_profissional', idProfSeparar)
                  .isFilter('fk_grupo_empresa', null);
              for (final c in r as List) {
                final u = (c['fk_usuario'] as num?)?.toInt();
                if (u != null) outrosClientes.add(u);
              }
            }
          } else if (idGrupoSeparar != null) {
            final r = await _supabase
                .from('conversas')
                .select('fk_usuario')
                .eq('fk_grupo_empresa', idGrupoSeparar);
            for (final c in r as List) {
              final u = (c['fk_usuario'] as num?)?.toInt();
              if (u != null) outrosClientes.add(u);
            }
          }
          // Pedidos da outra conta ligados a conversas desta.
          final solOutraConta = <int>{};
          final idsSol = {
            for (final c in conversas)
              if ((c['fk_solicitacao'] as num?) != null)
                (c['fk_solicitacao'] as num).toInt(),
          };
          if (idsSol.isNotEmpty) {
            final sols = await _supabase
                .from('solicitacoes')
                .select('id_solicitacao, fk_grupo_empresa')
                .inFilter('id_solicitacao', idsSol.toList());
            for (final s in sols as List) {
              final ehLoja = s['fk_grupo_empresa'] != null;
              if (ehLoja != _contaEmpresaAtiva) {
                solOutraConta.add((s['id_solicitacao'] as num).toInt());
              }
            }
          }
          conversas.removeWhere((c) {
            final id = (c['id_conversa'] as num?)?.toInt();
            if (id == null || ultimaPorConversa.containsKey(id)) return false;
            final cliente = (c['fk_usuario'] as num?)?.toInt();
            final sol = (c['fk_solicitacao'] as num?)?.toInt();
            return outrosClientes.contains(cliente) ||
                (sol != null && solOutraConta.contains(sol));
          });
        } catch (e) {
          debugPrint('[mensagens] separar contas: $e');
        }
        if (conversas.isEmpty) {
          _aplicarLista([]);
          return;
        }
      }

      final servicoPorConversa = <int, String>{};
      final clientePorSolicitacao = <int, int>{};
      try {
        final idsSolicitacao = {
          ...conversas
              .map((row) => (row['fk_solicitacao'] as num?)?.toInt())
              .whereType<int>(),
        }.toList();
        if (idsSolicitacao.isNotEmpty) {
          final solicitacoes = await _supabase
              .from('solicitacoes')
              .select(
                'id_solicitacao, data_aceite, fk_servico_prof, fk_usuario',
              )
              .inFilter('id_solicitacao', idsSolicitacao);
          for (final row in solicitacoes as List) {
            final idSol = (row['id_solicitacao'] as num?)?.toInt();
            final idCliSol = (row['fk_usuario'] as num?)?.toInt();
            if (idSol != null && idCliSol != null && idCliSol != idUsuario) {
              clientePorSolicitacao[idSol] = idCliSol;
            }
          }

          final idsServico = {
            ...solicitacoes
                .where(
                  (row) =>
                      row['data_aceite'] != null &&
                      row['fk_servico_prof'] != null,
                )
                .map((row) => (row['fk_servico_prof'] as num?)?.toInt())
                .whereType<int>(),
          }.toList();
          if (idsServico.isNotEmpty) {
            final servicos = await _supabase
                .from('servicos_profissional')
                .select('id_servico_prof, titulo')
                .inFilter('id_servico_prof', idsServico);
            final tituloPorServico = <int, String>{
              for (final row in servicos)
                if ((row['id_servico_prof'] as num?) != null &&
                    row['titulo'] != null)
                  (row['id_servico_prof'] as num).toInt(): row['titulo']
                      .toString(),
            };
            final solicitacaoPorId = <int, Map<String, dynamic>>{
              for (final row in solicitacoes)
                if ((row['id_solicitacao'] as num?) != null)
                  (row['id_solicitacao'] as num).toInt():
                      Map<String, dynamic>.from(row),
            };
            for (final conv in conversas) {
              final idSol = (conv['fk_solicitacao'] as num?)?.toInt();
              if (idSol == null) continue;
              final solicitacao = solicitacaoPorId[idSol];
              if (solicitacao == null || solicitacao['data_aceite'] == null) {
                continue;
              }
              final idServ = (solicitacao['fk_servico_prof'] as num?)?.toInt();
              final titulo = idServ == null ? null : tituloPorServico[idServ];
              final idConv = (conv['id_conversa'] as num?)?.toInt();
              if (idConv != null && titulo != null && titulo.isNotEmpty) {
                servicoPorConversa[idConv] = titulo;
              }
            }
          }
        }
      } catch (_) {}

      final Map<int, Map<String, dynamic>> contatoPorChave;
      final Map<int, int> clientePorConversa =
          {}; // idConversa -> idUsuario do cliente

      if (isProfissional) {
        final idsClientes = <int>{};
        for (final conv in conversas) {
          final idConv = (conv['id_conversa'] as num?)?.toInt();
          if (idConv == null) continue;
          final fkUser = (conv['fk_usuario'] as num?)?.toInt();

          int? idCliente;
          if (fkUser != null && fkUser != idUsuario) {
            idCliente = fkUser;
          } else {
            // Se fk_usuario foi preenchido com o próprio profissional logado,
            // identifica o cliente real pelo remetente das mensagens que não seja eu
            final outros = remetentesOutrosPorConversa[idConv];
            if (outros != null && outros.isNotEmpty) {
              idCliente = outros.first;
            } else {
              // Ou pela solicitação vinculada
              final idSol = (conv['fk_solicitacao'] as num?)?.toInt();
              if (idSol != null && clientePorSolicitacao.containsKey(idSol)) {
                idCliente = clientePorSolicitacao[idSol];
              }
            }
          }

          if (idCliente != null) {
            clientePorConversa[idConv] = idCliente;
            idsClientes.add(idCliente);
          }
        }

        if (idsClientes.isNotEmpty) {
          final usuarios = await _buscarUsuarios(idsClientes.toList());
          contatoPorChave = {
            for (final row in usuarios)
              if ((row['id_usuario'] as num?) != null)
                (row['id_usuario'] as num).toInt(): Map<String, dynamic>.from(
                  row,
                ),
          };
        } else {
          contatoPorChave = {};
        }
      } else {
        final idsProfissional = {
          ...conversas
              .map((row) => (row['fk_profissional'] as num?)?.toInt())
              .whereType<int>(),
        }.toList();
        final idsGruposCliente = {
          ...conversas
              .map((row) => (row['fk_grupo_empresa'] as num?)?.toInt())
              .whereType<int>(),
        }.toList();
        idsGrupos = idsGruposCliente;
        // Cliente vê chats individuais (fk_profissional) E chats da empresa
        // (fk_grupo_empresa). Se não há nenhum dos dois, lista vazia.
        if (idsProfissional.isEmpty && idsGruposCliente.isEmpty) {
          _aplicarLista([]);
          return;
        }
        Map<int, Map<String, dynamic>> dadosPorId = {};
        if (idsProfissional.isNotEmpty) {
          final dados = await _supabase
              .from('dados_profissionais')
              .select('id_profissional, fk_usuario')
              .inFilter('id_profissional', idsProfissional);
          dadosPorId = <int, Map<String, dynamic>>{
            for (final row in dados)
              if ((row['id_profissional'] as num?) != null)
                (row['id_profissional'] as num).toInt():
                    Map<String, dynamic>.from(row),
          };
        }
        final idsUsuariosProf = {
          ...dadosPorId.values
              .map((row) => (row['fk_usuario'] as num?)?.toInt())
              .whereType<int>(),
        }.toList();
        if (idsUsuariosProf.isEmpty && idsGruposCliente.isEmpty) {
          _aplicarLista([]);
          return;
        }
        Map<int, Map<String, dynamic>> usuarioPorId = {};
        if (idsUsuariosProf.isNotEmpty) {
          final usuarios = await _buscarUsuarios(idsUsuariosProf);
          usuarioPorId = <int, Map<String, dynamic>>{
            for (final row in usuarios)
              if ((row['id_usuario'] as num?) != null)
                (row['id_usuario'] as num).toInt(): Map<String, dynamic>.from(
                  row,
                ),
          };
        }
        contatoPorChave = <int, Map<String, dynamic>>{
          for (final entrada in dadosPorId.entries)
            if (usuarioPorId[(entrada.value['fk_usuario'] as num?)?.toInt()] !=
                null)
              entrada.key:
                  usuarioPorId[(entrada.value['fk_usuario'] as num).toInt()]!,
        };
      }

      final nomePorGrupo = <int, String>{};
      final fotoPorGrupo = <int, String>{};
      if (idsGrupos.isNotEmpty) {
        try {
          final gruposRows = await _supabase
              .from('grupo_empresa')
              .select('id_grupo_empresa, nome_empresa, foto_url_empresa')
              .inFilter('id_grupo_empresa', idsGrupos);
          for (final row in gruposRows as List) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = (map['id_grupo_empresa'] as num?)?.toInt();
            if (id == null) continue;
            nomePorGrupo[id] = map['nome_empresa']?.toString() ?? 'Empresa';
            fotoPorGrupo[id] = map['foto_url_empresa']?.toString() ?? '';
          }
        } catch (_) {}
      }
      final oficioPorProfissional = <int, String>{};
      if (!isProfissional) {
        try {
          final idsProf = contatoPorChave.keys.toList();
          if (idsProf.isNotEmpty) {
            final assocs = await _supabase
                .from('ass_oficio_profissional')
                .select('fk_profissional, fk_funcao')
                .inFilter('fk_profissional', idsProf);
            final idsOficio = assocs
                .map((r) => (r['fk_funcao'] as num?)?.toInt())
                .whereType<int>()
                .toSet()
                .toList();
            if (idsOficio.isNotEmpty) {
              final oficios = await _supabase
                  .from('funcoes')
                  .select(kColunasFuncaoComoOficio)
                  .inFilter('id_funcao', idsOficio);
              final funcaoPorId = <int, String>{
                for (final row in oficios)
                  if ((row['id_oficio'] as num?) != null)
                    (row['id_oficio'] as num).toInt():
                        row['funcao']?.toString() ?? '',
              };
              for (final row in assocs) {
                final idP = (row['fk_profissional'] as num?)?.toInt();
                final idO = (row['fk_funcao'] as num?)?.toInt();
                if (idP != null &&
                    idO != null &&
                    !oficioPorProfissional.containsKey(idP)) {
                  final funcao = funcaoPorId[idO] ?? '';
                  if (funcao.isNotEmpty) oficioPorProfissional[idP] = funcao;
                }
              }
            }
          }
        } catch (_) {}
      }

      final resultado = <_ConversaResumo>[];
      for (final conv in conversas) {
        final idConv = (conv['id_conversa'] as num?)?.toInt();
        if (idConv == null) continue;
        final idGrupoConv = (conv['fk_grupo_empresa'] as num?)?.toInt();
        final ehEmpresa = idGrupoConv != null;

        final ultima = ultimaPorConversa[idConv];
        final remetenteUltima = (ultima?['fk_remitente_usuario'] as num?)
            ?.toInt();
        final ultimaLida = ultima?['lida'] == true;
        final ultimaEnviadaPorMim =
            remetenteUltima != null && remetenteUltima == idUsuario;
        final ultimaRecebida =
            remetenteUltima != null && remetenteUltima != idUsuario;
        // Do meu lado da conversa (na empresa, qualquer membro).
        final ladoMeu = isProfissional
            ? remetenteUltima != null &&
                  remetenteUltima != clientePorConversa[idConv]
            : ultimaEnviadaPorMim;
        final previa = _previaMensagem(ultima, enviadaPorMim: ladoMeu);
        final ehProposta = _ehProposta(ultima);

        if (isProfissional) {
          final idCliente = clientePorConversa[idConv];
          final contato = idCliente != null ? contatoPorChave[idCliente] : null;

          final nomeContato =
              contato?['nome']?.toString().trim().isNotEmpty == true
              ? contato!['nome'].toString().trim()
              : 'Cliente';
          final fotoUrl = contato?['foto_perfil_url']?.toString().trim() ?? '';

          resultado.add(
            _ConversaResumo(
              idConversa: idConv,
              idCliente: idCliente,
              idSolicitacao: (conv['fk_solicitacao'] as num?)?.toInt(),
              nomeContato: nomeContato,
              fotoUrl: fotoUrl,
              oficioContato: 'Cliente',
              idProfissional: null,
              idGrupoEmpresa: ehEmpresa ? idGrupoConv : null,
              ehChatEmpresa: ehEmpresa,
              servicoAssociado: servicoPorConversa[idConv],
              ultimaConexaoContato: DateTime.tryParse(
                contato?['ultima_conexao']?.toString() ?? '',
              ),
              ultimaMensagem: previa,
              ehProposta: ehProposta,
              tipoUltimaMensagem: ultima?['tipo_mensagem']?.toString(),
              dataUltimaMensagem: DateTime.tryParse(
                ultima?['data_envio']?.toString() ?? '',
              ),
              mensagensNaoLidas: naoLidasPorConversa[idConv] ?? 0,
              ultimaMensagemRecebida: ultimaRecebida,
              ultimaMensagemLida: ultimaLida,
              ultimaMensagemEnviadaPorMim: ultimaEnviadaPorMim,
            ),
          );
          continue;
        }

        if (ehEmpresa) {
          resultado.add(
            _ConversaResumo(
              idConversa: idConv,
              idSolicitacao: (conv['fk_solicitacao'] as num?)?.toInt(),
              nomeContato: nomePorGrupo[idGrupoConv] ?? 'Empresa',
              fotoUrl: fotoPorGrupo[idGrupoConv] ?? '',
              oficioContato: 'Loja e Oficina Especializada',
              idProfissional: null,
              idGrupoEmpresa: idGrupoConv,
              ehChatEmpresa: true,
              servicoAssociado: servicoPorConversa[idConv],
              ultimaConexaoContato: null,
              ultimaMensagem: previa,
              ehProposta: ehProposta,
              tipoUltimaMensagem: ultima?['tipo_mensagem']?.toString(),
              dataUltimaMensagem: DateTime.tryParse(
                ultima?['data_envio']?.toString() ?? '',
              ),
              mensagensNaoLidas: naoLidasPorConversa[idConv] ?? 0,
              ultimaMensagemRecebida: ultimaRecebida,
              ultimaMensagemLida: ultimaLida,
              ultimaMensagemEnviadaPorMim: ultimaEnviadaPorMim,
            ),
          );
          continue;
        }

        final chaveContato = (conv['fk_profissional'] as num?)?.toInt();
        final contato = chaveContato == null
            ? null
            : contatoPorChave[chaveContato];
        if (contato == null) continue;

        resultado.add(
          _ConversaResumo(
            idConversa: idConv,
            idSolicitacao: (conv['fk_solicitacao'] as num?)?.toInt(),
            nomeContato: contato['nome']?.toString() ?? 'Nome não encontrado',
            fotoUrl: contato['foto_perfil_url']?.toString() ?? '',
            oficioContato: oficioPorProfissional[chaveContato] ?? '',
            idProfissional: chaveContato,
            idGrupoEmpresa: null,
            ehChatEmpresa: false,
            servicoAssociado: servicoPorConversa[idConv],
            ultimaConexaoContato: DateTime.tryParse(
              contato['ultima_conexao']?.toString() ?? '',
            ),
            ultimaMensagem: previa,
            ehProposta: ehProposta,
            tipoUltimaMensagem: ultima?['tipo_mensagem']?.toString(),
            dataUltimaMensagem: DateTime.tryParse(
              ultima?['data_envio']?.toString() ?? '',
            ),
            mensagensNaoLidas: naoLidasPorConversa[idConv] ?? 0,
            ultimaMensagemRecebida: ultimaRecebida,
            ultimaMensagemLida: ultimaLida,
            ultimaMensagemEnviadaPorMim: ultimaEnviadaPorMim,
          ),
        );
      }

      if (resultado.isEmpty) {
        _aplicarLista([]);
        return;
      }
      await _completarExtras(resultado, isProfissional, idUsuario);

      final unicasPorCliente = <int, _ConversaResumo>{};
      final semCliente = <_ConversaResumo>[];
      for (final conversa in resultado) {
        if (!isProfissional || conversa.idCliente == null) {
          semCliente.add(conversa);
          continue;
        }
        final anterior = unicasPorCliente[conversa.idCliente!];
        if (anterior == null || _maisRecente(conversa, anterior)) {
          unicasPorCliente[conversa.idCliente!] = conversa;
        }
      }
      final listaUnica = isProfissional
          ? [...unicasPorCliente.values, ...semCliente]
          : resultado;

      listaUnica.sort((a, b) {
        final fa = a.dataUltimaMensagem;
        final fb = b.dataUltimaMensagem;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });

      _aplicarLista(listaUnica);
    } catch (erro) {
      if (_eTabelaIndisponivel(erro)) {
        _aplicarLista([]);
        return;
      }
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as conversas.';
      });
    }
  }

  bool _maisRecente(_ConversaResumo atual, _ConversaResumo anterior) {
    final dataAtual = atual.dataUltimaMensagem;
    final dataAnterior = anterior.dataUltimaMensagem;
    if (dataAtual == null) return false;
    if (dataAnterior == null) return true;
    return dataAtual.isAfter(dataAnterior);
  }

  void _aplicarLista(List<_ConversaResumo> lista) {
    if (!mounted) return;
    setState(() {
      _conversas = lista;
      _carregando = false;
      _erro = null;
    });
  }

  void _assinarAtualizacoes() {
    _pollingLista?.cancel();
    if (_canalLista != null) {
      _supabase.removeChannel(_canalLista!);
      _canalLista = null;
    }

    final canal = _supabase.channel(
      'lista_mensagens_realtime_${_idUsuarioLogado ?? 0}_${DateTime.now().millisecondsSinceEpoch}',
    );
    _canalLista = canal;

    // Escuta novas mensagens e alterações em conversas em tempo real
    canal.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'mensagens',
      callback: (_) => _agendarRecarregar(),
    );
    canal.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversas',
      callback: (_) => _agendarRecarregar(),
    );
    canal.subscribe();

    // Polling a cada 4 segundos como garantia para atualizações silenciosas em segundo plano
    _pollingLista = Timer.periodic(const Duration(seconds: 4), (_) {
      _carregarConversas();
    });
  }

  void _agendarRecarregar() {
    _debounceReload?.cancel();
    _debounceReload = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _carregarConversas();
    });
  }

  static bool _eTabelaIndisponivel(Object erro) {
    if (erro is! PostgrestException) return false;
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '42P01' ||
        (texto.contains('conversas') || texto.contains('mensagens')) &&
            (texto.contains('not found') ||
                texto.contains('does not exist') ||
                texto.contains('relation') ||
                texto.contains('schema cache'));
  }

  Future<List<Map<String, dynamic>>> _buscarUsuarios(List<int> ids) async {
    try {
      return await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url, ultima_conexao')
          .inFilter('id_usuario', ids);
    } catch (_) {
      return await _supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .inFilter('id_usuario', ids);
    }
  }

  Future<List<Map<String, dynamic>>> _buscarMensagens(List<int> ids) async {
    try {
      return await _supabase
          .from('mensagens')
          .select(
            'fk_conversa, conteudo, data_envio, fk_remitente_usuario, lida, tipo_mensagem',
          )
          .inFilter('fk_conversa', ids)
          .order('data_envio', ascending: false)
          .limit(300);
    } catch (_) {
      return await _supabase
          .from('mensagens')
          .select('fk_conversa, conteudo, data_envio, fk_remitente_usuario')
          .inFilter('fk_conversa', ids)
          .order('data_envio', ascending: false)
          .limit(300);
    }
  }

  /// Prévia amigável da última mensagem (foto, documento, áudio ou texto).
  /// Funções/tag do profissional ou da loja (visão do cliente) e a
  /// solicitação em curso de cada conversa (título + status).
  Future<void> _completarExtras(
    List<_ConversaResumo> lista,
    bool isProfissional,
    int idUsuario,
  ) async {
    final funcoesProf = <int, List<String>>{};
    final funcoesGrupo = <int, List<String>>{};
    final tagGrupo = <int, (String?, String?)>{};
    if (!isProfissional) {
      final idsProf = {
        for (final c in lista)
          if (!c.ehChatEmpresa && c.idProfissional != null) c.idProfissional!,
      };
      final idsGrupo = {
        for (final c in lista)
          if (c.ehChatEmpresa && c.idGrupoEmpresa != null) c.idGrupoEmpresa!,
      };
      try {
        if (idsProf.isNotEmpty) {
          final r = await _supabase
              .from('ass_oficio_profissional')
              .select('fk_profissional, funcoes(funcao)')
              .inFilter('fk_profissional', idsProf.toList());
          for (final x in r) {
            final f = x['funcoes'];
            final nome = f is Map ? f['funcao']?.toString() : null;
            if (nome == null || nome.isEmpty) continue;
            final l = funcoesProf.putIfAbsent(
              (x['fk_profissional'] as num).toInt(),
              () => [],
            );
            if (!l.contains(nome)) l.add(nome);
          }
        }
        if (idsGrupo.isNotEmpty) {
          final r = await _supabase
              .from('ass_oficio_grupo_empresa')
              .select('fk_grupo_empresa, funcoes(funcao)')
              .inFilter('fk_grupo_empresa', idsGrupo.toList());
          for (final x in r) {
            final f = x['funcoes'];
            final nome = f is Map ? f['funcao']?.toString() : null;
            if (nome == null || nome.isEmpty) continue;
            final l = funcoesGrupo.putIfAbsent(
              (x['fk_grupo_empresa'] as num).toInt(),
              () => [],
            );
            if (!l.contains(nome)) l.add(nome);
          }
          final g = await _supabase
              .from('grupo_empresa')
              .select('id_grupo_empresa, tag_empresa, cor_tag_empresa')
              .inFilter('id_grupo_empresa', idsGrupo.toList());
          for (final x in g) {
            final t = x['tag_empresa']?.toString().trim() ?? '';
            tagGrupo[(x['id_grupo_empresa'] as num).toInt()] = (
              t.isEmpty ? null : (t.startsWith('#') ? t : '#$t').toUpperCase(),
              x['cor_tag_empresa']?.toString(),
            );
          }
        }
      } catch (e) {
        debugPrint('[mensagens] funções: $e');
      }
    }

    // Solicitações em curso (não concluídas/canceladas/recusadas).
    final ativas = <String, (String, EstiloStatus)>{};
    try {
      var q = _supabase
          .from('solicitacoes')
          .select(
            'id_solicitacao, fk_status, tipo_execucao, etapa_solicitacao, '
            'fk_usuario, fk_profissional, fk_grupo_empresa, '
            'servicos_profissional(titulo), servicos_chat_temporarios(titulo)',
          )
          .not('fk_status', 'in', '(6,7,30)');
      if (isProfissional) {
        final clientes = {
          for (final c in lista)
            if (c.idCliente != null) c.idCliente!,
        };
        if (clientes.isEmpty)
          return _aplicarExtras(
            lista,
            funcoesProf,
            funcoesGrupo,
            tagGrupo,
            ativas,
          );
        q = q.inFilter('fk_usuario', clientes.toList());
      } else {
        q = q.eq('fk_usuario', idUsuario);
      }
      final rows = await q.order('data_solicitacao', ascending: false);
      for (final r in rows) {
        final sp = r['servicos_profissional'];
        final st = r['servicos_chat_temporarios'];
        final titulo =
            (sp is Map ? sp['titulo'] : null)?.toString() ??
            (st is Map ? st['titulo'] : null)?.toString() ??
            'Serviço';
        final estilo = EstiloStatus.de(
          fkStatus: (r['fk_status'] as num?)?.toInt(),
          tipoExecucao: r['tipo_execucao']?.toString(),
          etapa: (r['etapa_solicitacao'] as num?)?.toInt() ?? 0,
        );
        final grupo = (r['fk_grupo_empresa'] as num?)?.toInt();
        final chave = isProfissional
            ? 'c${r['fk_usuario']}|${grupo ?? 'p${r['fk_profissional']}'}'
            : (grupo != null ? 'g$grupo' : 'p${r['fk_profissional']}');
        ativas.putIfAbsent(chave, () => (titulo, estilo));
      }
    } catch (e) {
      debugPrint('[mensagens] solicitações ativas: $e');
    }
    _aplicarExtras(lista, funcoesProf, funcoesGrupo, tagGrupo, ativas);
  }

  void _aplicarExtras(
    List<_ConversaResumo> lista,
    Map<int, List<String>> funcoesProf,
    Map<int, List<String>> funcoesGrupo,
    Map<int, (String?, String?)> tagGrupo,
    Map<String, (String, EstiloStatus)> ativas,
  ) {
    for (var i = 0; i < lista.length; i++) {
      final c = lista[i];
      final String chave;
      if (_isProfissional) {
        // Conversa da empresa x conversa individual do profissional.
        final lado = c.ehChatEmpresa ? '${c.idGrupoEmpresa}' : null;
        chave = lado != null
            ? 'c${c.idCliente}|$lado'
            : ativas.keys.firstWhere(
                (k) => k.startsWith('c${c.idCliente}|p'),
                orElse: () => '',
              );
      } else {
        chave = c.ehChatEmpresa
            ? 'g${c.idGrupoEmpresa}'
            : 'p${c.idProfissional}';
      }
      final ativa = ativas[chave];
      final tag = c.idGrupoEmpresa != null ? tagGrupo[c.idGrupoEmpresa] : null;
      lista[i] = c.comExtras(
        funcoes: c.ehChatEmpresa
            ? funcoesGrupo[c.idGrupoEmpresa]
            : funcoesProf[c.idProfissional],
        tagEmpresa: tag?.$1,
        corTagEmpresa: tag?.$2,
        tituloAtiva: ativa?.$1,
        estiloAtiva: ativa?.$2,
      );
    }
  }

  bool _ehProposta(Map<String, dynamic>? ultima) {
    if (ultima == null) return false;
    final tipo = (ultima['tipo_mensagem']?.toString() ?? '').toLowerCase();
    final conteudo = ultima['conteudo']?.toString() ?? '';
    return tipo == 'proposta' ||
        conteudo.contains('"tipo":"proposta_personalizada"');
  }

  String? _previaMensagem(
    Map<String, dynamic>? ultima, {
    bool enviadaPorMim = false,
  }) {
    if (ultima == null) return null;

    final tipo = (ultima['tipo_mensagem']?.toString() ?? 'Texto').toLowerCase();
    final conteudo = ultima['conteudo']?.toString() ?? '';
    if (_ehProposta(ultima)) {
      return enviadaPorMim ? 'Proposta enviada' : 'Proposta recebida';
    }

    if (tipo == 'imagem') return 'Foto';
    if (tipo == 'audio') return 'Áudio';
    if (tipo == 'documento') {
      final nome =
          ChatAnexosService.separarConteudoDocumento(conteudo)?.nome ?? '';
      return nome.isEmpty ? 'Documento' : nome;
    }
    return conteudo;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisitante && !_carregando) {
      tutorialDaTela(
        chave: widget.isProfissional ? 'mensagens_prof' : 'mensagens_cliente',
        passos: () => [
          PassoTutorial(
            widget.isProfissional
                ? 'Aqui ficam as conversas com os seus clientes. Use a busca '
                      'para achar alguém.'
                : 'Aqui ficam as conversas com os profissionais. Use a busca '
                      'para achar alguém.',
            alvo: chaveTut('busca'),
            raio: 28,
          ),
          PassoTutorial(
            'Cada conversa mostra o pedido em andamento e quantas mensagens '
            'você ainda não leu. Toque para abrir o chat.',
            alvo: chaveTut('lista'),
          ),
        ],
      );
    }
    return AppBackHandler(
      child: Scaffold(
        backgroundColor: _background,
        appBar: BarraCorOriginal(child: AppBar(
          backgroundColor: _primaryBlue,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: _voltarParaHome,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          title: const Text(
            'Mensagens',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
          // Foto da MINHA conta (empresa ou profissional) no topo direito,
          // circular com borda azul 0xFF0FB3FF.
          actions: [
            BotaoAjuda(
              cor: Colors.white,
              passos: () => passosAjuda(
                reserva: () => explicacaoDaTela(
                  context,
                  tela: 'Aqui ficam as suas conversas.',
                  conteudo: ['Toque em uma conversa para abrir o chat.'],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: _abrirMinhaConta,
                  child: _buildAvatarMinhaConta(),
                ),
              ),
            ),
          ],
        )),
        body: Column(
          children: [
            alvoTut('busca', _buildBarraPesquisa()),
            Expanded(key: chaveTut('lista'), child: _buildLista()),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildLista() {
    if (_carregando && _conversas.isEmpty) {
      return const SkeletonPage(layout: SkeletonLayout.messages);
    }
    if (_erro != null && _conversas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMuted),
          ),
        ),
      );
    }

    final termo = _termoBusca.trim().toLowerCase();
    final conversas = _conversas
        .where(
          (conversa) =>
              termo.isEmpty ||
              conversa.nomeContato.toLowerCase().contains(termo) ||
              conversa.subtituloServico.toLowerCase().contains(termo) ||
              (conversa.ultimaMensagem ?? '').toLowerCase().contains(termo),
        )
        .toList();

    if (conversas.isEmpty) {
      return _buildEstadoVazio(termo.isNotEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: conversas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCard(conversas[index]);
      },
    );
  }

  /// Foto da minha conta: perfil do cliente/profissional ou gestão da
  /// empresa (dono). Funcionário da empresa não vai para lugar nenhum.
  void _abrirMinhaConta() {
    final Widget? destino;
    if (!_isProfissional) {
      destino = const TelaMeuPerfilClientePage();
    } else if (_contaEmpresaAtiva) {
      destino = _souDonoEmpresa ? const GestaoEquipePage() : null;
    } else {
      destino = const TelaMeuPerfilProfissionalPage(isVisitante: false);
    }
    if (destino == null) return;
    final pagina = destino;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pagina))
        .then((_) => _carregarContaAtivaEMinhaFoto());
  }

  Widget _buildAvatarMinhaConta() {
    final foto = (_minhaFotoConta ?? '').trim();
    final nomeBase = _meuNomeConta.trim().isNotEmpty
        ? _meuNomeConta.trim()
        : 'Conta';
    final Widget imagem;
    if (foto.startsWith('http')) {
      imagem = CorOriginal(child: CircleAvatar(
        radius: 15,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(foto),
      ));
    } else {
      imagem = CircleAvatar(
        radius: 15,
        backgroundColor: const Color(0xFFDCE5EE),
        child: Text(
          obterIniciais(nomeBase),
          style: const TextStyle(
            color: Color(0xFF5E6F7E),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }
    // Circular com borda azul 0xFF0FB3FF.
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _primaryBlue, width: 2),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(child: imagem),
    );
  }

  Widget _buildBarraPesquisa() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _buscaController,
          onChanged: (value) => setState(() => _termoBusca = value),
          style: const TextStyle(fontSize: 15, color: _titleDark),
          decoration: InputDecoration(
            hintText: 'Pesquisar...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (_isProfissional) {
      // Sem prop isContaEmpresa: a barra resolve sozinha pelo cache
      // interno — sem piscar Perfil/Empresa na abertura, igual às
      // demais telas. Mesma chave da Gestão: reutiliza o elemento ao
      // alternar Gestão <-> Mensagens, sem reconstruir.
      return BottomNavigationBarProfissional(
        key: const ValueKey('bottomProfissional'),
        currentIndex: 2,
        // Tocar em Mensagens estando em Mensagens recarrega a lista.
        onReselecionarAbaAtual: (_) => _carregarConversas(mostrarLoading: true),
        onTap: _navegar,
      );
    }
    return BottomNavigationBarCliente(
      currentIndex: 2,
      // Tocar em Mensagens estando em Mensagens recarrega a lista.
      onReselecionarAbaAtual: (_) => _carregarConversas(mostrarLoading: true),
      onTap: _navegar,
    );
  }

  void _navegar(int index) {
    if (index == 0) {
      AppNavigationUtil.navegarAba(
        context,
        _isProfissional
            ? TelaHomeProfissional(isVisitante: widget.isVisitante)
            : TelaHome(isVisitante: widget.isVisitante),
        isHome: true,
      );
    } else if (index == 1 && !_isProfissional) {
      AppNavigationUtil.navegarAba(
        context,
        SolicitacaoGeograficaClientePage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    } else if (index == 1 && _isProfissional) {
      Navigator.of(context).push(
        AppNavigationUtil.rotaSemAnimacao(
          SolicitacaoGeograficaProfissionalPage(
            isVisitante: widget.isVisitante,
          ),
          nome: 'SolicitacaoGeograficaProfissionalPage',
        ),
      );
    } else if (index == 3 && !_isProfissional) {
      AppNavigationUtil.navegarAba(
        context,
        MeusPedidosPage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    } else if (index == 3 && _isProfissional) {
      // Aba Serviços do profissional: abre os serviços solicitados
      // (conta independente ou empresa), igual à home do profissional.
      Navigator.of(context).push(
        AppNavigationUtil.rotaSemAnimacao(
          const MeusServicosSolicitadosPage(),
          nome: 'MeusServicosSolicitadosPage',
        ),
      );
    } else if (index == 4) {
      // 5º botão: conta empresa -> "Empresa" (gestão), senão "Perfil".
      // Usa o cache síncrono (igual às demais telas), sem depender do
      // setState assíncrono de _contaEmpresaAtiva.
      final ehEmpresa =
          BottomNavigationBarProfissional.leituraSincronaContaEmpresa();
      if (_isProfissional && ehEmpresa) {
        Navigator.of(context).push(
          AppNavigationUtil.rotaSemAnimacao(
            const GestaoEquipePage(),
            nome: 'GestaoEquipePage',
          ),
        );
        return;
      }
      AppNavigationUtil.navegarAba(
        context,
        _isProfissional
            ? TelaMeuPerfilProfissionalPage(isVisitante: widget.isVisitante)
            : TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
        isHome: false,
      );
    }
  }

  void _voltarParaHome() {
    AppNavigationUtil.tratarBotaoVoltar(context, isHome: false);
  }

  Widget _buildEstadoVazio(bool pesquisaAtiva) {
    if (pesquisaAtiva) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma conversa encontrada',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tente buscar por outro termo ou nome.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final titulo = _isProfissional
        ? 'Você ainda não contatou nem foi contatado por nenhum cliente'
        : 'Você ainda não contatou nenhum profissional';

    final subtitulo = _isProfissional
        ? 'Quando um cliente iniciar um atendimento ou você enviar uma mensagem, as conversas aparecerão aqui.'
        : 'Quando você iniciar uma conversa com um profissional para solicitar um serviço, ela aparecerá aqui.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F6FD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _titleDark,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_ConversaResumo conversa) {
    final destaqueNaoLida = conversa.temNaoLidas;
    final textoDataHora = _formatarDataHoraUltimaMensagem(
      conversa.dataUltimaMensagem,
    );

    // Cores e estilos fiéis ao design
    final corHorario = destaqueNaoLida ? _unreadAccent : _textMuted;
    final corServico = destaqueNaoLida ? _unreadAccent : _textMuted;
    final corMensagem = destaqueNaoLida ? _titleDark : _textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TelaChatProfissional(
                nomeProfissional: conversa.nomeContato,
                fotoProfissional: conversa.fotoUrl,
                oficioPrincipal: conversa.subtituloServico,
                // Empresa usa fk_grupo_empresa (chat próprio da loja);
                // profissional individual usa fk_profissional.
                idProfissional: conversa.ehChatEmpresa
                    ? null
                    : conversa.idProfissional,
                idGrupoEmpresa: conversa.ehChatEmpresa
                    ? conversa.idGrupoEmpresa
                    : null,
                idSolicitacao: conversa.idSolicitacao,
                idConversa: conversa.idConversa > 0
                    ? conversa.idConversa
                    : null,
              ),
            ),
          );
          if (!mounted) return;
          _carregarConversas();
        },
        child: BordaGradienteAnimada(
          ativa: conversa.estiloAtiva != null,
          cor: conversa.estiloAtiva?.cor ?? _primaryBlue,
          raio: 16,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(conversa),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Linha 1: Nome e Horário
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversa.nomeContato,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: _titleDark,
                                ),
                              ),
                            ),
                            if (textoDataHora.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                textoDataHora,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: destaqueNaoLida
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: corHorario,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Linha 2: solicitação em curso, pills do
                        // profissional/loja ou a categoria.
                        const SizedBox(height: 3),
                        _buildLinhaServico(
                          conversa,
                          corServico,
                          destaqueNaoLida,
                        ),
                        // Linha 3: Mensagem prévia e Badge numérico
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Visto único/duplo: aparece SOMENTE nas mensagens
                            // ENVIADAS pelo usuário logado (última mensagem da
                            // conversa enviada por mim), para mostrar se foi
                            // lida (azul duplo) ou não (cinza).
                            if (conversa.ultimaMensagemEnviadaPorMim &&
                                (conversa.ultimaMensagem?.trim().isNotEmpty ==
                                    true)) ...[
                              Icon(
                                conversa.ultimaMensagemLida
                                    ? Icons.done_all
                                    : Icons.done,
                                size: 16,
                                color: conversa.ultimaMensagemLida
                                    ? _primaryBlue
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: _buildPreviewMensagem(
                                conversa,
                                corMensagem,
                                destaqueNaoLida,
                              ),
                            ),
                            if (conversa.mensagensNaoLidas > 0) ...[
                              const SizedBox(width: 8),
                              _buildBadgeNaoLidas(conversa.mensagensNaoLidas),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Linha abaixo do nome.
  Widget _buildLinhaServico(
    _ConversaResumo conversa,
    Color corServico,
    bool destaqueNaoLida,
  ) {
    final estilo = conversa.estiloAtiva;
    if (estilo != null) {
      return Row(
        children: [
          Icon(estilo.icone, size: 15, color: estilo.cor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${conversa.tituloAtiva ?? 'Serviço'} - ${estilo.rotulo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: estilo.texto,
              ),
            ),
          ),
        ],
      );
    }
    final pills = <(String, Color)>[
      if (conversa.tagEmpresa != null)
        (conversa.tagEmpresa!, CorOficio.parse(conversa.corTagEmpresa)),
      for (final f in conversa.funcoes) (f, const Color(0xFF64748B)),
    ];
    if (!_isProfissional && pills.isNotEmpty) {
      return SizedBox(
        height: 22,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pills.length,
          separatorBuilder: (_, _) => const SizedBox(width: 5),
          itemBuilder: (_, i) {
            final (texto, cor) = pills[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cor.withValues(alpha: 0.7)),
              ),
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CorOficio.corTexto(cor),
                ),
              ),
            );
          },
        ),
      );
    }
    return Text(
      conversa.subtituloServico,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: destaqueNaoLida ? FontWeight.w600 : FontWeight.w400,
        color: corServico,
      ),
    );
  }

  Widget _buildPreviewMensagem(
    _ConversaResumo conversa,
    Color corMensagem,
    bool destaqueNaoLida,
  ) {
    final tipo = conversa.tipoUltimaMensagem?.toLowerCase();
    if (conversa.ehProposta) {
      return Row(
        children: [
          const Icon(
            Icons.request_quote_outlined,
            size: 17,
            color: _primaryBlue,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              conversa.ultimaMensagem ?? 'Proposta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _primaryBlue,
              ),
            ),
          ),
        ],
      );
    }
    final icone = tipo == 'imagem'
        ? Icons.image_outlined
        : tipo == 'audio'
        ? Icons.mic_none_outlined
        : null;
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 17, color: _primaryBlue),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            conversa.ultimaMensagem ?? 'Nenhuma mensagem ainda',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: destaqueNaoLida ? FontWeight.w600 : FontWeight.w400,
              color: corMensagem,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeNaoLidas(int quantidade) {
    final texto = quantidade > 99 ? '99+' : '$quantidade';
    return CorOriginal(interface: true, child: Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    ));
  }

  Widget _buildAvatar(_ConversaResumo conversa) {
    final online = VerificacaoOnline.estaOnline(conversa.ultimaConexaoContato);
    final temFoto = conversa.fotoUrl.trim().startsWith('http');

    final Widget avatar = temFoto
        ? CorOriginal(child: CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: NetworkImage(conversa.fotoUrl),
          ))
        : CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFDCE5EE),
            child: Text(
              obterIniciais(conversa.nomeContato),
              style: const TextStyle(
                color: Color(0xFF5E6F7E),
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
          );

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: CorOriginal(interface: true, child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.2),
                ),
              )),
            ),
        ],
      ),
    );
  }

  /// Formatação em formato 24h BR (ex: "23:00", "Ontem", "Seg", "12/07")
  String _formatarDataHoraUltimaMensagem(DateTime? data) {
    if (data == null) return '';
    final local = data.isUtc ? data.toLocal() : data;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diaMsg = DateTime(local.year, local.month, local.day);
    final diferencaDias = hoje.difference(diaMsg).inDays;

    if (diferencaDias == 0) {
      return DateFormat('HH:mm').format(local);
    }
    if (diferencaDias == 1) return 'Ontem';
    if (diferencaDias < 7 && diferencaDias > 0) {
      final diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return diasSemana[local.weekday - 1];
    }
    return DateFormat('dd/MM').format(local);
  }
}

class _ConversaResumo {
  final int idConversa;
  final int? idCliente;
  final int? idSolicitacao;
  final String nomeContato;
  final String fotoUrl;
  final String oficioContato;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final bool ehChatEmpresa;
  final String? servicoAssociado;
  final DateTime? ultimaConexaoContato;
  final String? ultimaMensagem;
  final String? tipoUltimaMensagem;
  final DateTime? dataUltimaMensagem;
  final int mensagensNaoLidas;
  final bool forcarDestaqueNaoLida;
  final bool ultimaMensagemRecebida;
  final bool ultimaMensagemLida;
  final bool ultimaMensagemEnviadaPorMim;

  /// Última mensagem é uma proposta (prévia em azul).
  final bool ehProposta;

  /// Funções do profissional/empresa (pills com borda) — visão do cliente.
  final List<String> funcoes;

  /// Tag da loja (#XXXX) e a cor dela.
  final String? tagEmpresa;
  final String? corTagEmpresa;

  /// Solicitação em curso entre os dois (título + estilo do status).
  final String? tituloAtiva;
  final EstiloStatus? estiloAtiva;

  const _ConversaResumo({
    required this.idConversa,
    this.idCliente,
    this.idSolicitacao,
    required this.nomeContato,
    this.fotoUrl = '',
    this.oficioContato = '',
    this.idProfissional,
    this.idGrupoEmpresa,
    this.ehChatEmpresa = false,
    this.servicoAssociado,
    this.ultimaConexaoContato,
    this.ultimaMensagem,
    this.tipoUltimaMensagem,
    this.dataUltimaMensagem,
    this.mensagensNaoLidas = 0,
    this.forcarDestaqueNaoLida = false,
    this.ultimaMensagemRecebida = false,
    this.ultimaMensagemLida = false,
    this.ultimaMensagemEnviadaPorMim = false,
    this.ehProposta = false,
    this.funcoes = const [],
    this.tagEmpresa,
    this.corTagEmpresa,
    this.tituloAtiva,
    this.estiloAtiva,
  });

  _ConversaResumo comExtras({
    List<String>? funcoes,
    String? tagEmpresa,
    String? corTagEmpresa,
    String? tituloAtiva,
    EstiloStatus? estiloAtiva,
  }) => _ConversaResumo(
    idConversa: idConversa,
    idCliente: idCliente,
    idSolicitacao: idSolicitacao,
    nomeContato: nomeContato,
    fotoUrl: fotoUrl,
    oficioContato: oficioContato,
    idProfissional: idProfissional,
    idGrupoEmpresa: idGrupoEmpresa,
    ehChatEmpresa: ehChatEmpresa,
    servicoAssociado: servicoAssociado,
    ultimaConexaoContato: ultimaConexaoContato,
    ultimaMensagem: ultimaMensagem,
    tipoUltimaMensagem: tipoUltimaMensagem,
    dataUltimaMensagem: dataUltimaMensagem,
    mensagensNaoLidas: mensagensNaoLidas,
    forcarDestaqueNaoLida: forcarDestaqueNaoLida,
    ultimaMensagemRecebida: ultimaMensagemRecebida,
    ultimaMensagemLida: ultimaMensagemLida,
    ultimaMensagemEnviadaPorMim: ultimaMensagemEnviadaPorMim,
    ehProposta: ehProposta,
    funcoes: funcoes ?? this.funcoes,
    tagEmpresa: tagEmpresa ?? this.tagEmpresa,
    corTagEmpresa: corTagEmpresa ?? this.corTagEmpresa,
    tituloAtiva: tituloAtiva ?? this.tituloAtiva,
    estiloAtiva: estiloAtiva ?? this.estiloAtiva,
  );

  bool get temNaoLidas => mensagensNaoLidas > 0 || forcarDestaqueNaoLida;

  String get subtituloServico {
    if (servicoAssociado != null && servicoAssociado!.trim().isNotEmpty) {
      return servicoAssociado!.trim();
    }
    if (oficioContato.trim().isNotEmpty) {
      return oficioContato.trim();
    }
    return 'Atendimento';
  }
}
