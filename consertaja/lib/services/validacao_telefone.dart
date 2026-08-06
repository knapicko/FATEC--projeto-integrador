// =========================================================================
// SERVIÇO DE VALIDAÇÃO DE TELEFONE
// Valida DDI (bandeiras), DDD e estrutura do número
// =========================================================================

/// Lista de DDI válidos (códigos de país) com suas bandeiras
const Map<String, String> _ddiBandeiras = {
  '+55': '🇧🇷', // Brasil
  '+54': '🇦🇷', // Argentina
  '+56': '🇨🇱', // Chile
  '+57': '🇨🇴', // Colômbia
  '+58': '🇻🇪', // Venezuela
  '+51': '🇵🇪', // Peru
  '+52': '🇲🇽', // México
  '+53': '🇨🇺', // Cuba
  '+591': '🇧🇴', // Bolívia
  '+592': '🇬🇾', // Guiana
  '+593': '🇪🇨', // Equador
  '+594': '🇬🇫', // Guiana Francesa
  '+595': '🇵🇾', // Paraguai
  '+596': '🇲🇶', // Martinica
  '+597': '🇸🇷', // Suriname
  '+598': '🇺🇾', // Uruguai
  '+1': '🇺🇸', // EUA/Canadá
  '+44': '🇬🇧', // Reino Unido
  '+351': '🇵🇹', // Portugal
  '+34': '🇪🇸', // Espanha
  '+33': '🇫🇷', // França
  '+49': '🇩🇪', // Alemanha
  '+39': '🇮🇹', // Itália
  '+81': '🇯🇵', // Japão
  '+86': '🇨🇳', // China
  '+82': '🇰🇷', // Coreia do Sul
  '+61': '🇦🇺', // Austrália
  '+64': '🇳🇿', // Nova Zelândia
  '+7': '🇷🇺', // Rússia
  '+91': '🇮🇳', // Índia
  '+20': '🇪🇬', // Egito
  '+27': '🇿🇦', // África do Sul
  '+30': '🇬🇷', // Grécia
  '+31': '🇳🇱', // Holanda
  '+32': '🇧🇪', // Bélgica
  '+36': '🇭🇺', // Hungria
  '+40': '🇷🇴', // Romênia
  '+41': '🇨🇭', // Suíça
  '+43': '🇦🇹', // Áustria
  '+45': '🇩🇰', // Dinamarca
  '+46': '🇸🇪', // Suécia
  '+47': '🇳🇴', // Noruega
  '+48': '🇵🇱', // Polônia
  '+60': '🇲🇾', // Malásia
  '+62': '🇮🇩', // Indonésia
  '+63': '🇵🇭', // Filipinas
  '+65': '🇸🇬', // Singapura
  '+66': '🇹🇭', // Tailândia
  '+90': '🇹🇷', // Turquia
  '+92': '🇵🇰', // Paquistão
  '+93': '🇦🇫', // Afeganistão
  '+94': '🇱🇰', // Sri Lanka
  '+95': '🇲🇲', // Mianmar
  '+98': '🇮🇷', // Irã
  '+211': '🇸🇸', // Sudão do Sul
  '+212': '🇲🇦', // Marrocos
  '+213': '🇩🇿', // Argélia
  '+216': '🇹🇳', // Tunísia
  '+218': '🇱🇾', // Líbia
  '+220': '🇬🇲', // Gâmbia
  '+221': '🇸🇳', // Senegal
  '+222': '🇲🇷', // Mauritânia
  '+223': '🇲🇱', // Mali
  '+224': '🇬🇳', // Guiné
  '+225': '🇨🇮', // Costa do Marfim
  '+226': '🇧🇫', // Burkina Faso
  '+227': '🇳🇪', // Níger
  '+228': '🇹🇬', // Togo
  '+229': '🇧🇯', // Benin
  '+230': '🇲🇺', // Maurício
  '+231': '🇱🇷', // Libéria
  '+232': '🇸🇱', // Serra Leoa
  '+233': '🇬🇭', // Gana
  '+234': '🇳🇬', // Nigéria
  '+235': '🇹🇩', // Chade
  '+236': '🇨🇫', // República Centro-Africana
  '+237': '🇨🇲', // Camarões
  '+238': '🇨🇻', // Cabo Verde
  '+239': '🇸🇹', // São Tomé e Príncipe
  '+240': '🇬🇶', // Guiné Equatorial
  '+241': '🇬🇦', // Gabão
  '+242': '🇨🇬', // Congo
  '+243': '🇨🇩', // RD Congo
  '+244': '🇦🇴', // Angola
  '+245': '🇬🇼', // Guiné-Bissau
  '+246': '🇮🇴', // Território Britânico do Oceano Índico
  '+248': '🇸🇨', // Seychelles
  '+249': '🇸🇩', // Sudão
  '+250': '🇷🇼', // Ruanda
  '+251': '🇪🇹', // Etiópia
  '+252': '🇸🇴', // Somália
  '+253': '🇩🇯', // Djibuti
  '+254': '🇰🇪', // Quênia
  '+255': '🇹🇿', // Tanzânia
  '+256': '🇺🇬', // Uganda
  '+257': '🇧🇮', // Burundi
  '+258': '🇲🇿', // Moçambique
  '+260': '🇿🇲', // Zâmbia
  '+261': '🇲🇬', // Madagascar
  '+262': '🇷🇪', // Reunião
  '+263': '🇿🇼', // Zimbábue
  '+264': '🇳🇦', // Namíbia
  '+265': '🇲🇼', // Malawi
  '+266': '🇱🇸', // Lesoto
  '+267': '🇧🇼', // Botsuana
  '+268': '🇸🇿', // Essuatíni
  '+269': '🇰🇲', // Comores
  '+290': '🇸🇭', // Santa Helena
  '+291': '🇪🇷', // Eritreia
  '+297': '🇦🇼', // Aruba
  '+298': '🇫🇴', // Ilhas Faroe
  '+299': '🇬🇱', // Groenlândia
  '+350': '🇬🇮', // Gibraltar
  '+352': '🇱🇺', // Luxemburgo
  '+353': '🇮🇪', // Irlanda
  '+354': '🇮🇸', // Islândia
  '+355': '🇦🇱', // Albânia
  '+356': '🇲🇹', // Malta
  '+357': '🇨🇾', // Chipre
  '+358': '🇫🇮', // Finlândia
  '+359': '🇧🇬', // Bulgária
  '+370': '🇱🇹', // Lituânia
  '+371': '🇱🇻', // Letônia
  '+372': '🇪🇪', // Estônia
  '+373': '🇲🇩', // Moldávia
  '+374': '🇦🇲', // Armênia
  '+375': '🇧🇾', // Bielorrússia
  '+376': '🇦🇩', // Andorra
  '+377': '🇲🇨', // Mônaco
  '+378': '🇸🇲', // San Marino
  '+380': '🇺🇦', // Ucrânia
  '+381': '🇷🇸', // Sérvia
  '+382': '🇲🇪', // Montenegro
  '+383': '🇽🇰', // Kosovo
  '+385': '🇭🇷', // Croácia
  '+386': '🇸🇮', // Eslovênia
  '+387': '🇧🇦', // Bósnia e Herzegovina
  '+389': '🇲🇰', // Macedônia do Norte
  '+420': '🇨🇿', // República Tcheca
  '+421': '🇸🇰', // Eslováquia
  '+423': '🇱🇮', // Liechtenstein
  '+500': '🇫🇰', // Ilhas Malvinas
  '+501': '🇧🇿', // Belize
  '+502': '🇬🇹', // Guatemala
  '+503': '🇸🇻', // El Salvador
  '+504': '🇭🇳', // Honduras
  '+505': '🇳🇮', // Nicarágua
  '+506': '🇨🇷', // Costa Rica
  '+507': '🇵🇦', // Panamá
  '+508': '🇵🇲', // São Pedro e Miquelon
  '+509': '🇭🇹', // Haiti
  '+590': '🇬🇵', // Guadalupe
  '+599': '🇨🇼', // Curaçao
  '+670': '🇹🇱', // Timor-Leste
  '+672': '🇳🇫', // Ilha Norfolk
  '+673': '🇧🇳', // Brunei
  '+674': '🇳🇷', // Nauru
  '+675': '🇵🇬', // Papua Nova Guiné
  '+676': '🇹🇴', // Tonga
  '+677': '🇸🇧', // Ilhas Salomão
  '+678': '🇻🇺', // Vanuatu
  '+679': '🇫🇯', // Fiji
  '+680': '🇵🇼', // Palau
  '+681': '🇼🇫', // Wallis e Futuna
  '+682': '🇨🇰', // Ilhas Cook
  '+683': '🇳🇺', // Niue
  '+685': '🇼🇸', // Samoa
  '+686': '🇰🇮', // Kiribati
  '+687': '🇳🇨', // Nova Caledônia
  '+688': '🇹🇻', // Tuvalu
  '+689': '🇵🇫', // Polinésia Francesa
  '+690': '🇹🇰', // Tokelau
  '+691': '🇫🇲', // Micronésia
  '+692': '🇲🇭', // Ilhas Marshall
  '+850': '🇰🇵', // Coreia do Norte
  '+852': '🇭🇰', // Hong Kong
  '+853': '🇲🇴', // Macau
  '+855': '🇰🇭', // Camboja
  '+856': '🇱🇦', // Laos
  '+880': '🇧🇩', // Bangladesh
  '+886': '🇹🇼', // Taiwan
  '+960': '🇲🇻', // Maldivas
  '+961': '🇱🇧', // Líbano
  '+962': '🇯🇴', // Jordânia
  '+963': '🇸🇾', // Síria
  '+964': '🇮🇶', // Iraque
  '+965': '🇰🇼', // Kuwait
  '+966': '🇸🇦', // Arábia Saudita
  '+967': '🇾🇪', // Iêmen
  '+968': '🇴🇲', // Omã
  '+970': '🇵🇸', // Palestina
  '+971': '🇦🇪', // Emirados Árabes Unidos
  '+972': '🇮🇱', // Israel
  '+973': '🇧🇭', // Bahrein
  '+974': '🇶🇦', // Catar
  '+975': '🇧🇹', // Butão
  '+976': '🇲🇳', // Mongólia
  '+977': '🇳🇵', // Nepal
  '+992': '🇹🇯', // Tajiquistão
  '+993': '🇹🇲', // Turcomenistão
  '+994': '🇦🇿', // Azerbaijão
  '+995': '🇬🇪', // Geórgia
  '+996': '🇰🇬', // Quirguistão
  '+998': '🇺🇿', // Uzbequistão
};

