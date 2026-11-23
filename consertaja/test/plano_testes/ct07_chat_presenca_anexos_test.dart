// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT37 a CT42 — Chat em Tempo Real e Envio de Arquivos
// Requisitos: RF010 (chat), RF011 (envio de arquivos)
// Abordagem: Testes unitários
//
// ATENÇÃO: CT38 e CT40 documentam defeitos encontrados (DEF-01 e DEF-02).
// Eles FALHAM de propósito até a correção ser feita no código do app.
// =============================================================================
import 'package:consertaja/services/chat_anexos_service.dart';
import 'package:consertaja/services/chat_theme_storage.dart';
import 'package:consertaja/services/formatacao_data.dart';
import 'package:consertaja/services/verificacao_online.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _ha(Duration d) => DateTime.now().subtract(d);

void main() {
  group('RF010 — Presença no chat', () {
    test('CT37 - "Visto por último" em texto relativo', () {
      expect(formatarUltimaVezAtivo(null), '');
      expect(formatarUltimaVezAtivo(_ha(const Duration(seconds: 10))), 'Online');
      expect(formatarUltimaVezAtivo(_ha(const Duration(minutes: 30))), 'há 30 min');
      expect(formatarUltimaVezAtivo(_ha(const Duration(hours: 5))), 'há 5 h');
      expect(formatarUltimaVezAtivo(_ha(const Duration(days: 1))), 'há 1 dia');
      expect(formatarUltimaVezAtivo(_ha(const Duration(days: 3))), 'há 3 dias');
      expect(formatarUltimaVezAtivo(_ha(const Duration(days: 14))), 'há 2 semanas');
      expect(formatarUltimaVezAtivo(_ha(const Duration(days: 90))), 'há 3 meses');
    });

    test('CT38 - [DEF-01] Singular para 1 semana ("há 1 semana")', () {
      // Entre 7 e 13 dias o app mostra "há 1 semanas" (erro de concordância).
      expect(formatarUltimaVezAtivo(_ha(const Duration(days: 8))), 'há 1 semana');
    }, tags: ['defeito']);

    test('CT39 - Indicador online respeita a janela de presença', () {
      expect(VerificacaoOnline.estaOnline(null), isFalse);
      expect(VerificacaoOnline.estaOnline(DateTime.now()), isTrue);
      expect(
        VerificacaoOnline.estaOnline(_ha(const Duration(minutes: 2))),
        isFalse,
      );
      // horário vindo do banco em UTC
      expect(
        VerificacaoOnline.estaOnline(
          DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
        ),
        isTrue,
      );
      expect(VerificacaoOnline.janelaOnline, const Duration(seconds: 45));
    });

    test('CT40 - [DEF-02] Texto "Online" coerente com o indicador online', () {
      // Com 50 s sem sinal o indicador diz offline, mas o texto diz "Online".
      final ultima = _ha(const Duration(seconds: 50));
      expect(VerificacaoOnline.estaOnline(ultima), isFalse);
      expect(formatarUltimaVezAtivo(ultima), isNot('Online'));
    }, tags: ['defeito']);

    test('CT41 - Tema do chat: padrão e salvamento (JSON)', () {
      final padrao = ChatThemeStorage.defaultTheme;
      final lido = ChatThemeData.fromJson(const {});
      expect(lido.corBaloes, padrao.corBaloes);
      expect(lido.planoFundo, padrao.planoFundo);
      expect(lido.desfoqueFundo, 0.0);
      expect(lido.opacidadeFundo, 35.0);

      const meu = ChatThemeData(
        corBaloes: '0xFF10B981',
        planoFundo: 'galeria/fundo.png',
        desfoqueFundo: 4,
        opacidadeFundo: 60,
      );
      final copia = ChatThemeData.fromJson(meu.toJson());
      expect(copia.corBaloes, '0xFF10B981');
      expect(copia.planoFundo, 'galeria/fundo.png');
      expect(copia.desfoqueFundo, 4.0);
      expect(copia.opacidadeFundo, 60.0);
    });
  });

  group('RF011 — Envio de arquivos no chat', () {
    test('CT42 - Tipo, extensão e conteúdo das mensagens de anexo', () {
      expect(ChatAnexosService.tamanhoMaximoBytes, 50 * 1024 * 1024);
      expect(ChatAnexosService.ehImagem('foto.HEIC'), isTrue);
      expect(ChatAnexosService.ehImagem('orcamento.pdf'), isFalse);
      expect(ChatAnexosService.extensaoDe('.gitignore'), '');
      expect(ChatAnexosService.extensaoDe('arquivo.'), '');
      expect(
        ChatAnexosService.contentTypeDe('PLANILHA.XLSX'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(ChatAnexosService.contentTypeDe('audio.xyz'), 'application/octet-stream');

      final conteudo = ChatAnexosService.montarConteudoDocumento(
        nomeArquivo: ' Orçamento final.pdf ',
        url: 'https://cdn.exemplo/o.pdf',
      );
      expect(conteudo, 'Orçamento final.pdf\nhttps://cdn.exemplo/o.pdf');
      final partes = ChatAnexosService.separarConteudoDocumento(conteudo);
      expect(partes?.nome, 'Orçamento final.pdf');
      expect(partes?.url, 'https://cdn.exemplo/o.pdf');
      expect(ChatAnexosService.separarConteudoDocumento('sem link'), isNull);
    });
  });
}
