// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT01 a CT08 — Cadastro de Usuário e Verificação de Profissional
// Requisitos: RF001, RF004, RN010 (formatação e validação de campos)
// Abordagem: Testes unitários (caixa-preta sobre funções puras)
// =============================================================================
import 'package:consertaja/services/formatacao_data.dart';
import 'package:consertaja/services/validacao_documento.dart';
import 'package:consertaja/services/validacao_senha.dart';
import 'package:consertaja/services/validacao_telefone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RF001/RF004 — Validação de CPF', () {
    test('CT01 - CPF válido é aceito (com e sem máscara)', () {
      expect(validarCpf('52998224725'), isTrue);
      expect(validarCpf(somenteDigitos('529.982.247-25')), isTrue);
      expect(validarCpf('11144477735'), isTrue);
    });

    test('CT02 - CPF inválido é recusado', () {
      // dígito verificador errado
      expect(validarCpf('52998224724'), isFalse);
      // todos os dígitos iguais
      expect(validarCpf('11111111111'), isFalse);
      expect(validarCpf('00000000000'), isFalse);
      // quantidade de dígitos diferente de 11
      expect(validarCpf('5299822472'), isFalse);
      expect(validarCpf(''), isFalse);
    });
  });

  group('RF001/RF004 — Validação de CNPJ', () {
    test('CT03 - CNPJ válido é aceito', () {
      expect(validarCnpj('11222333000181'), isTrue);
      expect(validarCnpj(somenteDigitos('45.997.418/0001-53')), isTrue);
    });

    test('CT04 - CNPJ inválido é recusado', () {
      expect(validarCnpj('11222333000182'), isFalse);
      expect(validarCnpj('00000000000000'), isFalse);
      expect(validarCnpj('1122233300018'), isFalse);
    });
  });

  group('RN010 — Máscaras de documento', () {
    test('CT05 - Formata CPF/CNPJ e identifica o tipo do documento', () {
      expect(formatarCpf('52998224725'), '529.982.247-25');
      expect(formatarCnpj('11222333000181'), '11.222.333/0001-81');
      expect(formatarCpfOuCnpj('52998224725'), '529.982.247-25');
      expect(formatarCpfOuCnpj('11222333000181'), '11.222.333/0001-81');
      // valor incompleto é devolvido sem alteração
      expect(formatarCpfOuCnpj('123'), '123');

      expect(rotuloDocumento('529.982.247-25'), 'CPF');
      expect(rotuloDocumento('11.222.333/0001-81'), 'CNPJ');
      expect(documentoEhCpf('52998224725'), isTrue);
      expect(documentoEhCnpj('11222333000181'), isTrue);
      expect(somenteDigitos('(11) 9.1234-5678'), '11912345678');
    });
  });

  group('RF001/RN010 — Política de senha', () {
    test('CT06 - Senha forte atende todos os requisitos', () {
      const senha = 'Conserta@2026';
      expect(senhaTemOitoCaracteres(senha), isTrue); // regra atual: 12+
      expect(senhaTemMaiuscula(senha), isTrue);
      expect(senhaTemMinuscula(senha), isTrue);
      expect(senhaTemNumero(senha), isTrue);
      expect(senhaTemSimbolo(senha), isTrue);
    });

    test('CT07 - Senha fraca é sinalizada requisito a requisito', () {
      // menos de 12 caracteres
      expect(senhaTemOitoCaracteres('Abcdef1!'), isFalse);
      // sem maiúscula / minúscula / número / símbolo
      expect(senhaTemMaiuscula('abcdefgh1!xy'), isFalse);
      expect(senhaTemMinuscula('ABCDEFGH1!XY'), isFalse);
      expect(senhaTemNumero('Abcdefgh!xyz'), isFalse);
      expect(senhaTemSimbolo('Abcdefgh1xyz'), isFalse);
      // espaço não conta como símbolo
      expect(senhaTemSimbolo('Abcdefgh1 xy'), isFalse);
      // letras acentuadas contam como letras
      expect(senhaTemMaiuscula('Élan'), isTrue);
      expect(senhaTemMaiuscula('élan'), isFalse);
    });
  });

  group('RF001 — Telefone e datas do cadastro', () {
    test('CT08 - Formata telefone e converte datas (ISO <-> BR)', () {
      expect(formatarTelefoneBrasil('11912345678'), '(11) 91234-5678');
      expect(formatarTelefoneBrasil('2125551234'), '(21) 2555-1234');
      expect(formatarTelefoneBrasil('123'), '123');
      expect(validarTelefoneCompleto('(11) 91234-5678').valido, isTrue);

      expect(formatarDataBrasileira('2026-11-18'), '18/11/2026');
      expect(converterDataParaIso('18/11/2026'), '2026-11-18');
      expect(formatarDataSelecionada(DateTime(2026, 3, 5)), '05/03/2026');
      // formato inesperado é devolvido sem alteração
      expect(formatarDataBrasileira('18/11/2026'), '18/11/2026');
    });
  });
}
