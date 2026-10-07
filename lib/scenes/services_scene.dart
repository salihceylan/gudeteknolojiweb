import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reveal.dart';

/// Hizmetler: yüzeyleri grafit (açık temada beyaz), çizgileri ince, ikonları tek renkli sade kartlar.
/// Renk yok; üzerine gelince yüzey hafifçe parlar, kart birkaç piksel yükselir ve alt çizgi turkuaza döner.
class ServicesScene extends StatelessWidget {
  const ServicesScene({super.key});

  static const _items = <_Service>[
    _Service(
      Icons.doorbell_outlined,
      'İnterkom Sistemleri',
      'IP ve iki telli görüntülü interkom sistemleri, güvenlik ve daire iletişim çözümleri',
    ),
    _Service(
      Icons.badge_outlined,
      'Geçiş Kontrol',
      'Kartlı geçiş, kapı kontrolü, personel erişimi ve merkezi yönetim sistemleri',
    ),
    _Service(
      Icons.fence_outlined,
      'Turnike ve Bariyer',
      'Personel ve araç geçişlerinin kontrolü için turnike ve bariyer çözümleri',
    ),
    _Service(
      Icons.local_fire_department_outlined,
      'Yangın Algılama',
      'Yangın algılama, ihbar ve projeye uygun güvenlik sistemleri',
    ),
    _Service(
      Icons.home_outlined,
      'Akıllı Ev Sistemleri',
      'Aydınlatma, kontrol, güvenlik ve otomasyon sistemlerinin entegre çözümleri',
    ),
  ];

  /// Genişliğe göre sütun sayısı: masaüstü 3, tablet 2, telefon 1.
  /// Sütun sayısı satırdan satıra değişmez; son satırdaki boş hücreler yer tutar, böylece kartların
  /// genişliği ve dikey hizaları bütün satırlarda aynı kalır (5. kart hiçbir ekranda tek başına genişlemez).
  static int _columnsFor(double width) => width >= 900 ? 3 : (width >= 600 ? 2 : 1);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final columns = _columnsFor(MediaQuery.sizeOf(context).width);
    final gap = fluid(context, 12, 20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HairlineDivider(),
        Section(
          color: c.bgAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('HİZMETLERİMİZ'),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      // Ortak SectionTitle başlık işaretlemesi taşımadığından burada sarılır.
                      child: Semantics(header: true, child: const SectionTitle('Teknolojiyi projenin ihtiyacına göre uygularız.')),
                    ),
                  ],
                ),
              ),
              SizedBox(height: fluid(context, 32, 56)),
              _rows(columns, gap),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rows(int columns, double gap) {
    final rows = <Widget>[];
    for (var start = 0; start < _items.length; start += columns) {
      final cells = <Widget>[
        for (var j = 0; j < columns; j++) ...[
          if (j > 0) SizedBox(width: gap),
          Expanded(
            child: start + j < _items.length
                ? Reveal(
                    delay: Duration(milliseconds: 70 * (start + j)),
                    child: _ServiceCard(index: start + j, service: _items[start + j]),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ];
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      // Aynı satırdaki kartlar, metin uzunluğundan bağımsız eşit yükseklikte olsun.
      rows.add(columns > 1 ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)) : Row(children: cells));
    }
    return Column(children: rows);
  }
}

class _Service {
  const _Service(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.index, required this.service});

  final int index;
  final _Service service;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.service;
    final reduce = reduceMotionOf(context);
    final pad = fluid(context, 22, 28);
    final number = (widget.index + 1).toString().padLeft(2, '0');

    // Metin bloğu hover'a bağlı değil: animasyon karelerinde yeniden kurulmasın diye builder'a `child` olarak verilir.
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.title, style: AppText.h3(context)),
        const SizedBox(height: 10),
        Text(s.text, style: AppText.body(context)),
      ],
    );

    // Kartlar etkileşimli değil (bağlantı vermiyor); bu yüzden klavye odağı almazlar, yalnızca fare vurgusu vardır.
    return MergeSemantics(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _hover ? 1 : 0),
          // Kısa yay: kart hedefini ~%4 aşıp yerine oturur. Hareketi azalt açıksa yalnızca renk değişir, anında.
          duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
          curve: const SpringCurve(),
          child: copy,
          builder: (context, t, child) {
            final h = t.clamp(0.0, 1.0);
            // Hover'da yüzey yazı renginin %3.5'i kadar karışır: koyuda hafif aydınlanır, açıkta hafif grileşir
            // (açık temada surfaceHi'ye gitmek kartı zeminden ayırt edilemez hale getirirdi).
            final fill = Color.alphaBlend(c.text.withValues(alpha: 0.035 * h), c.surface);
            // Yükselme RepaintBoundary'nin dışında: kart yeniden boyanmadan yalnızca katman kayar.
            return Transform.translate(
              offset: Offset(0, reduce ? 0 : -4 * t),
              child: RepaintBoundary(
                key: ValueKey('service-card-${widget.index}'),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Gradyan verilince `color` yok sayılır; bu yüzden gradyan uçları dolgu rengiyle harmanlanmış, opak renklerdir.
                    color: fill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color.lerp(c.line, c.lineStrong, h)!),
                    // Yumuşak gölge yalnızca vurguda; dinlenme halinde hiç yoktur.
                    boxShadow: h > 0 ? [BoxShadow(color: c.shadow.withValues(alpha: c.shadow.a * 0.6 * h), blurRadius: 28, offset: const Offset(0, 12))] : null,
                    // Yüzey parlaması: sol üstten ışık. Dinlenme halinde gradyan hiç kurulmaz.
                    gradient: h > 0
                        ? RadialGradient(
                            center: const Alignment(-0.7, -1.1),
                            radius: 1.3,
                            colors: [Color.alphaBlend(c.stageGlow.withValues(alpha: c.stageGlow.a * h), fill), fill],
                          )
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(s.icon, size: 28, color: Color.lerp(c.textDim, c.text, h)),
                                  const Spacer(),
                                  // Numara süs değil bilgi: textDim ile iki temada da ≥ 4.5:1; vurguda turkuaz yazı tonuna döner.
                                  ExcludeSemantics(child: Text(number, style: AppText.label(context, color: Color.lerp(c.textDim, c.accentText, h)))),
                                ],
                              ),
                              SizedBox(height: fluid(context, 24, 32)),
                              child!,
                            ],
                          ),
                        ),
                        // İnce turkuaz alt çizgi soldan sağa uzar.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              key: ValueKey('service-line-${widget.index}'),
                              widthFactor: h,
                              child: SizedBox(height: 1, child: ColoredBox(color: c.accent)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
