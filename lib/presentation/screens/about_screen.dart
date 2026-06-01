import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';

// 1. Modelo de datos para representar a una persona. Es más seguro y legible que un Map.
class _Person {
  final String name;
  final String linkedinUrl;
  final String emailUrl;

  const _Person({
    required this.name,
    required this.linkedinUrl,
    required this.emailUrl,
  });
}

// Función auxiliar para abrir URLs. Al ser de nivel superior, es más fácil de reutilizar.
Future<void> _launchURL(String url) async {
  final Uri uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    // En una app real, aquí podrías mostrar un snackbar de error.
    debugPrint('No se pudo abrir el enlace: $url');
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _tapCount = 0;
  bool _showEasterEgg = false;

  // Los datos ahora usan el modelo _Person.
  final List<_Person> _developers = const [
    _Person(
      name: 'Julen Beiro Suso',
      linkedinUrl: 'https://www.linkedin.com/in/jbeiro/',
      emailUrl: 'mailto:jbeiro@gti.uvigo.es',
    ),
    _Person(
      name: 'Alejandro Pajón Sanmartin',
      linkedinUrl: 'https://www.linkedin.com/in/apajon/',
      emailUrl: 'mailto:apajon@gti.uvigo.es',
    ),
    _Person(
      name: 'Anxo Gesto Gayoso',
      linkedinUrl: 'https://www.linkedin.com/in/anxo/',
      emailUrl: 'mailto:agesto@gti.uvigo.es',
    ),
  ];

  final List<_Person> _secretDevelopers = const [
    _Person(
      name: 'David Perez Iglesias',
      linkedinUrl: '',
      emailUrl: '',
    ),
    _Person(
      name: 'Axel Valladares Pazo',
      linkedinUrl: '',
      emailUrl: '',
    ),
  ];

  final List<_Person> _principalInvestigators = const [
    _Person(
      name: 'Francisco de Arriba Pérez',
      linkedinUrl: 'https://www.linkedin.com/in/franciscodearriba/',
      emailUrl: 'mailto:farriba@gti.uvigo.es',
    ),
    _Person(
      name: 'Silvia García Méndez',
      linkedinUrl: 'https://www.linkedin.com/in/silviamndez/',
      emailUrl: 'mailto:sgarcia@gti.uvigo.es',
    ),
  ];

  void _handleTap() {
    setState(() {
      _tapCount++;
      if (_tapCount >= 50 && !_showEasterEgg) {
        _showEasterEgg = true;
        // Mostrar un mensaje al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 ¡Has descubierto a los desarrolladores secretos!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    // Crear lista de desarrolladores con el easter egg si está activado
    final displayedDevelopers = _showEasterEgg 
        ? [..._developers, ..._secretDevelopers]
        : _developers;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTap,
          child: Text(localeProvider.translate('about')),
        ),
        centerTitle: true,
      ),
      // 4. Usar ListView para permitir scroll si el contenido es muy largo.
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _SectionHeader(title: localeProvider.translate('developers')),
          _PersonList(people: displayedDevelopers),
          const SizedBox(height: 24),
          _SectionHeader(title: localeProvider.translate('principal_investigators')),
          _PersonList(people: _principalInvestigators),
          const SizedBox(height: 24),
          _SectionHeader(title: localeProvider.translate('project_funded')),
          const SizedBox(height: 16),
          const _FundingLogos(),
        ],
      ),
    );
  }
}

// --- WIDGETS INTERNOS REFACTORIZADOS ---

// Widget para los títulos de sección.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// Widget que construye la lista de personas.
class _PersonList extends StatelessWidget {
  final List<_Person> people;
  const _PersonList({required this.people});

  @override
  Widget build(BuildContext context) {
    return Column(
      // Se usa un for-loop en lugar de .map para mayor legibilidad.
      children: [for (final person in people) _PersonTile(person: person)],
    );
  }
}

// 2. Widget reutilizable para mostrar una persona. ¡Adiós a la duplicación!
class _PersonTile extends StatelessWidget {
  final _Person person;
  const _PersonTile({required this.person});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            children: [
                SizedBox(
                width: 200, // Ajusta el ancho fijo según lo que necesites
                child: Text(
                  person.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                ),
              const Spacer(flex: 1,),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.linkedin, color: Color(0xFF0A66C2)),
                onPressed: () => _launchURL(person.linkedinUrl),
                tooltip: 'LinkedIn',
                iconSize: 30,
              ),
              IconButton(
                icon: const Icon(Icons.email_outlined, color: Colors.redAccent),
                onPressed: () => _launchURL(person.emailUrl),
                tooltip: 'Email',
                iconSize: 32,
              ),
              const Spacer(flex: 1,)
            ],
          ),
          
          const Divider(color: Colors.blueGrey,),
        ],
      ),
    );
  }
}

// 5. Widget para los logos, con la lógica del tema encapsulada.
class _FundingLogos extends StatelessWidget {
  const _FundingLogos();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // NOTA: La imagen 'ue_dark.jpg' parece ser para el tema claro, y 'ue.png' para el oscuro.
    // Si es al revés, simplemente invierte la lógica.
    final ueLogoPath = isDarkMode ? 'images/ue.png' : 'images/ue_dark.jpg';

    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
      ConstrainedBox(
        constraints: const BoxConstraints(
        maxWidth: 200, // máximo ancho en px
        ),
        child: Image.asset(
        'images/3dataspace.png',
        height: screenWidth * 0.22,
        fit: BoxFit.contain,
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(
        maxWidth: 400, // máximo ancho en px
        ),
        child: Image.asset(
        ueLogoPath,
        height: screenWidth * 0.08,
        fit: BoxFit.contain,
        ),
      ),
      ],
    );
  }
}