/// Lista de DDDs válidos do Brasil
const Set<String> _dddsValidos = {
  '11', '12', '13', '14', '15', '16', '17', '18', '19', // SP
  '21', '22', '24', '27', '28', // RJ/ES
  '31', '32', '33', '34', '35', '37', '38', // MG
  '41', '42', '43', '44', '45', '46', // PR
  '47', '48', '49', // SC
  '51', '53', '54', '55', // RS
  '61', // DF
  '62', '64', // GO
  '63', // TO
  '65', '66', // MT
  '67', // MS
  '68', // AC
  '69', // RO
  '71', '73', '74', '75', '77', // BA
  '79', // SE
  '81', '87', // PE
  '82', // AL
  '83', // PB
  '84', // RN
  '85', '88', // CE
  '86', '89', // PI
  '91', '93', '94', // PA
  '92', '97', // AM
  '95', // RR
  '96', // AP
  '98', '99', // MA
};

/// Lista de DDDs que não existem (para mensagens de erro mais claras)
const Set<String> _dddsInvalidos = {
  '10', '20', '23', '25', '26', '29', '30', '36', '39', '40',
  '50', '52', '56', '57', '58', '59', '60', '63', '70', '72',
  '76', '78', '80', '90',
};

/// Resultado da validação de telefone
class ResultadoValidacaoTelefone {
  final bool valido;
  final String? erro;
  final String? ddi;
  final String? ddd;
  final String? numero;

