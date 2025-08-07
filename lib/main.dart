import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(ChoreTrackerApp());
}

// ---- Shared app data ----
const List<String> kUsers = ['Maxwell', 'Elijah'];
final Map<String, String> kUserAvatars = {
  'Maxwell': 'assets/images/maxwell_avatar.jpg',
  'Elijah': 'assets/images/elijah_avatar.jpg',
};

const Map<String, int> defaultTasks = {
  'Doing a chore without being told': 3,
  'Doing a chore on first ask (no excuses)': 4,
  'Helping a sibling or parent': 2,
  'Practice something for 10 minutes': 5,
  'Bonus task (vacuum, dishes, etc.)': 6,
  'Read a book for 15+ minutes': 4,
};

const Map<String, int> defaultRewards = {
  'Extra screen time (15 min)': 10,
  'Snack of choice': 15,
  'Pick the game/movie': 20,
  '\$1 Cash': 25,
  '\$2 Cash': 50,
};

// ⬇️ INSERTED: ParentPrefs class
class ParentPrefs {
  static const pinKey = 'parent_pin';
  static const requirePinForAdminKey = 'require_pin_for_admin';

  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(pinKey) ?? '1234';
  }

  static Future<void> setPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pinKey, newPin);
  }

  static Future<bool> getRequirePinForAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(requirePinForAdminKey) ?? true;
  }

  static Future<void> setRequirePinForAdmin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(requirePinForAdminKey, value);
  }

  static Future<bool> verifyPin(String input) async {
    final pin = await getPin();
    return input == pin;
  }
}

// ✅ Already included class; make sure it's still here
class DynamicData {
  static Future<Map<String, int>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('tasks_map');
    if (jsonStr != null) {
      return Map<String, int>.from(
        jsonDecode(jsonStr).map((k, v) => MapEntry(k as String, v as int)),
      );
    }
    return Map<String,int>.from(defaultTasks);
  }

  static Future<Map<String, int>> loadRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('rewards_map');
    if (jsonStr != null) {
      return Map<String, int>.from(
        jsonDecode(jsonStr).map((k, v) => MapEntry(k as String, v as int)),
      );
    }
    return Map<String,int>.from(defaultRewards);
  }

  static Future<void> saveTasks(Map<String,int> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks_map', jsonEncode(tasks));
  }

  static Future<void> saveRewards(Map<String,int> rewards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rewards_map', jsonEncode(rewards));
  }
}

// ✅ Entry point of the app
class ChoreTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Team Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

// ---------------- Login Screen ----------------
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _openParentControls(BuildContext context) async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (_) => const PinEntryDialog(title: 'Enter Parent PIN'),
    );

    if (verified == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParentControlsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Select a User'),
          const SizedBox(height: 10),
          for (final user in kUsers)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage(kUserAvatars[user]!),
              ),
              title: Text(user),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(selectedUser: user),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('Parent Controls'),
            onPressed: () => _openParentControls(context),
          ),
        ],
      ),
    );
  }
}


// ---------------- Parent Controls Screen ----------------
class ParentControlsScreen extends StatefulWidget {
  const ParentControlsScreen({super.key});
  @override
  State<ParentControlsScreen> createState() => _ParentControlsScreenState();
}

class _ParentControlsScreenState extends State<ParentControlsScreen> {
  Map<String, int> _tasks = {};
  Map<String, int> _rewards = {};

  @override
  void initState() {
    super.initState();
    _loadDynamic();
  }

  Future<void> _loadDynamic() async {
    final t = await DynamicData.loadTasks();
    final r = await DynamicData.loadRewards();
    setState(() {
      _tasks = t;
      _rewards = r;
    });
  }

