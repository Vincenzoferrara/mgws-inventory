import 'package:flutter/material.dart';
import 'caldav_service.dart';
import '../login/gui/login.gui.dart';
import '../l10n/extensions.dart';

class CalDavGui extends StatefulWidget {
  const CalDavGui({super.key});

  @override
  State<CalDavGui> createState() => _CalDavGuiState();
}

class _CalDavGuiState extends State<CalDavGui>
    with SingleTickerProviderStateMixin {
  final CalDavService _service = CalDavService();
  late TabController _tabController;
  List<Map<String, dynamic>> _calendars = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;
  String? _selectedCalendarHref;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    await _service.loadCredentials();
    if (_service.baseUrl == null ||
        _service.username == null ||
        _service.password == null) {
      // Apri login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } else {
      _loadCalendars();
    }
  }

  Future<void> _loadCalendars() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _calendars = await _service.getCalendars();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTasks(String href) async {
    setState(() {
      _isLoading = true;
    });
    try {
      _tasks = await _service.getTasks(href);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEvents(String href) async {
    setState(() {
      _isLoading = true;
    });
    try {
      _events = await _service.getEvents(href);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.caldavTitolo),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.calendar_today),
              text: context.l10n.caldavTabCalendar,
            ),
            Tab(
              icon: Icon(Icons.contacts),
              text: context.l10n.caldavTabContacts,
            ),
            Tab(icon: Icon(Icons.checklist), text: context.l10n.caldavTabTodo),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarioTab(),
                _buildRubricaTab(),
                _buildTodoTab(),
              ],
            ),
    );
  }

  Widget _buildCalendarioTab() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            context.l10n.caldavCalendars,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._calendars.map(
          (cal) => ListTile(
            title: Text(cal['displayName'] ?? context.l10n.caldavUnnamed),
            subtitle: Text(cal['href']),
            onTap: () {
              setState(() {
                _selectedCalendarHref = cal['href'];
              });
              _loadEvents(cal['href']);
            },
          ),
        ),
        if (_selectedCalendarHref != null) ...[
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              context.l10n.caldavEventsPending,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ..._events.map(
            (event) => ListTile(
              title: Text(event['href'] ?? context.l10n.caldavNoHref),
              subtitle: Text(event['etag'] ?? ''),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRubricaTab() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            context.l10n.caldavContactsPending,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // Placeholder
        ListTile(title: Text(context.l10n.caldavCarddavInSviluppo)),
      ],
    );
  }

  Widget _buildTodoTab() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            context.l10n.caldavTasks,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._calendars.map(
          (cal) => ListTile(
            title: Text(cal['displayName'] ?? context.l10n.caldavUnnamed),
            subtitle: Text(cal['href']),
            onTap: () {
              setState(() {
                _selectedCalendarHref = cal['href'];
              });
              _loadTasks(cal['href']);
            },
          ),
        ),
        if (_selectedCalendarHref != null) ...[
          ..._tasks.map(
            (task) => ListTile(
              title: Text(task['href'] ?? context.l10n.caldavNoHref),
              subtitle: Text(task['etag'] ?? ''),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