  const ResultadoValidacaoTelefone({
    required this.valido,
    this.erro,
    this.ddi,
    this.ddd,
    this.numero,
  });
}

/// Valida um número de telefone completo (com DDI, DDD e número)
/// Formato esperado: +55 (11) 91234-5678 ou 11912345678
ResultadoValidacaoTelefone validarTelefoneCompleto(String telefone) {
  // Remove tudo que não é dígito ou +
  final limpo = telefone.replaceAll(RegExp(r'[^\d+]'), '');

  if (limpo.isEmpty) {
    return const ResultadoValidacaoTelefone(
      valido: false,
      erro: 'Informe um telefone',
    );
  }

  // Verifica se tem DDI explícito com +
  String ddi = '';
  String restante = limpo;

  if (limpo.startsWith('+')) {
    // Formato: +55 11 912345678
    // Tenta DDI de 3 dígitos primeiro (ex: +591)
    for (int len = 3; len >= 1; len--) {
      if (limpo.length > len) {
        final possivelDdi = '+${limpo.substring(1, 1 + len)}';
        if (_ddiBandeiras.containsKey(possivelDdi)) {
          ddi = possivelDdi;
          restante = limpo.substring(1 + len);
          break;
        }
      }
    }
    if (ddi.isEmpty) {
      return const ResultadoValidacaoTelefone(
        valido: false,
        erro: 'DDI (código do país) inválido. Ex: +55 para Brasil',
      );
    }
  } else {
    // Sem +, assume Brasil (+55) - a aplicação é brasileira e os campos usam máscara (XX) XXXXX-XXXX
    ddi = '+55';
    restante = limpo;
  }

  // Se não for Brasil, valida apenas a estrutura básica
  if (ddi != '+55') {
    if (restante.length < 6 || restante.length > 15) {
      final bandeira = _ddiBandeiras[ddi] ?? '';
      return ResultadoValidacaoTelefone(
        valido: false,
        erro: 'Número de telefone inválido para o país $bandeira $ddi',
        ddi: ddi,
      );
    }
    return ResultadoValidacaoTelefone(
      valido: true,
      ddi: ddi,
      ddd: null,
      numero: restante,
    );
  }

  // Para Brasil, valida DDD e número
  if (restante.length < 10 || restante.length > 11) {
    return ResultadoValidacaoTelefone(
      valido: false,
      erro: 'Número incompleto. Informe DDD + número (ex: 11 91234-5678)',
      ddi: ddi,
    );
  }

  final ddd = restante.substring(0, 2);
  final numero = restante.substring(2);

  // Valida DDD
  if (_dddsInvalidos.contains(ddd)) {
    return ResultadoValidacaoTelefone(
      valido: false,
      erro: 'DDD $ddd não existe no Brasil',
      ddi: ddi,
      ddd: ddd,
      numero: numero,
    );
  }

  if (!_dddsValidos.contains(ddd)) {
    return ResultadoValidacaoTelefone(
      valido: false,
      erro: 'DDD $ddd não é válido no Brasil',
      ddi: ddi,
      ddd: ddd,
      numero: numero,
    );
  }

  // Valida estrutura do número
  if (numero.length == 8) {
    // Telefone fixo: 8 dígitos, não pode começar com 0 ou 1
    if (numero.startsWith('0') || numero.startsWith('1')) {
      return ResultadoValidacaoTelefone(
        valido: false,
        erro: 'Número fixo não pode começar com 0 ou 1',
        ddi: ddi,
        ddd: ddd,
        numero: numero,
      );
    }
    return ResultadoValidacaoTelefone(
      valido: true,
      ddi: ddi,
      ddd: ddd,
      numero: numero,
    );
  } else if (numero.length == 9) {
    // Celular: 9 dígitos, deve começar com 9
    if (!numero.startsWith('9')) {
      return ResultadoValidacaoTelefone(
        valido: false,
        erro: 'Celular deve começar com 9 (ex: 9 1234-5678)',
        ddi: ddi,
        ddd: ddd,
        numero: numero,
      );
    }
    return ResultadoValidacaoTelefone(
      valido: true,
      ddi: ddi,
      ddd: ddd,
      numero: numero,
    );
  } else {
    return ResultadoValidacaoTelefone(
      valido: false,
      erro: 'Número deve ter 8 dígitos (fixo) ou 9 dígitos (celular)',
      ddi: ddi,
      ddd: ddd,
      numero: numero,
    );
  }
}

/// Valida apenas o DDD brasileiro
bool validarDDD(String ddd) {
  return _dddsValidos.contains(ddd);
}

/// Valida apenas o DDI (código do país)
bool validarDDI(String ddi) {
  return _ddiBandeiras.containsKey(ddi);
}

/// Retorna a bandeira (emoji) para um DDI
String? obterBandeira(String ddi) {
  return _ddiBandeiras[ddi];
}

/// Retorna a lista de DDI válidos
List<String> get dddsValidos => _dddsValidos.toList()..sort();

/// Retorna a lista de DDI válidos
List<String> get ddIsValidos => _ddiBandeiras.keys.toList()..sort();

/// Formata um número de telefone brasileiro
/// Ex: 11912345678 -> (11) 91234-5678
String formatarTelefoneBrasil(String numero) {
  final digitos = numero.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 10) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6)}';
  } else if (digitos.length == 11) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7)}';
  }
  return numero;
}