import 'package:material_ui/material_ui.dart';

import '../ortak.dart';

class TakvimEkrani extends StatelessWidget {
  const TakvimEkrani({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Renk.krem, title: const Text('Takvim')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Samsung Takvim bağlantısı 4. aşamada gelecek.',
                textAlign: TextAlign.center, style: TextStyle(color: Renk.kahve)),
          ),
        ),
      );
}
