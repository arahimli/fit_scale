import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/material.dart';

/// The demo order screen, written with fit_scale.
class GoodScreen extends StatelessWidget {
  const GoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fit = context.fit;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(fit.w(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                FitSquare(
                  size: 56,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D5BFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('JD',
                          style: TextStyle(
                              fontSize: fit.sp(18), color: Colors.white)),
                    ),
                  ),
                ),
                SizedBox(width: fit.w(12)),
                Expanded(
                  child: Text('Order summary',
                      style: TextStyle(
                          fontSize: fit.sp(20), fontWeight: FontWeight.w700)),
                ),
              ]),
              SizedBox(height: fit.h(16)),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(fit.r(16)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(fit.w(16)),
                  child: FitBox(
                    height: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wireless Headphones',
                            style: TextStyle(
                                fontSize: fit.sp(18),
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: fit.h(6)),
                        Text(
                          'Noise cancelling, 30-hour battery and USB-C '
                          'fast charging.',
                          style: TextStyle(fontSize: fit.sp(14)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: fit.h(16)),
              for (final label in const ['Shipping address', 'Payment method'])
                Padding(
                  padding: EdgeInsets.only(bottom: fit.h(8)),
                  child: Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {},
                      child: FitBox(
                        height: 52,
                        interactive: true,
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: fit.w(16),
                            vertical: fit.h(8),
                          ),
                          child: Text(label,
                              style: TextStyle(fontSize: fit.sp(15))),
                        ),
                      ),
                    ),
                  ),
                ),
              Text('Prices include VAT',
                  style: TextStyle(fontSize: fit.sp(11))),
              SizedBox(height: fit.h(24)),
              FitBox(
                height: 48,
                interactive: true,
                child: FilledButton(
                  onPressed: () {},
                  child: Text('Place order',
                      style: TextStyle(fontSize: fit.sp(16))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same idea written with linear-scaling habits: fixed heights,
/// a tiny tap target and a tiny caption.
class BadScreen extends StatelessWidget {
  const BadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: Column(children: const [
              Text('Wireless Headphones', style: TextStyle(fontSize: 18)),
              Text('Noise cancelling, 30-hour battery and USB-C '
                  'fast charging.'),
            ]),
          ),
          GestureDetector(
            onTap: () {},
            child: const SizedBox(width: 30, height: 30),
          ),
          const Text('Prices include VAT', style: TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}

Widget fitApp(Widget home) => FitScaleScope(
      child: MaterialApp(debugShowCheckedModeBanner: false, home: home),
    );
