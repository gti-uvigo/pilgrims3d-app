// lib/screens/terms_screen.dart
import 'package:flutter/material.dart';

// 1. Constants for the text content
class TermsContent {
  static const String welcomeTitle = 'Bienvenido a nuestros Términos y Condiciones.';
  static const String welcomeSubtitle = 'Aquí encontrarás información importante sobre el uso de nuestra aplicación.';
  static const String section1Title = '1. Aceptación de los Términos';
  static const String section1Body =
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque luctus urna et ultricies auctor. Curabitur risus tortor, dignissim vitae tristique mollis, dictum nec augue. Proin mollis metus gravida imperdiet interdum. Curabitur sed est eu magna congue feugiat sit amet et dui. Nullam massa metus, blandit ac tristique sit amet, commodo nec tortor. Donec porttitor scelerisque turpis, vel tempus lacus cursus bibendum. Maecenas in pellentesque orci. Suspendisse ultricies elementum arcu, interdum hendrerit libero accumsan ut. Aenean vulputate purus cursus, pretium sem ut, bibendum odio. Mauris eget dictum elit, vel vulputate ex. Quisque id dui urna. Nulla in lacus quis sem tristique maximus. Ut arcu urna, rutrum id augue quis, efficitur scelerisque tortor. Integer aliquet, nisi ac laoreet consectetur, turpis diam aliquam tortor, vel tempor est justo et felis. Cras facilisis ipsum at nunc venenatis fermentum. \nCras convallis auctor sapien sed tempus. Ut mattis sagittis sagittis. Quisque fermentum justo non eros imperdiet faucibus et et erat. Mauris aliquam, purus malesuada pulvinar cursus, nunc ante molestie purus, quis rutrum libero sem ut orci. Suspendisse pharetra laoreet purus, at feugiat purus fringilla sed. Cras suscipit porta ex, vel eleifend lectus vulputate non. Sed vel arcu diam. Vivamus sollicitudin tempus pharetra. Vestibulum porta elit nulla, vitae interdum tellus ultricies sit amet. Mauris quis rutrum eros. Phasellus ornare purus id eros viverra mattis. Suspendisse hendrerit, massa vitae sodales aliquam, velit diam pharetra magna, egestas faucibus arcu urna vestibulum diam. Duis ut viverra orci, ac ultricies nulla. Donec sed finibus erat, eu laoreet tortor. Vestibulum tempor tellus ut tortor tristique scelerisque. Donec at gravida lorem.\nVivamus ut velit semper, elementum nibh et, hendrerit neque. Vestibulum vitae libero sit amet lorem dictum dictum. Donec sed elementum massa. Etiam vel orci sit amet lorem sodales interdum. Fusce posuere vitae nibh sed mollis. Proin augue sapien, eleifend ut posuere ac, feugiat vel odio. Nunc et tellus rhoncus, commodo urna eu, placerat ipsum. Morbi sem est, elementum eu turpis ut, ullamcorper dictum eros.\nNullam non dui aliquam metus pretium feugiat. Integer ac lacus tempus, dapibus nisl eget, tincidunt orci. Nam porttitor felis eget pharetra aliquam. Donec molestie pretium eleifend. Aliquam erat volutpat. Sed eget sagittis augue. Cras nec lobortis ex, vitae sodales dui. Ut semper purus purus, a dictum urna pellentesque non. Phasellus velit leo, facilisis quis dolor ut, consequat faucibus metus. In lacinia quam sed quam aliquam, eget hendrerit felis aliquam. Cras eget nisi vel neque dapibus malesuada eu quis nulla. Donec luctus tempor dui, a porta sem luctus in. Sed eu malesuada odio, a fringilla nunc.\nPhasellus luctus non odio et fermentum. Duis tristique tincidunt mauris, et malesuada lectus finibus ac. Curabitur eu malesuada velit, ut ultrices odio. Nullam vehicula fringilla neque. Morbi mauris erat, efficitur non urna quis, accumsan laoreet lorem. Phasellus consequat sed libero non tempus. Mauris malesuada, lacus eu cursus accumsan, libero orci venenatis ligula, tincidunt commodo ante nunc at velit. Phasellus tristique risus in nulla faucibus interdum. Sed aliquet egestas sem, sed blandit enim venenatis quis. Pellentesque vel lorem aliquet, pharetra tellus id, consectetur libero. Sed sodales augue quam, et tempor velit ultrices sit amet. Quisque scelerisque justo facilisis dignissim feugiat.";

