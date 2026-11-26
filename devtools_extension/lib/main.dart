import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FitScaleDevToolsExtension());

class FitScaleDevToolsExtension extends StatelessWidget {
  const FitScaleDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: FitScalePanel());
  }
}

/// Reads `ext.fit_scale.state` once a second and drives the
/// `setTextScale` and `setOverlay` extensions of the connected app.
class FitScalePanel extends StatefulWidget {
  const FitScalePanel({super.key});

  @override
  State<FitScalePanel> createState() => _FitScalePanelState();
}

class _FitScalePanelState extends State<FitScalePanel> {
  Map<String, dynamic>? _state;
  String? _error;
  Timer? _timer;
  double _textScale = 1.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      'ext.fit_scale.$method',
      args: args,
    );
    return response.json ?? const {};
  }

  Future<void> _refresh() async {
    if (!serviceManager.connectedState.value.connected) {
      if (mounted) setState(() => _error = 'Not connected to an app.');
      return;
    }
    try {
      final state = await _call('state');
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = null;
        // The slider follows what the app shows: the forced scale, or
        // the device's own when nothing is forced.
        final shown = state['forcedTextScale'] ?? state['systemTextScale'];
        if (shown is num) _textScale = shown.toDouble();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'fit_scale is not running in this app. Use a debug or profile '
          'build with a FitScaleScope above the app.');
    }
  }

  Future<void> _setTextScale(double? scale) async {
    await _call('setTextScale', {'scale': scale?.toString() ?? 'off'});
    await _refresh();
  }

  Future<void> _setOverlay(String enabled) async {
    await _call('setOverlay', {'enabled': enabled});
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (_error != null || state == null) {
      return Center(child: Text(_error ?? 'Connecting…'));
    }
    if (state['connected'] != true) {
      return const Center(
        child: Text('No FitScaleScope in the running app yet.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _screenCard(state),
            _textScaleCard(state),
            _overlayCard(state),
          ],
        ),
        const SizedBox(height: 16),
        _problemsCard(state),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) => SizedBox(
        width: 340,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 140, child: Text(label)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  String _n(Object? v) => v is num ? v.toStringAsFixed(2) : '–';

  Widget _screenCard(Map<String, dynamic> s) {
    final hinge = s['hinge'] as Map<String, dynamic>?;
    return _card('Screen', [
      _row('Size', '${_n(s['width'])} × ${_n(s['height'])}'),
      _row('Design', '${_n(s['designWidth'])} × ${_n(s['designHeight'])}'),
      _row('Window class', '${s['windowClass']} (height ${s['heightClass']})'),
      _row(
        'Factors',
        'w ${_n(s['scaleWidth'])}  h ${_n(s['scaleHeight'])}  '
            'r ${_n(s['scale'])}  sp ${_n(s['fontScale'])}',
      ),
      _row('Min tap target', _n(s['minTapTarget'])),
      _row(
        'Fold / hinge',
        hinge == null ? 'none' : '${hinge['posture']} at '
            '${_n(hinge['left'])}, ${_n(hinge['top'])}',
      ),
    ]);
  }

  Widget _textScaleCard(Map<String, dynamic> s) {
    final forced = s['forcedTextScale'];
    return _card('System text size', [
      _row('Device setting', '×${_n(s['systemTextScale'])}'),
      _row('Showing', forced == null ? 'device setting' : '×${_n(forced)}'),
      Slider(
        value: _textScale.clamp(1.0, 3.0),
        min: 1,
        max: 3,
        divisions: 20,
        label: '×${_textScale.toStringAsFixed(2)}',
        onChanged: (v) => setState(() => _textScale = v),
        onChangeEnd: _setTextScale,
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final v in const [1.0, 1.3, 2.0])
            OutlinedButton(
              onPressed: () {
                setState(() => _textScale = v);
                _setTextScale(v);
              },
              child: Text('×$v'),
            ),
          TextButton(
            onPressed: () => _setTextScale(null),
            child: const Text('Use device setting'),
          ),
        ],
      ),
    ]);
  }

  Widget _overlayCard(Map<String, dynamic> s) {
    final forced = s['forcedOverlay'];
    return _card('Debug overlay', [
      const Text('Needs a FitDebugOverlay in the app.'),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'default', label: Text('App setting')),
          ButtonSegment(value: 'true', label: Text('On')),
          ButtonSegment(value: 'false', label: Text('Off')),
        ],
        selected: {forced == null ? 'default' : '$forced'},
        onSelectionChanged: (v) => _setOverlay(v.single),
      ),
    ]);
  }

  Widget _problemsCard(Map<String, dynamic> s) {
    final problems = (s['problems'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    const colors = {
      'tapTarget': Color(0xFFE53935),
      'smallText': Color(0xFF8E24AA),
      'truncatedText': Color(0xFFFB8C00),
      'hingeOverlap': Color(0xFF00897B),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Problems on screen (${problems.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (problems.isEmpty)
              const Text('None found by the debug overlay.'),
            for (final p in problems)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.crop_square,
                  color: colors[p['kind']] ?? Colors.grey,
                ),
                title: Text('${p['message']}'),
                subtitle: Text(
                  '${p['kind']} · at ${_n(p['left'])}, ${_n(p['top'])} · '
                  '${_n(p['width'])} × ${_n(p['height'])}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
