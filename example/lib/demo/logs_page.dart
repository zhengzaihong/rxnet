import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import 'demo_widgets.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  bool _collect = true;

  @override
  void initState() {
    super.initState();
    RxNet.I.logManager.setCollectLogs(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = RxNet.I.logManager;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DemoPageHeader(
            title: '运行日志',
            subtitle: '查看请求、响应、耗时与错误日志。敏感 Header / Body 默认脱敏。',
            icon: Icons.terminal_outlined,
          ),
          DemoSectionCard(
            title: '日志控制台',
            subtitle: kDebugMode ? '当前为 debug 模式，日志已开启' : 'release 模式默认关闭日志',
            icon: Icons.tune,
            actions: [
              IconButton(
                tooltip: '复制全部',
                onPressed: () async {
                  final logs = manager.logsNotifier.value;
                  await Clipboard.setData(ClipboardData(text: logs.join('\n')));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('日志已复制')),
                  );
                },
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                tooltip: '清空',
                onPressed: manager.clearLogs,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
            child: Row(
              children: [
                Switch(
                  value: _collect,
                  onChanged: (value) {
                    setState(() => _collect = value);
                    manager.setCollectLogs(value);
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  _collect ? '正在收集日志' : '已暂停收集',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<List<String>>(
                  valueListenable: manager.logsNotifier,
                  builder: (context, logs, _) {
                    return InfoPill(
                      label: '${logs.length} 条',
                      color: scheme.primary,
                      icon: Icons.list_alt,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: manager.logsNotifier,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 42, color: scheme.outline),
                        const SizedBox(height: 10),
                        Text(
                          '暂无日志。\n在 Playground / Methods / Recipes 发送请求后再回来查看。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                final reversed = logs.reversed.toList();
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Scrollbar(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: reversed.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 10,
                        color: Color(0x22FFFFFF),
                      ),
                      itemBuilder: (context, index) {
                        return SelectableText(
                          reversed[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.8,
                            height: 1.45,
                            color: Color(0xFFE2E8F0),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}