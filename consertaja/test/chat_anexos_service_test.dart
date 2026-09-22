import 'package:consertaja/services/chat_anexos_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bucket de anexos e limite de tamanho configurados', () {
    expect(ChatAnexosService.bucketAnexos, 'Anexos Chat');
    expect(ChatAnexosService.tamanhoMaximoBytes, 50 * 1024 * 1024);
  });

  group('ChatAnexosService.extensaoDe', () {
    test('extrai a extensão em minúsculas', () {
      expect(ChatAnexosService.extensaoDe('Contrato.PDF'), 'pdf');
      expect(ChatAnexosService.extensaoDe('foto.jpeg'), 'jpeg');
      expect(ChatAnexosService.extensaoDe('dados.Final.XLSX'), 'xlsx');
    });

    test('retorna vazio quando não há extensão válida', () {
      expect(ChatAnexosService.extensaoDe('arquivo'), '');
      expect(ChatAnexosService.extensaoDe('arquivo.'), '');
      expect(ChatAnexosService.extensaoDe('.gitignore'), '');
      expect(ChatAnexosService.extensaoDe('   '), '');
    });
  });

  group('ChatAnexosService.ehImagem', () {
    test('reconhece os formatos de imagem do chat', () {
      for (final nome in [
        'a.jpg',
        'a.JPEG',
        'b.png',
        'c.gif',
        'd.webp',
        'e.bmp',
        'f.heic',
        'g.heif',
      ]) {
        expect(ChatAnexosService.ehImagem(nome), isTrue, reason: nome);
      }
    });

    test('não trata documentos como imagem', () {
      for (final nome in [
        'contrato.pdf',
        'planilha.xlsx',
        'texto.txt',
        'backup.zip',
        'arquivo',
      ]) {
        expect(ChatAnexosService.ehImagem(nome), isFalse, reason: nome);
      }
    });
  });

  group('ChatAnexosService.contentTypeDe', () {
    test('mapeia os principais formatos', () {
      expect(ChatAnexosService.contentTypeDe('foto.JPG'), 'image/jpeg');
      expect(ChatAnexosService.contentTypeDe('foto.png'), 'image/png');
      expect(ChatAnexosService.contentTypeDe('foto.webp'), 'image/webp');
      expect(
        ChatAnexosService.contentTypeDe('contrato.pdf'),
        'application/pdf',
      );
      expect(
        ChatAnexosService.contentTypeDe('dados.xlsx'),
        contains('spreadsheetml'),
      );
      expect(ChatAnexosService.contentTypeDe('texto.txt'), 'text/plain');
      expect(ChatAnexosService.contentTypeDe('backup.zip'), 'application/zip');
    });

    test('usa application/octet-stream como padrão', () {
      expect(
        ChatAnexosService.contentTypeDe('arquivo.bin'),
        'application/octet-stream',
      );
      expect(
        ChatAnexosService.contentTypeDe('arquivo'),
        'application/octet-stream',
      );
    });
  });

  group('documentos (conteudo = nome + URL)', () {
    const url =
        'https://projeto.supabase.co/storage/v1/object/public/'
        'Anexos%20Chat/conversa_7/1700000000000_contrato.pdf';

    test('monta o conteúdo com nome e URL', () {
      final conteudo = ChatAnexosService.montarConteudoDocumento(
        nomeArquivo: ' contrato.pdf ',
        url: url,
      );
      expect(conteudo, 'contrato.pdf\n$url');
    });

    test('separa nome e URL', () {
      final dados = ChatAnexosService.separarConteudoDocumento(
        'contrato.pdf\n$url',
      );
      expect(dados, isNotNull);
      expect(dados!.nome, 'contrato.pdf');
      expect(dados.url, url);
    });

    test('aceita conteúdo apenas com a URL (sem nome)', () {
      final dados = ChatAnexosService.separarConteudoDocumento(url);
      expect(dados, isNotNull);
      expect(dados!.nome, '');
      expect(dados.url, url);
    });

    test('ignora linhas vazias ao separar', () {
      final dados = ChatAnexosService.separarConteudoDocumento(
        '\n\n  orcamento.pdf  \n\n$url\n\n',
      );
      expect(dados!.nome, 'orcamento.pdf');
      expect(dados.url, url);
    });

    test('retorna null quando não há URL', () {
      expect(ChatAnexosService.separarConteudoDocumento('apenas texto'), isNull);
      expect(ChatAnexosService.separarConteudoDocumento(''), isNull);
      expect(ChatAnexosService.separarConteudoDocumento('  \n  '), isNull);
    });
  });
}