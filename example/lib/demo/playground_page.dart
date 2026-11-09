import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import 'demo_models.dart';
import 'demo_widgets.dart';

enum _BodyFormat { json, formData, urlEncoded }

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  final TextEditingController _pathController =
      TextEditingController(text: '/posts');
  final TextEditingController _bodyController = TextEditingController();
  final List<DemoPair> _queryPairs = [
    DemoPair(key: 'userId', value: '1'),
  ];
  final List<DemoPair> _headerPairs = [
    DemoPair(key: 'Accept', value: 'application/json'),
  ];

  HttpMethod _method = HttpMethod.GET;
  CacheMode _cacheMode = CacheMode.ONLY_REQUEST;
  int _retryCount = 0;
  Duration _timeout = const Duration(seconds: 10);
  _BodyFormat _bodyFormat = _BodyFormat.json;

  DemoResult? _result;
  bool _loading = false;
  CancelToken? _cancelToken;

  bool get _supportsBody =>
      _method == HttpMethod.POST ||
      _method == HttpMethod.PUT ||
      _method == HttpMethod.PATCH;

  @override
  void dispose() {
    _pathController.dispose();
    _bodyController.dispose();
    for (final pair in _queryPairs) {
      pair.dispose();
    }
    for (final pair in _headerPairs) {
      pair.dispose();
    }
    super.dispose();
  }

  void _updateMethod(HttpMethod method) {
    final previousSample = samplePathFor(_method);
    final currentPath = _pathController.text.trim();
    final shouldReplacePath =
        currentPath.isEmpty || currentPath == previousSample;

    setState(() {
      _method = method;
      if (shouldReplacePath) {
        _pathController.text = samplePathFor(method);
      }
      if (_supportsBody && _bodyController.text.trim().isEmpty) {
        _bodyController.text = prettyJson(sampleBodyFor(method));
      }
      if (!_supportsBody) {
        _bodyController.clear();
      }
    });
  }

  void _reset() {
    for (final pair in _queryPairs) {
      pair.dispose();
    }
    for (final pair in _headerPairs) {
      pair.dispose();
    }
    _queryPairs
      ..clear()
      ..add(DemoPair(key: 'userId', value: '1'));
    _headerPairs
      ..clear()
      ..add(DemoPair(key: 'Accept', value: 'application/json'));

    setState(() {
      _method = HttpMethod.GET;
      _pathController.text = '/posts';
      _bodyController.clear();
      _cacheMode = CacheMode.ONLY_REQUEST;
      _retryCount = 0;
      _timeout = const Duration(seconds: 10);
      _bodyFormat = _BodyFormat.json;
      _result = null;
    });
  }

  Future<void> _send() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写请求路径')),
      );
      return;
    }

    if (_supportsBody && _bodyController.text.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(_bodyController.text);
        if (decoded is! Map) {
          throw const FormatException('Body 必须是 JSON 对象');
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Body JSON 无效：$error')),
        );
        return;
      }
    }

    FocusScope.of(context).unfocus();
    final token = CancelToken();
    final stopwatch = Stopwatch()..start();
    AdapterResponse? captured;

    setState(() {
      _loading = true;
      _result = null;
      _cancelToken = token;
    });

    try {
      final request = _buildRequest(
        token,
        (response) => captured = response,
      );
      final result = await request.request();
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _result = DemoResult.from(
          result: result,
          response: captured,
          elapsed: stopwatch.elapsed,
        );
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _result = DemoResult.failure(error, elapsed: stopwatch.elapsed);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _cancelToken = null;
        });
      }
    }
  }

  BuildRequest<dynamic> _buildRequest(
    CancelToken token,
    void Function(AdapterResponse response) onResponse,
  ) {
    final request = switch (_method) {
      HttpMethod.GET => RxNet.get(),
      HttpMethod.POST => RxNet.post(),
      HttpMethod.PUT => RxNet.put(),
      HttpMethod.PATCH => RxNet.patch(),
      HttpMethod.DELETE => RxNet.delete(),
      HttpMethod.HEAD => RxNet.head(),
      HttpMethod.OPTIONS => RxNet.options(),
    };

    request.setPath(_pathController.text.trim());

    final query = mapFromPairs(_queryPairs);
    if (query.isNotEmpty) {
      request.setQueryParams(query);
    }

    for (final entry in mapFromPairs(_headerPairs).entries) {
      request.setHeader(entry.key, entry.value);
    }

    if (_supportsBody && _bodyController.text.trim().isNotEmpty) {
      final decoded = jsonDecode(_bodyController.text);
      if (decoded is Map) {
        request.setBodyParams(Map<String, dynamic>.from(decoded));
        switch (_bodyFormat) {
          case _BodyFormat.json:
            request.asJson();
          case _BodyFormat.formData:
            request.asFormData();
          case _BodyFormat.urlEncoded:
            request.asUrlEncoded();
        }
      }
    }

    if (_retryCount > 0) {
      request.setRetryCount(
        _retryCount,
        interval: const Duration(milliseconds: 300),
      );
    }

    request
        .setCacheMode(_cacheMode)
        .setConnectTimeout(_timeout)
        .setReceiveTimeout(_timeout)
        .setCancelToken(token)
        .setResponseCallBack(onResponse);

    return request;
  }

  void _cancel() {
    _cancelToken?.cancel('用户取消请求');
  }

  String _codeSnippet() {
    final queryLiteral = pairsToDartLiteral(_queryPairs);
    final headers = mapFromPairs(_headerPairs);
    final buffer = StringBuffer()
      ..writeln('final cancelToken = CancelToken();')
      ..writeln('')
      ..writeln('final result = await RxNet.'
          '${_method.name.toLowerCase()}()')
      ..writeln("    .setPath('${_escape(_pathController.text.trim())}')");

    if (queryLiteral != '{}') {
      buffer.writeln('    .setQueryParams($queryLiteral)');
    }

    for (final entry in headers.entries) {
      buffer.writeln(
        "    .setHeader('${_escape(entry.key)}', '${_escape(entry.value.toString())}')",
      );
    }

    buffer
      ..writeln('    .setCacheMode(CacheMode.${_cacheMode.name})')
      ..writeln(
        '    .setConnectTimeout(const Duration(seconds: ${_timeout.inSeconds}))',
      )
      ..writeln(
        '    .setReceiveTimeout(const Duration(seconds: ${_timeout.inSeconds}))',
      );

    if (_retryCount > 0) {
      buffer.writeln(
        '    .setRetryCount($_retryCount, interval: const Duration(milliseconds: 300))',
      );
    }

    if (_supportsBody && _bodyController.text.trim().isNotEmpty) {
      buffer
        ..writeln('    .setBodyParams(${_bodyLiteral()})')
        ..writeln('    .${switch (_bodyFormat) {
          _BodyFormat.json => 'asJson()',
          _BodyFormat.formData => 'asFormData()',
          _BodyFormat.urlEncoded => 'asUrlEncoded()',
        }}');
    }

    buffer
      ..writeln('    .setCancelToken(cancelToken)')
      ..writeln(
        "    .setResponseCallBack((response) => debugPrint('status: \${response.statusCode}'))",
      )
      ..writeln('    .request();')
      ..writeln('')
      ..writeln('// result.isSuccess / result.value / result.model');

    return buffer.toString();
  }

  String _bodyLiteral() {
    try {
      final decoded = jsonDecode(_bodyController.text);
      if (decoded is Map) {
        return '{${decoded.entries.map((entry) => "'${_escape(entry.key.toString())}': ${_dartValue(entry.value)}").join(', ')}}';
      }
    } catch (_) {
      // 保持示例可读性
    }
    return '{}';
  }

  String _dartValue(dynamic value) {
    if (value is String) return "'${_escape(value)}'";
    if (value is num || value is bool || value == null) return '$value';
    return jsonEncode(value);
  }

  String _escape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
  }

  String _cacheLabel(CacheMode mode) {
    return switch (mode) {
      CacheMode.ONLY_REQUEST => '仅网络',
      CacheMode.ONLY_CACHE => '仅缓存',
      CacheMode.REQUEST_FAILED_READ_CACHE => '网络失败读缓存',
      CacheMode.FIRST_USE_CACHE_THEN_REQUEST => '先缓存后网络',
      CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST => '缓存优先',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final form = _buildFormCard(context);
        final result = ResultPanel(
          result: _result,
          loading: _loading,
          emptyHint: '选择请求方法、填写参数后发送。'
              '这里会展示状态码、网络/缓存来源、耗时、响应头和响应体。',
        );
        final code = DemoSectionCard(
          title: '生成的 Dart 代码',
          subtitle: '跟随当前表单实时更新，可直接复制到项目中使用',
          icon: Icons.code,
          child: CodeBlock(code: _codeSnippet()),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 28 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DemoPageHeader(
                title: '请求游乐场',
                subtitle: '组合请求方法、Query、Body、Header、缓存、重试与超时，'
                    '实时查看网络/缓存响应。',
                icon: Icons.play_circle_outline,
              ),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          form,
                          const SizedBox(height: 16),
                          code,
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: result),
                  ],
                )
              else
                Column(
                  children: [
                    form,
                    const SizedBox(height: 16),
                    result,
                    const SizedBox(height: 16),
                    code,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DemoSectionCard(
      title: '请求构造器',
      subtitle: '基础地址：${RxNet.I.baseUrl}',
      icon: Icons.tune,
      actions: [
        IconButton(
          tooltip: '恢复示例',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HttpMethod.values.map((method) {
              final selected = _method == method;
              final color = methodColor(method);
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => _updateMethod(method),
                avatar: Icon(
                  selected ? Icons.check : Icons.circle,
                  size: selected ? 14 : 8,
                  color: selected ? color : color.withAlpha(140),
                ),
                label: Text(
                  method.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? color : scheme.onSurface,
                  ),
                ),
                selectedColor: color.withAlpha(30),
                side: BorderSide(
                  color: selected ? color.withAlpha(120) : scheme.outlineVariant,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pathController,
            decoration: InputDecoration(
              labelText: 'Request Path',
              hintText: '/posts/1',
              prefixIcon: const Icon(Icons.link),
              helperText: 'GET / POST 使用 /posts，其余方法默认 /posts/1',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          _sectionLabel(context, 'Query Params'),
          KeyValueEditor(
            pairs: _queryPairs,
            onChanged: () => setState(() {}),
            keyHint: 'userId',
            valueHint: '1',
            addLabel: '添加 Query 参数',
          ),
          if (_supportsBody) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _sectionLabel(context, 'Body')),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<_BodyFormat>(
                    key: ValueKey('body-${_bodyFormat.name}'),
                    initialValue: _bodyFormat,
                    decoration: const InputDecoration(
                      labelText: 'Body 格式',
                      isDense: true,
                    ),
                    items: _BodyFormat.values
                        .map(
                          (format) => DropdownMenuItem(
                            value: format,
                            child: Text(_bodyFormatLabel(format)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _bodyFormat = value);
                    },
                  ),
                ),
              ],
            ),
            TextField(
              controller: _bodyController,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: '{"title": "...", "body": "..."}',
                helperText: 'POST / PUT / PATCH 使用；JSON / FormData / URL-Encoded',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 14),
          _sectionLabel(context, 'Headers'),
          KeyValueEditor(
            pairs: _headerPairs,
            onChanged: () => setState(() {}),
            keyHint: 'Accept',
            valueHint: 'application/json',
            addLabel: '添加 Header',
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, '请求选项'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<CacheMode>(
                  key: ValueKey('cache-${_cacheMode.name}'),
                  initialValue: _cacheMode,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: '缓存模式'),
                  items: CacheMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(
                            _cacheLabel(mode),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _cacheMode = value);
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('retry-$_retryCount'),
                  initialValue: _retryCount,
                  decoration: const InputDecoration(labelText: '重试次数'),
                  items: [0, 1, 2, 3]
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count 次'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _retryCount = value);
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<Duration>(
                  key: ValueKey('timeout-${_timeout.inSeconds}'),
                  initialValue: _timeout,
                  decoration: const InputDecoration(labelText: '超时'),
                  items: const [
                    Duration(seconds: 5),
                    Duration(seconds: 10),
                    Duration(seconds: 20),
                    Duration(seconds: 30),
                  ]
                      .map(
                        (duration) => DropdownMenuItem(
                          value: duration,
                          child: Text('${duration.inSeconds} 秒'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _timeout = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _send,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_loading ? '请求中…' : '发送请求'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _loading ? _cancel : null,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('取消'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '提示：GET / HEAD / OPTIONS 没有 Body；DELETE 的 body 参数会按库行为转为 Query。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _bodyFormatLabel(_BodyFormat format) {
    return switch (format) {
      _BodyFormat.json => 'JSON',
      _BodyFormat.formData => 'FormData',
      _BodyFormat.urlEncoded => 'URL Encoded',
    };
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}