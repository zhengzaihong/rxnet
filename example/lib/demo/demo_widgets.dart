import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import 'demo_models.dart';

/// 可编辑的键值对
class DemoPair {
  final TextEditingController keyController;
  final TextEditingController valueController;

  DemoPair({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

Map<String, dynamic> mapFromPairs(List<DemoPair> pairs) {
  final result = <String, dynamic>{};
  for (final pair in pairs) {
    final key = pair.keyController.text.trim();
    if (key.isEmpty) continue;
    result[key] = pair.valueController.text.trim();
  }
  return result;
}

String pairsToDartLiteral(List<DemoPair> pairs) {
  final values = mapFromPairs(pairs);
  if (values.isEmpty) return '{}';
  return '{${values.entries.map((entry) => "'${entry.key}': '${_escape(entry.value.toString())}'").join(', ')}}';
}

String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n');

/// 键值对编辑器
class KeyValueEditor extends StatelessWidget {
  const KeyValueEditor({
    super.key,
    required this.pairs,
    required this.onChanged,
    this.keyHint = 'Key',
    this.valueHint = 'Value',
    this.addLabel = '添加参数',
  });

  final List<DemoPair> pairs;
  final VoidCallback onChanged;
  final String keyHint;
  final String valueHint;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pairs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: pairs[i].keyController,
                    decoration: InputDecoration(hintText: keyHint),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: pairs[i].valueController,
                    decoration: InputDecoration(hintText: valueHint),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '移除',
                  onPressed: () {
                    final removed = pairs.removeAt(i);
                    removed.dispose();
                    onChanged();
                  },
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () {
            pairs.add(DemoPair());
            onChanged();
          },
          icon: const Icon(Icons.add, size: 18),
          label: Text(addLabel),
        ),
      ],
    );
  }
}

/// 页面标题
class DemoPageHeader extends StatelessWidget {
  const DemoPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用卡片
class DemoSectionCard extends StatelessWidget {
  const DemoSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surface.withAlpha(238),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withAlpha(170),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

Color methodColor(HttpMethod method) {
  return switch (method) {
    HttpMethod.GET => const Color(0xFF2563EB),
    HttpMethod.POST => const Color(0xFF16A34A),
    HttpMethod.PUT => const Color(0xFFEA580C),
    HttpMethod.PATCH => const Color(0xFF7C3AED),
    HttpMethod.DELETE => const Color(0xFFDC2626),
    HttpMethod.HEAD => const Color(0xFF0F766E),
    HttpMethod.OPTIONS => const Color(0xFF475569),
  };
}

class MethodBadge extends StatelessWidget {
  const MethodBadge(this.method, {super.key});

  final HttpMethod method;

  @override
  Widget build(BuildContext context) {
    final color = methodColor(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        method.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(24),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: effectiveColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.result});

  final DemoResult? result;

  @override
  Widget build(BuildContext context) {
    final value = result;
    final scheme = Theme.of(context).colorScheme;

    if (value == null) {
      return InfoPill(label: '待发送', color: scheme.outline);
    }

    final success = value.success;
    final color = success ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final label = value.statusCode != null
        ? 'HTTP ${value.statusCode}'
        : success
            ? 'SUCCESS'
            : 'ERROR';

    return InfoPill(label: label, color: color, icon: success ? Icons.check : Icons.close);
  }
}

/// 代码块
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.label = 'Dart'});

  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6, top: 6),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '复制代码',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('代码已复制')),
                    );
                  },
                  icon: const Icon(
                    Icons.copy_all_outlined,
                    size: 17,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  height: 1.55,
                  fontSize: 12.2,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 响应面板
class ResultPanel extends StatelessWidget {
  const ResultPanel({
    super.key,
    required this.result,
    required this.loading,
    this.emptyHint = '发送请求后，这里会展示状态码、来源、响应头和响应体。',
  });

  final DemoResult? result;
  final bool loading;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = result;

    return Card(
      elevation: 0,
      color: scheme.surface.withAlpha(238),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: loading
              ? _buildLoading(context)
              : value == null
                  ? _buildEmpty(context)
                  : _buildResult(context, value),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('loading'),
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              '请求中…',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('empty'),
      height: 260,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.data_object, size: 42, color: scheme.outline),
              const SizedBox(height: 12),
              Text(
                emptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, DemoResult value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headers = value.headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return DefaultTabController(
      key: const ValueKey('result'),
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(result: value),
                    InfoPill(
                      label: value.source == SourcesType.cache
                          ? 'CACHE'
                          : 'NETWORK',
                      color: value.source == SourcesType.cache
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF2563EB),
                      icon: value.source == SourcesType.cache
                          ? Icons.savings_outlined
                          : Icons.cloud_outlined,
                    ),
                    InfoPill(
                      label: '${value.elapsed.inMilliseconds} ms',
                      color: scheme.outline,
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '复制响应体',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value.body));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('响应体已复制')),
                  );
                },
                icon: const Icon(Icons.copy_all_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            tabs: [
              const Tab(text: 'Body'),
              Tab(text: 'Headers (${headers.length})'),
            ],
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [
                Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(
                      value.body,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        height: 1.5,
                        fontSize: 12.4,
                      ),
                    ),
                  ),
                ),
                if (headers.isEmpty)
                  const Center(child: Text('无响应头'))
                else
                  ListView.separated(
                    padding: const EdgeInsets.only(top: 12),
                    itemCount: headers.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final entry = headers[index];
                      return SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${entry.key}\n',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            TextSpan(
                              text: entry.value.join(', '),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}