  Future<void> _addChore() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddEntryDialog(title: 'New Chore', hint: 'Points'),
    );
    if (result != null) {
      setState(() {
        _tasks[result['name']] = result['value'];
      });
      await DynamicData.saveTasks(_tasks);
    }
  }

  Future<void> _addReward() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
      const AddEntryDialog(title: 'New Reward', hint: 'Cost (pts)'),
    );
    if (result != null) {
      setState(() {
        _rewards[result['name']] = result['value'];
      });
      await DynamicData.saveRewards(_rewards);
    }
  }

  void _viewProfile(String user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Controls')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Manage Chores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ..._tasks.entries
              .map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value} pts'))),
          ElevatedButton(onPressed: _addChore, child: const Text('Add Chore')),
          const Divider(),
          const Text('Manage Rewards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ..._rewards.entries
              .map((e) => ListTile(title: Text(e.key), trailing: Text('Cost: ${e.value}'))),
          ElevatedButton(
              onPressed: _addReward, child: const Text('Add Reward')),
          const Divider(),
          const Text('View User Profiles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...kUsers.map((u) => ListTile(
            title: Text(u),
            trailing: ElevatedButton(
                onPressed: () => _viewProfile(u),
                child: const Text('View')),
          )),
        ],
      ),
    );
  }
}

// ---------------- User Profile Screen ----------------
class UserProfileScreen extends StatelessWidget {
  final String user;
  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile: $user')),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prefs = snap.data!;
          final pts = prefs.getInt('points_$user') ?? 0;
          final statusJson = prefs.getString('choreStatus_$user');
          final historyJson = prefs.getString('history_$user');
          final tasksMap = prefs.getString('tasks_map') != null
              ? Map<String, int>.from(
              jsonDecode(prefs.getString('tasks_map')!)
                  .map((k, v) => MapEntry(k as String, v as int)))
              : defaultTasks;
          final statuses = statusJson != null
              ? Map<String, bool>.from(
              jsonDecode(statusJson).map((k, v) => MapEntry(k as String, v as bool)))
              : {for (var k in tasksMap.keys) k: false};
          final history =
          historyJson != null ? List<String>.from(jsonDecode(historyJson)) : <String>[];

          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Points: $pts', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            const Text('Chore Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...statuses.entries.map((e) =>
                ListTile(leading: Icon(e.value ? Icons.check : Icons.close), title: Text(e.key))),
            const SizedBox(height: 16),
            const Text('History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (history.isEmpty)
              const Text('No history yet.')
            else
              ...history.map((h) => ListTile(title: Text(h))),
          ]);
        },
      ),
    );
  }
}

// ---------------- Dialog for PIN ----------------
class PinEntryDialog extends StatefulWidget {
  final String title;
  const PinEntryDialog({super.key, required this.title});
  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    final ok = await ParentPrefs.verifyPin(_ctrl.text);
    setState(() => _busy = false);
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Enter PIN'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: _busy ? null : _check,
            child: _busy
                ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator())
                : const Text('OK')),
      ],
    );
  }
}

// ---------------- Dialog to Add Chore/Reward ----------------
class AddEntryDialog extends StatefulWidget {
  final String title;
  final String hint;
  const AddEntryDialog({super.key, required this.title, required this.hint});
  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  final _name = TextEditingController();
  final _value = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(
            controller: _value,
            decoration: InputDecoration(labelText: widget.hint),
            keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () {
              final name = _name.text.trim();
              final value = int.tryParse(_value.text) ?? 0;
              if (name.isNotEmpty && value > 0) {
                Navigator.of(context).pop({'name': name, 'value': value});
              }
            },
            child: const Text('Add'))
      ],
    );
  }
}

