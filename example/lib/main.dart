import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const FitScaleScope(
      // The frame your designer drew on.
      config: FitScaleConfig(designSize: Size(360, 690)),
      // Outlines small tap targets and text while you develop; off in
      // release builds.
      child: FitDebugOverlay(child: MaterialApp(home: CheckoutPage())),
    );
  }
}

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fit = context.fit;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(fit.w(16)),
          children: [
            Row(
              children: [
                // Stays a circle on every aspect ratio, and the initials
                // shrink to stay inside it with a large system font.
                FitSquare(
                  size: 56,
                  child: const CircleAvatar(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: FitText('ER'),
                    ),
                  ),
                ),
                SizedBox(width: fit.w(12)),
                Expanded(
                  child: Text(
                    'Checkout',
                    style: TextStyle(fontSize: fit.sp(20)),
                  ),
                ),
              ],
            ),
            SizedBox(height: fit.h(16)),
            // Grows instead of overflowing when the text gets bigger.
            Card(
              child: Padding(
                padding: EdgeInsets.all(fit.w(16)),
                child: FitBox(
                  height: 96,
                  child: Text(
                    '25 GB internet, unlimited calls and 500 SMS for a month.',
                    style: TextStyle(fontSize: fit.sp(14)),
                  ),
                ),
              ),
            ),
            SizedBox(height: fit.h(24)),
            // Never shorter than 48 (Android) or 44 (iOS).
            FitBox(
              height: 48,
              interactive: true,
              child: FilledButton(
                onPressed: () {},
                child: Text('Continue', style: TextStyle(fontSize: fit.sp(16))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
