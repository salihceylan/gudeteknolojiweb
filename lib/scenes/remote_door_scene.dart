import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reveal.dart';
import 'remote/ad_stage.dart';
import 'remote/ad_timeline.dart';

/// "İlk ürünümüz": yalnızca mobil uygulamayla uzaktan kapı açan kompakt kutu.
/// Solda metin, sağda animasyonlu reklam sahnesi; dar ekranda (dikey kompozisyon) başlık ve açıklama üstte, hemen altında
/// sahne, maddeler ile düğme sahnenin altında yer alır: sahne bölümün üstüne yerleşince reklamın sonucu (kutu, LED, kapı)
/// ilk bakışta ekranda kalır; maddeler ve düğme sahnenin ardından, kaydırınca gelir.
///
/// Renkler temadan gelir (açık/koyu); ürünün kendi malzemesi (kutu, telefon, LED) iki temada aynıdır.
/// Yalnızca metin sütunu [Reveal] ile süzülerek girer; reklam sahnesi kendi girişini (kutu belirir) zaten
/// oynadığından üstüne ikinci bir giriş animasyonu konmaz, böylece reklamın ilk saniyesi gizli kalmaz.
/// "Hareketi azalt" açıkken giriş animasyonu ve reklam döngüsü kapanır: içerik hemen görünür, sahne durağan son karedir.
class RemoteDoorScene extends StatelessWidget {
  const RemoteDoorScene({super.key, this.onContact, @visibleForTesting this.debugClock});

  /// "Teklif İsteyin" düğmesi.
  final VoidCallback? onContact;

  /// Yalnızca testler için: reklamın zamanını dışarıdan sürer.
  final AdClock? debugClock;

  // YER TUTUCU: ürün adı henüz kesin değil; kesinleşince yalnızca bu sabit güncellenir.
  static const _productName = RemoteDoorStage.productName;

  static const _bullets = [
    'Mobil uygulamayla uzaktan açma',
    'Wi-Fi ile bağlantı',
    'Kompakt, USB-C girişli gövde',
  ];

  /// Masaüstünde metin ile sahne arası boşluk; sahnenin genişlik sınırları ve metin sütununun en az genişliği.
  static const _columnGap = 48.0;
  static const _stageShare = 0.55;
  static const _stageWidthRange = (430.0, 620.0);
  static const _textMinWidth = 280.0;

  /// Masaüstünde açıklama ile maddeler arası boşluk (maddeler [_actions] içinde başlar).
  static const _headToActionsGap = 26.0;

  /// Dikey yerleşimde sahnenin en geniş hâli (telefon, tablet).
  static const _stackedMaxWidth = (phone: 420.0, tablet: 620.0);

  /// Dikey yerleşimde sahne çiziminin en çok ekran yüksekliğinin bu kadarı olur: üstündeki başlık + açıklama, altındaki
  /// altyazı ve üst çubukla birlikte sahne tek ekrana sığar. Çok kısa pencerelerde (yatay telefon) sahne
  /// [_stackedMinStageHeight]'ten küçülmez; orada kaydırma zaten gerekir.
  static const _stackedStageHeightShare = 0.58;
  static const _stackedMinStageHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Section(
      color: c.bgAlt,
      child: isWide(context) ? _wideLayout(context) : _stackedLayout(context, isPhone(context)),
    );
  }

  /// Metnin giriş animasyonu; hareketi azalt açıkken hiç sarmalanmaz, içerik hemen ve kesin görünür.
  Widget _reveal(BuildContext context, Widget child) => reduceMotionOf(context) ? child : Reveal(child: child);

  Widget _wideLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final stageW = (box.maxWidth * _stageShare).clamp(_stageWidthRange.$1, _stageWidthRange.$2);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _reveal(context, _text(context))),
            const SizedBox(width: _columnGap),
            SizedBox(
              width: stageW.clamp(0.0, box.maxWidth - _columnGap - _textMinWidth),
              child: RemoteDoorStage(debugClock: debugClock),
            ),
          ],
        );
      },
    );
  }

  Widget _stackedLayout(BuildContext context, bool compact) {
    final stageMaxHeight = math.max(MediaQuery.sizeOf(context).height * _stackedStageHeightShare, _stackedMinStageHeight);
    final gap = fluid(context, 36, 48);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reveal(context, _head(context)),
        SizedBox(height: gap),
        Align(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? _stackedMaxWidth.phone : _stackedMaxWidth.tablet),
            child: RemoteDoorStage(compact: compact, maxHeight: stageMaxHeight, debugClock: debugClock),
          ),
        ),
        SizedBox(height: gap),
        _reveal(context, _actions(context)),
      ],
    );
  }

  Widget _text(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(context),
        const SizedBox(height: _headToActionsGap),
        _actions(context),
      ],
    );
  }

  /// Etiket, başlık ve açıklama.
  Widget _head(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Eyebrow('İLK ÜRÜNÜMÜZ'),
        const SizedBox(height: 18),
        const SectionTitle('Kapıyı telefonunuzdan açın.'),
        const SizedBox(height: 16),
        const Lead('Yalnızca mobil uygulamayla, uzaktan kapı açan ilk $_productName cihazı. Kompakt kutu, tek dokunuşla açma.'),
      ],
    );
  }

  /// Maddeler ve "Teklif İsteyin" düğmesi.
  Widget _actions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in _bullets) _Bullet(b),
        const SizedBox(height: 30),
        PillButton(label: 'Teklif İsteyin', onTap: onContact ?? () {}),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  /// Madde çizgisi 1,5 px: kesirli konumlarda 1 px'lik çizgi iki piksel satıra yarı saydam yayılıp soluk görünür.
  static const _dashThickness = 1.5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 14),
            child: Container(width: 14, height: _dashThickness, color: c.accent),
          ),
          Expanded(child: Text(text, style: AppText.body(context, color: c.text))),
        ],
      ),
    );
  }
}
