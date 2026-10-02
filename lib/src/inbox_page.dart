import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'pkb_fcm.dart';

/// หน้ารายการแจ้งเตือนสำเร็จรูป (ไม่บังคับใช้ — แอปที่มีหน้าแจ้งเตือนอยู่แล้วไม่ต้องใช้)
///
/// ```dart
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const PkbFcmInboxPage()));
/// ```
class PkbFcmInboxPage extends StatefulWidget {
  const PkbFcmInboxPage({
    super.key,
    this.title = 'การแจ้งเตือน',
    this.emptyText = 'ยังไม่มีการแจ้งเตือน',
    this.errorText = 'โหลดข้อมูลไม่สำเร็จ ลากลงเพื่อลองใหม่',
    this.readAllTooltip = 'อ่านทั้งหมด',
    this.onTap,
    this.api,
  });

  final String title;
  final String emptyText;
  final String errorText;
  final String readAllTooltip;

  /// กดรายการ (ถูก mark อ่านแล้วให้อัตโนมัติ) — ใช้พาไปหน้าตาม `item.data['screen']`
  final void Function(BuildContext context, PkbFcmInboxItem item)? onTap;

  /// ใช้ API อื่นแทน `PkbFcm.api` (สำหรับ test)
  final PkbFcmApi? api;

  @override
  State<PkbFcmInboxPage> createState() => _PkbFcmInboxPageState();
}

class _PkbFcmInboxPageState extends State<PkbFcmInboxPage> {
  final _items = <PkbFcmInboxItem>[];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _error = false;

  PkbFcmApi get _api => widget.api ?? PkbFcm.api;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _items.clear();
    _page = 0;
    _lastPage = 1;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await _api.inbox(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _lastPage = result.lastPage;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(PkbFcmInboxItem item) async {
    if (!item.read) {
      setState(() => item.read = true);
      try {
        await _api.markRead(item.id);
      } catch (_) {
        // ไม่สำคัญพอจะแจ้งผู้ใช้
      }
    }
    if (mounted && widget.onTap != null) widget.onTap!(context, item);
  }

  Future<void> _readAll() async {
    try {
      await _api.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final item in _items) {
          item.read = true;
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    if (_error && _items.isEmpty) {
      children.add(_message(widget.errorText));
    } else if (!_loading && _items.isEmpty) {
      children.add(_message(widget.emptyText));
    }

    for (final item in _items) {
      children.add(ListTile(
        leading: Icon(
          item.read ? Icons.notifications_none : Icons.notifications_active,
          color: item.read ? theme.disabledColor : theme.colorScheme.primary,
        ),
        title: Text(
          item.title,
          style: TextStyle(fontWeight: item.read ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text(
          item.createdAt == null ? item.body : '${item.body}\n${_formatDate(item.createdAt!)}',
        ),
        isThreeLine: item.createdAt != null,
        onTap: () => _open(item),
      ));
    }

    if (_loading) {
      children.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (_page < _lastPage) {
      // โหลดหน้าถัดไปเมื่อเลื่อนมาถึงท้ายรายการ
      children.add(Builder(builder: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
        return const SizedBox(height: 48);
      }));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: widget.readAllTooltip,
            onPressed: _items.any((i) => !i.read) ? _readAll : null,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: children),
      ),
    );
  }

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Center(child: Text(text, textAlign: TextAlign.center)),
      );

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
