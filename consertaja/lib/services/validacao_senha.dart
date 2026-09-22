bool senhaTemOitoCaracteres(String senha) => senha.runes.length >= 12;

bool senhaTemMaiuscula(String senha) => senha.runes.any((rune) {
      final caractere = String.fromCharCode(rune);
      return caractere.toUpperCase() == caractere &&
          caractere.toLowerCase() != caractere;
    });

bool senhaTemMinuscula(String senha) => senha.runes.any((rune) {
      final caractere = String.fromCharCode(rune);
      return caractere.toLowerCase() == caractere &&
          caractere.toUpperCase() != caractere;
    });

bool senhaTemNumero(String senha) => senha.runes.any(
      (rune) => rune >= 0x30 && rune <= 0x39,
    );

bool senhaTemSimbolo(String senha) => senha.runes.any((rune) {
      final caractere = String.fromCharCode(rune);
      final eLetra = caractere.toUpperCase() != caractere.toLowerCase();
      final eNumero = rune >= 0x30 && rune <= 0x39;
      return !eLetra && !eNumero && !RegExp(r'\s').hasMatch(caractere);
    });