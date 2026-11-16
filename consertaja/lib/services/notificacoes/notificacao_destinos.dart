// =============================================================================
// ConsertaJá — Para onde cada notificação leva ao ser tocada
//
// Prioridade: `tela_destino` gravado pelo servidor → destino padrão do tipo.
// Para um destino novo: acrescente uma chave em [_porChave] (e use a mesma
// string no SQL que cria a notificação).
// =============================================================================
import 'package:flutter/material.dart';

import '../../alterar_disponibilidade.dart';
import '../../area_atuacao.dart';
import '../../configuracoes_empresa.dart';
import '../../detalhes_pedido.dart';
import '../../editar_informacoes.dart';
import '../../meus_dados_financeiros_profissional.dart';
import '../../meus_enderecos.dart';
import '../../meus_pedidos.dart';
import '../../meus_servicos_profissional.dart';
import '../../metodo_entrega_profissional.dart';
import '../../minhas_notificacoes.dart';
import '../../modificar_conta_profissional.dart';
import '../../solicitacao_estado.dart';
import '../../solicitacao_geografica_cliente.dart';
import '../../solicitacao_geografica_profissional.dart';
import '../../tela_chat_profissional.dart';
import 'notificacao_app.dart';
import 'notificacao_tipos.dart';

class NotificacaoDestinos {
  NotificacaoDestinos._();

  static int? _int(Object? v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  /// Tela de cada chave de `tela_destino` (null = não dá para abrir).
  static Widget? _porChave(String chave, NotificacaoApp n) {
    final empresa = n.dados['perfil'] == 'empresa';
    switch (chave) {
      case 'detalhes_pedido':
        final id = n.fkSolicitacao ?? _int(n.dados['id_solicitacao']);
        return id == null ? null : DetalhesPedidoPage(idSolicitacao: id);
      case 'solicitacao_estado':
        final id = n.fkSolicitacao ?? _int(n.dados['id_solicitacao']);
        return id == null ? null : SolicitacaoEstadoPage(idSolicitacao: id);
      case 'conversa':
        final idConversa = n.fkConversa ?? _int(n.dados['id_conversa']);
        if (idConversa == null) return null;
        final idGrupo = _int(n.dados['id_grupo_empresa']);
        return TelaChatProfissional(
          nomeProfissional: n.dados['nome_remetente']?.toString() ?? n.titulo,
          fotoProfissional: n.dados['foto_remetente']?.toString() ?? '',
          oficioPrincipal: 'Conversa',
          idProfissional: idGrupo == null
              ? _int(n.dados['id_profissional'])
              : null,
          idGrupoEmpresa: idGrupo,
          idSolicitacao: n.fkSolicitacao,
          idConversa: idConversa,
        );
      case 'radar_profissional':
        return const SolicitacaoGeograficaProfissionalPage();
      case 'radar_cliente':
        return const SolicitacaoGeograficaClientePage();
      case 'editar_informacoes':
        return const EditarInformacoesPage();
      case 'meus_enderecos':
        return MeusEnderecosPage(isProfissional: n.papel == 'profissional');
      case 'dados_financeiros':
        return const MeusDadosFinanceirosProfissionalPage();
      case 'metodo_entrega':
        return const MetodoEntregaProfissionalPage();
      case 'disponibilidade':
        return AlterarDisponibilidadePage(isEmpresa: empresa);
      case 'modificar_conta':
        return const ModificarContaProfissionalPage();
      case 'area_atuacao':
        return const AreaAtuacaoPage();
      case 'configuracoes_empresa':
        return const ConfiguracoesEmpresaPage();
      case 'meus_servicos':
        return const MeusServicosProfissionalPage();
      case 'meus_pedidos':
        return const MeusPedidosPage();
      case 'notificacoes':
        return const MinhasNotificacoesPage();
    }
    return null;
  }

  /// Destino padrão de cada tipo (quando `tela_destino` está vazio).
  static String _chavePadrao(NotificacaoApp n) {
    switch (n.tipo) {
      case TipoNotificacao.solicitacao:
        return n.papel == 'profissional'
            ? 'solicitacao_estado'
            : 'detalhes_pedido';
      case TipoNotificacao.conversa:
        return 'conversa';
      case TipoNotificacao.radarProf:
        return 'radar_profissional';
      case TipoNotificacao.radarCliente:
        return 'radar_cliente';
      case TipoNotificacao.sistema:
      case TipoNotificacao.global:
      case TipoNotificacao.feedback:
        return 'notificacoes';
    }
  }

  static Widget? telaDe(NotificacaoApp n) {
    final chave = n.telaDestino;
    if (chave != null && chave.isNotEmpty) {
      final tela = _porChave(chave, n);
      if (tela != null) return tela;
    }
    return _porChave(_chavePadrao(n), n);
  }

  /// Abre a tela da notificação (empilhada sobre a atual).
  static Future<void> abrir(NavigatorState navegador, NotificacaoApp n) async {
    final tela = telaDe(n);
    if (tela == null) return;
    await navegador.push(MaterialPageRoute(builder: (_) => tela));
  }
}
