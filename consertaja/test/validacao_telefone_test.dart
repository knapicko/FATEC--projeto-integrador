import 'package:flutter_test/flutter_test.dart';
import 'package:consertaja/services/validacao_telefone.dart';

void main() {
  group('validarTelefoneCompleto', () {
    test('Telefone brasileiro válido - celular (11 dígitos)', () {
      final resultado = validarTelefoneCompleto('(11) 91234-5678');
      expect(resultado.valido, isTrue);
      expect(resultado.ddi, '+55');
      expect(resultado.ddd, '11');
      expect(resultado.numero, '912345678');
    });

    test('Telefone brasileiro válido - fixo (10 dígitos)', () {
      final resultado = validarTelefoneCompleto('(21) 2555-1234');
      expect(resultado.valido, isTrue);
      expect(resultado.ddi, '+55');
      expect(resultado.ddd, '21');
      expect(resultado.numero, '25551234');
    });

    test('Telefone com DDI +55 explícito', () {
      final resultado = validarTelefoneCompleto('+55 11 91234-5678');
      expect(resultado.valido, isTrue);
      expect(resultado.ddi, '+55');
      expect(resultado.ddd, '11');
    });

    test('Telefone com DDI internacional válido', () {
      final resultado = validarTelefoneCompleto('+1 (555) 123-4567');
      expect(resultado.valido, isTrue);
      expect(resultado.ddi, '+1');
    });

    test('DDD inválido', () {
      final resultado = validarTelefoneCompleto('(10) 91234-5678');
      expect(resultado.valido, isFalse);
      expect(resultado.erro, contains('DDD'));
    });

    test('DDD inexistente no Brasil', () {
      final resultado = validarTelefoneCompleto('(20) 91234-5678');
      expect(resultado.valido, isFalse);
      expect(resultado.erro, contains('não existe'));
    });

    test('Celular não começa com 9', () {
      final resultado = validarTelefoneCompleto('(11) 81234-5678');
      expect(resultado.valido, isFalse);
      expect(resultado.erro, contains('começar com 9'));
    });

    test('Celular pode ter qualquer segundo dígito', () {
      final resultado = validarTelefoneCompleto('(11) 90123-4567');
      expect(resultado.valido, isTrue);
    });

    test('Número muito curto', () {
      final resultado = validarTelefoneCompleto('(11) 9123');
      expect(resultado.valido, isFalse);
      expect(resultado.erro, contains('incompleto'));
    });

    test('Campo vazio', () {
      final resultado = validarTelefoneCompleto('');
      expect(resultado.valido, isFalse);
      expect(resultado.erro, 'Informe um telefone');
    });

    test('Número fixo não pode começar com 0 ou 1', () {
      final resultado = validarTelefoneCompleto('(11) 0123-4567');
      expect(resultado.valido, isFalse);
      expect(resultado.erro, contains('0 ou 1'));
    });

    test('Sem DDI, assume Brasil', () {
      final resultado = validarTelefoneCompleto('11912345678');
      expect(resultado.valido, isTrue);
      expect(resultado.ddi, '+55');
      expect(resultado.ddd, '11');
    });
  });

  group('validarDDD', () {
    test('DDD válido', () {
      expect(validarDDD('11'), isTrue);
      expect(validarDDD('21'), isTrue);
      expect(validarDDD('31'), isTrue);
    });

    test('DDD inválido', () {
      expect(validarDDD('10'), isFalse);
      expect(validarDDD('00'), isFalse);
    });
  });

  group('validarDDI', () {
    test('DDI válido', () {
      expect(validarDDI('+55'), isTrue);
      expect(validarDDI('+1'), isTrue);
      expect(validarDDI('+44'), isTrue);
    });

    test('DDI inválido', () {
      expect(validarDDI('+999'), isFalse);
    });
  });

  group('obterBandeira', () {
    test('Bandeira do Brasil', () {
      expect(obterBandeira('+55'), '🇧🇷');
    });

    test('Bandeira dos EUA', () {
      expect(obterBandeira('+1'), '🇺🇸');
    });

    test('DDI inválido retorna null', () {
      expect(obterBandeira('+999'), isNull);
    });
  });
}