  static const String section2Title = '2. Modificaciones de los Términos';
  static const String section2Body =
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque luctus urna et ultricies auctor. Curabitur risus tortor, dignissim vitae tristique mollis, dictum nec augue. Proin mollis metus gravida imperdiet interdum. Curabitur sed est eu magna congue feugiat sit amet et dui. Nullam massa metus, blandit ac tristique sit amet, commodo nec tortor. Donec porttitor scelerisque turpis, vel tempus lacus cursus bibendum. Maecenas in pellentesque orci. Suspendisse ultricies elementum arcu, interdum hendrerit libero accumsan ut. Aenean vulputate purus cursus, pretium sem ut, bibendum odio. Mauris eget dictum elit, vel vulputate ex. Quisque id dui urna. Nulla in lacus quis sem tristique maximus. Ut arcu urna, rutrum id augue quis, efficitur scelerisque tortor. Integer aliquet, nisi ac laoreet consectetur, turpis diam aliquam tortor, vel tempor est justo et felis. Cras facilisis ipsum at nunc venenatis fermentum. \nCras convallis auctor sapien sed tempus. Ut mattis sagittis sagittis. Quisque fermentum justo non eros imperdiet faucibus et et erat. Mauris aliquam, purus malesuada pulvinar cursus, nunc ante molestie purus, quis rutrum libero sem ut orci. Suspendisse pharetra laoreet purus, at feugiat purus fringilla sed. Cras suscipit porta ex, vel eleifend lectus vulputate non. Sed vel arcu diam. Vivamus sollicitudin tempus pharetra. Vestibulum porta elit nulla, vitae interdum tellus ultricies sit amet. Mauris quis rutrum eros. Phasellus ornare purus id eros viverra mattis. Suspendisse hendrerit, massa vitae sodales aliquam, velit diam pharetra magna, egestas faucibus arcu urna vestibulum diam. Duis ut viverra orci, ac ultricies nulla. Donec sed finibus erat, eu laoreet tortor. Vestibulum tempor tellus ut tortor tristique scelerisque. Donec at gravida lorem.\nVivamus ut velit semper, elementum nibh et, hendrerit neque. Vestibulum vitae libero sit amet lorem dictum dictum. Donec sed elementum massa. Etiam vel orci sit amet lorem sodales interdum. Fusce posuere vitae nibh sed mollis. Proin augue sapien, eleifend ut posuere ac, feugiat vel odio. Nunc et tellus rhoncus, commodo urna eu, placerat ipsum. Morbi sem est, elementum eu turpis ut, ullamcorper dictum eros.\nNullam non dui aliquam metus pretium feugiat. Integer ac lacus tempus, dapibus nisl eget, tincidunt orci. Nam porttitor felis eget pharetra aliquam. Donec molestie pretium eleifend. Aliquam erat volutpat. Sed eget sagittis augue. Cras nec lobortis ex, vitae sodales dui. Ut semper purus purus, a dictum urna pellentesque non. Phasellus velit leo, facilisis quis dolor ut, consequat faucibus metus. In lacinia quam sed quam aliquam, eget hendrerit felis aliquam. Cras eget nisi vel neque dapibus malesuada eu quis nulla. Donec luctus tempor dui, a porta sem luctus in. Sed eu malesuada odio, a fringilla nunc.\nPhasellus luctus non odio et fermentum. Duis tristique tincidunt mauris, et malesuada lectus finibus ac. Curabitur eu malesuada velit, ut ultrices odio. Nullam vehicula fringilla neque. Morbi mauris erat, efficitur non urna quis, accumsan laoreet lorem. Phasellus consequat sed libero non tempus. Mauris malesuada, lacus eu cursus accumsan, libero orci venenatis ligula, tincidunt commodo ante nunc at velit. Phasellus tristique risus in nulla faucibus interdum. Sed aliquet egestas sem, sed blandit enim venenatis quis. Pellentesque vel lorem aliquet, pharetra tellus id, consectetur libero. Sed sodales augue quam, et tempor velit ultrices sit amet. Quisque scelerisque justo facilisis dignissim feugiat.";

  static const String lastUpdated = 'Fecha de última actualización: 23 de Junio de 2025';
}

// 2. Reusable widget for section titles
class TermsSectionHeader extends StatelessWidget {
  final String title;

  const TermsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 5.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// 3. Reusable widget for section body text
class TermsSectionBody extends StatelessWidget {
  final String text;

  const TermsSectionBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.5), // Added height for better readability
    );
  }
}


// 4. Main Screen Widget
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              TermsContent.welcomeTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              TermsContent.welcomeSubtitle,
              style: TextStyle(fontSize: 16),
            ),
            
            // Section 1
            TermsSectionHeader(title: TermsContent.section1Title),
            TermsSectionBody(text: TermsContent.section1Body),

            // Section 2
            TermsSectionHeader(title: TermsContent.section2Title),
            TermsSectionBody(text: TermsContent.section2Body),

            // Footer
            SizedBox(height: 30),
            Text(
              TermsContent.lastUpdated,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 10), // Add some bottom padding
          ],
        ),
      ),
    );
  }
}