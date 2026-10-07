import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/theme.dart';
import 'package:gudeteknolojiweb/widgets/common.dart';

import 'helpers/shot.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shot yardımcısı gerçek yazı tipiyle PNG üretir', (tester) async {
    final path = await shot(
      tester,
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Kamera sistemleri'),
                const SizedBox(height: 16),
                const SectionTitle('Her açıdan net görüntü.'),
                const SizedBox(height: 12),
                const Lead('IP ve analog kamera sistemleri, kayıt çözümleri, ağ altyapısı ve profesyonel görüntüleme sistemleri.'),
                const SizedBox(height: 24),
                Row(children: [PillButton(label: 'Keşfedin', icon: Icons.arrow_downward_rounded, onTap: () {}), const SizedBox(width: 12), PillButton(label: 'Bize Ulaşın', filled: false, onTap: () {})]),
              ],
            ),
          ),
        ),
      ),
      size: const Size(900, 420),
      name: 'helpers_smoke',
    );
    // ignore: avoid_print
    print('SHOT: $path');
  });
}
