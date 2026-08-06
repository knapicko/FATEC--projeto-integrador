import 'package:flutter/material.dart';
import '../services/validacao_telefone.dart';

/// Widget de seleção de DDI (código do país) com bandeira
class SeletorDDI extends StatefulWidget {
  final String ddiInicial;
  final ValueChanged<String> onChanged;
  final Color corPrimaria;

  const SeletorDDI({
    super.key,
    this.ddiInicial = '+55',
    required this.onChanged,
    this.corPrimaria = const Color(0xFF00A2FF),
  });

  @override
  State<SeletorDDI> createState() => _SeletorDDIState();
}

class _SeletorDDIState extends State<SeletorDDI> {
  late String _ddiSelecionado;

  @override
  void initState() {
    super.initState();
    _ddiSelecionado = widget.ddiInicial;
  }

  @override
  void didUpdateWidget(covariant SeletorDDI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ddiInicial != oldWidget.ddiInicial) {
      _ddiSelecionado = widget.ddiInicial;
    }
  }

  Future<void> _abrirSeletor() async {
    final selecionado = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _SeletorDDILista(
          ddiSelecionado: _ddiSelecionado,
          corPrimaria: widget.corPrimaria,
        );
      },
    );

    if (selecionado != null && selecionado != _ddiSelecionado) {
      setState(() => _ddiSelecionado = selecionado);
      widget.onChanged(selecionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bandeira = obterBandeira(_ddiSelecionado) ?? '🌎';
    return InkWell(
      onTap: _abrirSeletor,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(bandeira, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              _ddiSelecionado,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

/// Lista de países/DDIs exibida no bottom sheet
class _SeletorDDILista extends StatelessWidget {
  final String ddiSelecionado;
  final Color corPrimaria;

  const _SeletorDDILista({
    required this.ddiSelecionado,
    required this.corPrimaria,
  });

  @override
  Widget build(BuildContext context) {
    final ddIs = ddIsValidos;

    // Agrupa: primeiro os mais comuns, depois o restante em ordem alfabética de bandeira
    final ddIPrioritarios = ['+55', '+54', '+1', '+44', '+351', '+34', '+33', '+49', '+39', '+52', '+56', '+57', '+58', '+51', '+598', '+595', '+591'];

    final listaPrioritaria = ddIPrioritarios
        .where((d) => ddIs.contains(d))
        .toList();

    final listaComum = ddIs
        .where((d) => !ddIPrioritarios.contains(d))
        .toList()
      ..sort((a, b) {
        final nomeA = _nomePais(a);
        final nomeB = _nomePais(b);
        return nomeA.compareTo(nomeB);
      });

    final todos = [...listaPrioritaria, ...listaComum];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Selecione o País',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: todos.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final ddi = todos[index];
                final bandeira = obterBandeira(ddi) ?? '🌎';
                final nomePais = _nomePais(ddi);
                final selecionado = ddi == ddiSelecionado;

                return ListTile(
                  dense: true,
                  leading: Text(bandeira, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    nomePais,
                    style: TextStyle(
                      fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                      color: selecionado ? corPrimaria : Colors.black87,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ddi,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (selecionado) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle, color: corPrimaria, size: 20),
                      ],
                    ],
                  ),
                  onTap: () => Navigator.pop(context, ddi),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _nomePais(String ddi) {
    switch (ddi) {
      case '+55': return 'Brasil';
      case '+54': return 'Argentina';
      case '+591': return 'Bolívia';
      case '+56': return 'Chile';
      case '+57': return 'Colômbia';
      case '+58': return 'Venezuela';
      case '+51': return 'Peru';
      case '+52': return 'México';
      case '+53': return 'Cuba';
      case '+592': return 'Guiana';
      case '+593': return 'Equador';
      case '+594': return 'Guiana Francesa';
      case '+595': return 'Paraguai';
      case '+596': return 'Martinica';
      case '+597': return 'Suriname';
      case '+598': return 'Uruguai';
      case '+1': return 'Estados Unidos / Canadá';
      case '+44': return 'Reino Unido';
      case '+351': return 'Portugal';
      case '+34': return 'Espanha';
      case '+33': return 'França';
      case '+49': return 'Alemanha';
      case '+39': return 'Itália';
      case '+81': return 'Japão';
      case '+86': return 'China';
      case '+82': return 'Coreia do Sul';
      case '+61': return 'Austrália';
      case '+64': return 'Nova Zelândia';
      case '+7': return 'Rússia';
      case '+91': return 'Índia';
      case '+20': return 'Egito';
      case '+27': return 'África do Sul';
      case '+30': return 'Grécia';
      case '+31': return 'Holanda';
      case '+32': return 'Bélgica';
      case '+36': return 'Hungria';
      case '+40': return 'Romênia';
      case '+41': return 'Suíça';
      case '+43': return 'Áustria';
      case '+45': return 'Dinamarca';
      case '+46': return 'Suécia';
      case '+47': return 'Noruega';
      case '+48': return 'Polônia';
      case '+60': return 'Malásia';
      case '+62': return 'Indonésia';
      case '+63': return 'Filipinas';
      case '+65': return 'Singapura';
      case '+66': return 'Tailândia';
      case '+90': return 'Turquia';
      case '+92': return 'Paquistão';
      case '+93': return 'Afeganistão';
      case '+94': return 'Sri Lanka';
      case '+95': return 'Mianmar';
      case '+98': return 'Irã';
      case '+211': return 'Sudão do Sul';
      case '+212': return 'Marrocos';
      case '+213': return 'Argélia';
      case '+216': return 'Tunísia';
      case '+218': return 'Líbia';
      case '+220': return 'Gâmbia';
      case '+221': return 'Senegal';
      case '+222': return 'Mauritânia';
      case '+223': return 'Mali';
      case '+224': return 'Guiné';
      case '+225': return 'Costa do Marfim';
      case '+226': return 'Burkina Faso';
      case '+227': return 'Níger';
      case '+228': return 'Togo';
      case '+229': return 'Benin';
      case '+230': return 'Maurício';
      case '+231': return 'Libéria';
      case '+232': return 'Serra Leoa';
      case '+233': return 'Gana';
      case '+234': return 'Nigéria';
      case '+235': return 'Chade';
      case '+236': return 'República Centro-Africana';
      case '+237': return 'Camarões';
      case '+238': return 'Cabo Verde';
      case '+239': return 'São Tomé e Príncipe';
      case '+240': return 'Guiné Equatorial';
      case '+241': return 'Gabão';
      case '+242': return 'Congo';
      case '+243': return 'RD Congo';
      case '+244': return 'Angola';
      case '+245': return 'Guiné-Bissau';
      case '+246': return 'Território Britânico do Oceano Índico';
      case '+248': return 'Seychelles';
      case '+249': return 'Sudão';
      case '+250': return 'Ruanda';
      case '+251': return 'Etiópia';
      case '+252': return 'Somália';
      case '+253': return 'Djibuti';
      case '+254': return 'Quênia';
      case '+255': return 'Tanzânia';
      case '+256': return 'Uganda';
      case '+257': return 'Burundi';
      case '+258': return 'Moçambique';
      case '+260': return 'Zâmbia';
      case '+261': return 'Madagascar';
      case '+262': return 'Reunião';
      case '+263': return 'Zimbábue';
      case '+264': return 'Namíbia';
      case '+265': return 'Malawi';
      case '+266': return 'Lesoto';
      case '+267': return 'Botsuana';
      case '+268': return 'Essuatíni';
      case '+269': return 'Comores';
      case '+290': return 'Santa Helena';
      case '+291': return 'Eritreia';
      case '+297': return 'Aruba';
      case '+298': return 'Ilhas Faroe';
      case '+299': return 'Groenlândia';
      case '+350': return 'Gibraltar';
      case '+352': return 'Luxemburgo';
      case '+353': return 'Irlanda';
      case '+354': return 'Islândia';
      case '+355': return 'Albânia';
      case '+356': return 'Malta';
      case '+357': return 'Chipre';
      case '+358': return 'Finlândia';
      case '+359': return 'Bulgária';
      case '+370': return 'Lituânia';
      case '+371': return 'Letônia';
      case '+372': return 'Estônia';
      case '+373': return 'Moldávia';
      case '+374': return 'Armênia';
      case '+375': return 'Bielorrússia';
      case '+376': return 'Andorra';
      case '+377': return 'Mônaco';
      case '+378': return 'San Marino';
      case '+380': return 'Ucrânia';
      case '+381': return 'Sérvia';
      case '+382': return 'Montenegro';
      case '+383': return 'Kosovo';
      case '+385': return 'Croácia';
      case '+386': return 'Eslovênia';
      case '+387': return 'Bósnia e Herzegovina';
      case '+389': return 'Macedônia do Norte';
      case '+420': return 'República Tcheca';
      case '+421': return 'Eslováquia';
      case '+423': return 'Liechtenstein';
      case '+500': return 'Ilhas Malvinas';
      case '+501': return 'Belize';
      case '+502': return 'Guatemala';
      case '+503': return 'El Salvador';
      case '+504': return 'Honduras';
      case '+505': return 'Nicarágua';
      case '+506': return 'Costa Rica';
      case '+507': return 'Panamá';
      case '+508': return 'São Pedro e Miquelon';
      case '+509': return 'Haiti';
      case '+590': return 'Guadalupe';
      case '+599': return 'Curaçao';
      case '+670': return 'Timor-Leste';
      case '+672': return 'Ilha Norfolk';
      case '+673': return 'Brunei';
      case '+674': return 'Nauru';
      case '+675': return 'Papua Nova Guiné';
      case '+676': return 'Tonga';
      case '+677': return 'Ilhas Salomão';
      case '+678': return 'Vanuatu';
      case '+679': return 'Fiji';
      case '+680': return 'Palau';
      case '+681': return 'Wallis e Futuna';
      case '+682': return 'Ilhas Cook';
      case '+683': return 'Niue';
      case '+685': return 'Samoa';
      case '+686': return 'Kiribati';
      case '+687': return 'Nova Caledônia';
      case '+688': return 'Tuvalu';
      case '+689': return 'Polinésia Francesa';
      case '+690': return 'Tokelau';
      case '+691': return 'Micronésia';
      case '+692': return 'Ilhas Marshall';
      case '+850': return 'Coreia do Norte';
      case '+852': return 'Hong Kong';
      case '+853': return 'Macau';
      case '+855': return 'Camboja';
      case '+856': return 'Laos';
      case '+880': return 'Bangladesh';
      case '+886': return 'Taiwan';
      case '+960': return 'Maldivas';
      case '+961': return 'Líbano';
      case '+962': return 'Jordânia';
      case '+963': return 'Síria';
      case '+964': return 'Iraque';
      case '+965': return 'Kuwait';
      case '+966': return 'Arábia Saudita';
      case '+967': return 'Iêmen';
      case '+968': return 'Omã';
      case '+970': return 'Palestina';
      case '+971': return 'Emirados Árabes Unidos';
      case '+972': return 'Israel';
      case '+973': return 'Bahrein';
      case '+974': return 'Catar';
      case '+975': return 'Butão';
      case '+976': return 'Mongólia';
      case '+977': return 'Nepal';
      case '+992': return 'Tajiquistão';
      case '+993': return 'Turcomenistão';
      case '+994': return 'Azerbaijão';
      case '+995': return 'Geórgia';
      case '+996': return 'Quirguistão';
      case '+998': return 'Uzbequistão';
      default: return ddi;
    }
  }
}