// ---------------- Home Screen ----------------
class HomeScreen extends StatefulWidget {
  final String selectedUser;
  const HomeScreen({super.key, required this.selectedUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<String> users = kUsers;
  final Map<String, String> userAvatars = kUserAvatars;

  late String selectedUser;

  Map<String, int> userPoints = {};
  Map<String, Map<String, bool>> choreStatus = {};
  Map<String, List<String>> userHistory = {};

  late TabController _tabController;

  final Map<String, int> tasks = const {
    'Doing a chore without being told': 3,
    'Doing a chore on first ask (no excuses)': 4,
    'Helping a sibling or parent': 2,
    'Practice something for 10 minutes': 5,
    'Bonus task (vacuum, dishes, etc.)': 6,
    'Read a book for 15+ minutes': 4,
    'Pick weeds or help outside': 3,
    'Pick up toys without being asked': 3,
    'Pick up toys when asked': 2,
    'Clean room': 3,
    'Pick up clothes': 2,
    'Put clean clothes away': 2,
    'Finish homework without reminders': 5,
    'Feed the dog': 2,
    'Fill water bowl': 2,
    'Brush teeth': 3,
    'Take shower': 2,
    'Eat dinner (no complaints)': 2,
    '5 push-ups': 1,
    '10 push-ups': 2,
    '20 push-ups': 5,
    '30+ push-ups': 10,
    'Plank 30 secs': 2,
    '3 challenges in a row': 5,
    'Beat last week’s score': 5,
  };

  final Map<String, int> deductions = const {
    'Refusing task after 2 reminders': -2,
    'Yelling / name-calling': -3,
    'Lying or blaming': -2,
    'Not following routine': -3,
    'Tantrum / outburst': -1,
  };

  final Map<String, int> rewards = const {
    'Extra screen time (15 min)': 10,
    'Snack of choice': 15,
    'Pick the game/movie': 20,
    '\$1 Cash': 25,
    '\$2 Cash': 50,
    '\$5 Cash or dinner pick': 75,
    'Movie night / No chores': 100,
    'Mystery Box (toys/candy)': 150,
    '\$10 Game Money': 200,
    'Full \$60 Game': 500,
  };

  @override
  void initState() {
    super.initState();
    selectedUser = widget.selectedUser;
    _tabController = TabController(length: 3, vsync: this);
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var user in users) {
        userPoints[user] = prefs.getInt('points_$user') ?? 0;

        final jsonStatus = prefs.getString('choreStatus_$user');
        if (jsonStatus != null) {
          final decoded = jsonDecode(jsonStatus) as Map<String, dynamic>;
          choreStatus[user] = decoded.map((k, v) => MapEntry(k, v as bool));
        } else {
          choreStatus[user] = {for (var task in tasks.keys) task: false};
        }

        final jsonHistory = prefs.getString('history_$user');
        if (jsonHistory != null) {
          userHistory[user] = List<String>.from(jsonDecode(jsonHistory));
        } else {
          userHistory[user] = [];
        }
      }
    });
  }

  Future<void> savePoints(String user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('points_$user', userPoints[user] ?? 0);
  }

  Future<void> saveChoreStatus(String user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('choreStatus_$user', jsonEncode(choreStatus[user]));
  }

  Future<void> saveHistory(String user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history_$user', jsonEncode(userHistory[user]));
  }

  void toggleChore(String chore) {
    final currentStatus = choreStatus[selectedUser]?[chore] ?? false;
    setState(() {
      choreStatus[selectedUser]?[chore] = !currentStatus;
      if (!currentStatus) {
        final earned = tasks[chore] ?? 0;
        userPoints[selectedUser] = (userPoints[selectedUser] ?? 0) + earned;
        savePoints(selectedUser);

        final now = DateTime.now();
        final formatted =
            '$selectedUser completed "$chore" on ${now.month}/${now.day}/${now.year} at ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        userHistory[selectedUser]?.insert(0, formatted);
        saveHistory(selectedUser);
      }
      saveChoreStatus(selectedUser);
    });
  }

  void updatePoints(String user, int value) {
    setState(() {
      userPoints[user] = (userPoints[user] ?? 0) + value;
    });
    savePoints(user);
  }

  Future<bool> _maybeVerifyParent() async {
    final require = await ParentPrefs.getRequirePinForAdmin();
    if (!require) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const PinEntryDialog(title: 'Parent PIN Required'),
    );
    return ok == true;
  }

  Future<void> _resetPointsGuarded(String user) async {
    if (await _maybeVerifyParent()) {
      setState(() {
        userPoints[user] = 0;
      });
      await savePoints(user);
      _toast('Points reset for $user.');
    } else {
      _toast('Action cancelled.');
    }
  }

  Future<void> _resetChoresGuarded(String user) async {
    if (await _maybeVerifyParent()) {
      setState(() {
        for (var key in tasks.keys) {
          choreStatus[user]?[key] = false;
        }
      });
      await saveChoreStatus(user);
      _toast('Chores reset for $user.');
    } else {
      _toast('Action cancelled.');
    }
  }

  Future<void> _clearHistoryGuarded(String user) async {
    if (await _maybeVerifyParent()) {
      setState(() {
        userHistory[user] = [];
      });
      await saveHistory(user);
      _toast('History cleared for $user.');
    } else {
      _toast('Action cancelled.');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget buildChoreChecklist() {
    final userChores = choreStatus[selectedUser] ?? {};
    return Column(
      children: tasks.entries.map((entry) {
        return CheckboxListTile(
          title: Row(
            children: [
              const Icon(Icons.star, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.key)),
            ],
          ),
          value: userChores[entry.key] ?? false,
          onChanged: (_) => toggleChore(entry.key),
          subtitle: Text('+${entry.value} pts'),
        );
      }).toList(),
    );
  }

  Widget buildRewardCard(String reward, int cost) {
    final int currentPoints = userPoints[selectedUser] ?? 0;
    return Card(
      child: ListTile(
        leading: Image.asset(
          'assets/images/reward_star.png',
          width: 30,
          height: 30,
        ),
        title: Text(reward),
        trailing: ElevatedButton(
          onPressed: currentPoints >= cost
              ? () {
            updatePoints(selectedUser, -cost);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$reward redeemed for $cost points!')),
            );
          }
              : null,
          child: Text('Redeem ($cost pts)'),
        ),
      ),
    );
  }

  Widget buildDeductionList() {
    return Column(
      children: deductions.entries.map((e) {
        return Card(
          child: ListTile(
            title: Text(e.key),
            trailing: Text(
              '${e.value} pts',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => updatePoints(selectedUser, e.value),
          ),
        );
      }).toList(),
    );
  }

  Widget buildHistoryView() {
    final history = userHistory[selectedUser] ?? [];
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _clearHistoryGuarded(selectedUser),
          icon: const Icon(Icons.delete),
          label: const Text("Clear History"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          const Text("No history yet.")
        else
          ...history.map(
                (e) => ListTile(
              title: Text(e),
              leading: const Icon(Icons.check_circle_outline),
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPoints = userPoints[selectedUser] ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('Chore Tracker: $selectedUser'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chores'),
            Tab(text: 'Rewards'),
            Tab(text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Switch User',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          DropdownButton<String>(
            value: selectedUser,
            dropdownColor: Colors.blue[50],
            underline: Container(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedUser = value);
              }
            },
            items: users.map((user) {
              return DropdownMenuItem(
                value: user,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: AssetImage(userAvatars[user]!),
                    ),
                    const SizedBox(width: 8),
                    Text(user),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Points & Chores',
            onPressed: () async {
              // Guarded by PIN depending on toggle
              await _resetPointsGuarded(selectedUser);
              await _resetChoresGuarded(selectedUser);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Points: $currentPoints',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('✅ Chore Checklist',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                buildChoreChecklist(),
                const SizedBox(height: 10),
                const Text('⚠️ Deductions',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                buildDeductionList(),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Points: $currentPoints',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('🎁 Rewards',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ...rewards.entries
                    .map((e) => buildRewardCard(e.key, e.value))
                    .toList(),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: buildHistoryView(),
          ),
        ],
      ),
    );
  }
}
