import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sticampuscentralguide/utils/notification_service.dart';

// Theme colors
const Color _navyBlue = Color(0xFF123CBE);
const Color _gold = Color(0xFFFFB206);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : Colors.white,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: _navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _navyBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _navyBlue,
                        ),
                      ),
                      Text(
                        'Manage your campus app',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _AdminActionCard(
                icon: Icons.notifications_active,
                title: 'Send Notification',
                subtitle: 'Create and send announcements to users',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationSenderScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AdminActionCard(
                icon: Icons.event,
                title: 'Manage Events',
                subtitle: 'Create and manage upcoming events',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EventManagerScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AdminActionCard(
                icon: Icons.schedule_send,
                title: 'Schedule Notifier',
                subtitle: 'Trigger class notifications immediately',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScheduleNotifierScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
  }
}

/// Card widget for admin action buttons
class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _navyBlue.withOpacity(isDark ? 0.3 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navyBlue.withOpacity(0.3)),
                ),
                child: Icon(icon, color: _navyBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _navyBlue,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right, color: _gold, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separate screen for sending notifications
class NotificationSenderScreen extends StatefulWidget {
  const NotificationSenderScreen({super.key});

  @override
  State<NotificationSenderScreen> createState() => _NotificationSenderScreenState();
}

class _NotificationSenderScreenState extends State<NotificationSenderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _topicController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _fromController.dispose();
    _topicController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('notifications_outbox').add({
        'from': _fromController.text.trim(),
        'topic': _topicController.text.trim(),
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': uid,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification sent successfully!'),
          backgroundColor: _navyBlue,
        ),
      );
      _fromController.clear();
      _topicController.clear();
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String docId, String message) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text(
          'Are you sure you want to delete this notification?\n\n"${message.length > 100 ? '${message.substring(0, 100)}...' : message}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications_outbox')
            .doc(docId)
            .delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, {bool multiline = false}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: multiline
          ? Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Icon(icon, color: _navyBlue),
            )
          : Icon(icon, color: _navyBlue),
      alignLabelWithHint: multiline,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navyBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : Colors.white,
      appBar: AppBar(
        title: const Text('Send Notification'),
        backgroundColor: _navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notification form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _navyBlue.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _navyBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.info_outline, color: _gold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This notification will be displayed in the announcement bar and notification center.',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _fromController,
                      decoration: _buildInputDecoration('From', 'e.g., Campus Admin, IT Department', Icons.person_outline),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _topicController,
                      decoration: _buildInputDecoration('Topic', 'e.g., MAWD302, all, Important', Icons.topic_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: _buildInputDecoration('Message', 'Enter your announcement message...', Icons.message_outlined, multiline: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendNotification,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Sending...' : 'Send Notification'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Sent Notifications section
              Row(
                children: [
                  Icon(Icons.history, color: _navyBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Sent Notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHighest : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navyBlue.withOpacity(0.2)),
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications_outbox')
                      .orderBy('createdAt', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: _navyBlue));
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: _navyBlue.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications sent yet',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: _navyBlue.withOpacity(0.1)),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final d = doc.data();
                        final ts = d['createdAt'];
                        String timeStr = '';
                        if (ts is Timestamp) {
                          final dt = ts.toDate();
                          timeStr = '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _navyBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.campaign, color: _navyBlue, size: 20),
                          ),
                          title: Text(
                            d['message'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'From: ${d['from'] ?? ''}  •  Topic: ${d['topic'] ?? ''}\n$timeStr',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            tooltip: 'Delete notification',
                            onPressed: () => _confirmDelete(context, doc.id, d['message'] ?? ''),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Screen for managing events
class EventManagerScreen extends StatefulWidget {
  const EventManagerScreen({super.key});

  @override
  State<EventManagerScreen> createState() => _EventManagerScreenState();
}

class _EventManagerScreenState extends State<EventManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customTimeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isMultiDay = false;
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isCustomTime = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _customTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({bool isEndDate = false}) async {
    final initial = isEndDate ? _endDate : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isEndDate ? _selectedDate : DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _navyBlue,
              secondary: _gold,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isEndDate) {
          _endDate = picked;
        } else {
          _selectedDate = picked;
          // If end date is before start date, bump it
          if (_endDate.isBefore(_selectedDate)) {
            _endDate = _selectedDate;
          }
        }
      });
    }
  }

  Future<void> _selectTime({required bool isStartTime}) async {
    final initial = isStartTime ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _navyBlue,
              secondary: _gold,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String timeDisplay;
      final eventData = <String, dynamic>{
        'title': _nameController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': uid,
        'isCustomTime': _isCustomTime,
      };

      if (_isCustomTime) {
        timeDisplay = _customTimeController.text.trim();
        eventData['time'] = timeDisplay;
      } else {
        final startTimeStr = _formatTimeOfDay(_startTime);
        final endTimeStr = _formatTimeOfDay(_endTime);
        eventData['startTime'] = startTimeStr;
        eventData['endTime'] = endTimeStr;
        timeDisplay = '$startTimeStr – $endTimeStr';
        eventData['time'] = timeDisplay;
      }

      // Only store endDate if multi-day AND dates actually differ
      final sameDay = _selectedDate.year == _endDate.year &&
          _selectedDate.month == _endDate.month &&
          _selectedDate.day == _endDate.day;
      if (_isMultiDay && !sameDay) {
        eventData['endDate'] = Timestamp.fromDate(_endDate);
      }
      await FirebaseFirestore.instance.collection('events').add(eventData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Event created successfully!'),
          backgroundColor: _navyBlue,
        ),
      );
      _nameController.clear();
      _locationController.clear();
      _descriptionController.clear();
      _customTimeController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _endDate = DateTime.now();
        _isMultiDay = false;
        _isCustomTime = false;
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 17, minute: 0);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create event: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteEvent(BuildContext context, String docId, String title) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete this event?\n\n"$title"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(docId)
            .delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, {bool multiline = false}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: multiline
          ? Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(icon, color: _navyBlue),
            )
          : Icon(icon, color: _navyBlue),
      alignLabelWithHint: multiline,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navyBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : Colors.white,
      appBar: AppBar(
        title: const Text('Manage Events'),
        backgroundColor: _navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _navyBlue.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _navyBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.info_outline, color: _gold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Create events that will appear in the Upcoming Events section on the Hub page.',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Event Name', 'e.g., Tech Conference, Club Meeting', Icons.event),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Date picker
                    InkWell(
                      onTap: () => _selectDate(),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _isMultiDay ? 'Start Date' : 'Date',
                          prefixIcon: Icon(Icons.calendar_today, color: _navyBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDate(_selectedDate)),
                            Icon(Icons.arrow_drop_down, color: _navyBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Multi-day checkbox
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _isMultiDay,
                            activeColor: _navyBlue,
                            onChanged: (v) => setState(() {
                              _isMultiDay = v ?? false;
                              if (_isMultiDay && _endDate.isBefore(_selectedDate)) {
                                _endDate = _selectedDate.add(const Duration(days: 1));
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Multi-day event',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    // End date picker (only when multi-day)
                    if (_isMultiDay) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _selectDate(isEndDate: true),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            prefixIcon: Icon(Icons.event, color: _navyBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDate(_endDate)),
                              Icon(Icons.arrow_drop_down, color: _navyBlue),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Custom time checkbox
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _isCustomTime,
                            activeColor: _navyBlue,
                            onChanged: (v) => setState(() => _isCustomTime = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Custom time (e.g. TBA, All Day)',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Time input: pickers or free text
                    if (_isCustomTime)
                      TextFormField(
                        controller: _customTimeController,
                        decoration: _buildInputDecoration('Time', 'e.g., TBA, All Day, Morning', Icons.access_time),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(isStartTime: true),
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Time',
                                  prefixIcon: Icon(Icons.access_time, color: _navyBlue, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                                  ),
                                ),
                                child: Text(_formatTimeOfDay(_startTime)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('–', style: TextStyle(fontSize: 18, color: cs.onSurface)),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(isStartTime: false),
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Time',
                                  prefixIcon: Icon(Icons.access_time, color: _navyBlue, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                                  ),
                                ),
                                child: Text(_formatTimeOfDay(_endTime)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: _buildInputDecoration('Location', 'e.g., Room C301, Main Auditorium', Icons.location_on_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: _buildInputDecoration('Description', 'Enter event description...', Icons.description_outlined, multiline: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _saveEvent,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add),
                      label: Text(_saving ? 'Saving...' : 'Create Event'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Existing Events section
              Row(
                children: [
                  Icon(Icons.event_note, color: _navyBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Existing Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHighest : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navyBlue.withOpacity(0.2)),
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .orderBy('date', descending: false)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Failed to load events.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: _navyBlue));
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 48,
                              color: _navyBlue.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No events created yet',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: _navyBlue.withOpacity(0.1)),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final d = doc.data();
                        final ts = d['date'];
                        String dateStr = '';
                        if (ts is Timestamp) {
                          dateStr = _formatDate(ts.toDate());
                        }
                        final endTs = d['endDate'];
                        if (endTs is Timestamp) {
                          dateStr = '$dateStr – ${_formatDate(endTs.toDate())}';
                        }
                        final timeStr = d['time'] as String? ?? '';
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.event, color: _gold, size: 20),
                          ),
                          title: Text(
                            d['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$dateStr  •  $timeStr\n📍 ${d['location'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: _navyBlue),
                                tooltip: 'Edit event',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EventEditScreen(
                                        docId: doc.id,
                                        data: d,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: cs.error),
                                tooltip: 'Delete event',
                                onPressed: () => _confirmDeleteEvent(context, doc.id, d['title'] ?? ''),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Screen for editing an existing event.
class EventEditScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EventEditScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _customTimeController;
  late DateTime _selectedDate;
  late DateTime _endDate;
  late bool _isMultiDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isCustomTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameController = TextEditingController(text: d['title'] as String? ?? '');
    _locationController = TextEditingController(text: d['location'] as String? ?? '');
    _descriptionController = TextEditingController(text: d['description'] as String? ?? '');

    // Date
    final ts = d['date'];
    if (ts is Timestamp) {
      _selectedDate = ts.toDate();
    } else {
      _selectedDate = DateTime.now();
    }

    // End date
    final endTs = d['endDate'];
    if (endTs is Timestamp) {
      _endDate = endTs.toDate();
      _isMultiDay = true;
    } else {
      _endDate = _selectedDate;
      _isMultiDay = false;
    }

    // Time
    _isCustomTime = d['isCustomTime'] == true;
    _customTimeController = TextEditingController(
      text: _isCustomTime ? (d['time'] as String? ?? '') : '',
    );

    _startTime = _parseTimeOfDay(d['startTime'] as String?) ??
        const TimeOfDay(hour: 8, minute: 0);
    _endTime = _parseTimeOfDay(d['endTime'] as String?) ??
        const TimeOfDay(hour: 17, minute: 0);
  }

  TimeOfDay? _parseTimeOfDay(String? s) {
    if (s == null || s.isEmpty) return null;
    // Expect "8:00 AM" or "12:30 PM" format
    final re = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
    final m = re.firstMatch(s);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final period = m.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _customTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({bool isEndDate = false}) async {
    final initial = isEndDate ? _endDate : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isEndDate
          ? _selectedDate
          : DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _navyBlue,
              secondary: _gold,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isEndDate) {
          _endDate = picked;
        } else {
          _selectedDate = picked;
          if (_endDate.isBefore(_selectedDate)) {
            _endDate = _selectedDate;
          }
        }
      });
    }
  }

  Future<void> _selectTime({required bool isStartTime}) async {
    final initial = isStartTime ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _navyBlue,
              secondary: _gold,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  InputDecoration _buildInputDecoration(
      String label, String hint, IconData icon,
      {bool multiline = false}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: multiline
          ? Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(icon, color: _navyBlue),
            )
          : Icon(icon, color: _navyBlue),
      alignLabelWithHint: multiline,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navyBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
      ),
    );
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final eventData = <String, dynamic>{
        'title': _nameController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'isCustomTime': _isCustomTime,
      };

      if (_isCustomTime) {
        eventData['time'] = _customTimeController.text.trim();
        // Clear structured time fields
        eventData['startTime'] = FieldValue.delete();
        eventData['endTime'] = FieldValue.delete();
      } else {
        final startTimeStr = _formatTimeOfDay(_startTime);
        final endTimeStr = _formatTimeOfDay(_endTime);
        eventData['startTime'] = startTimeStr;
        eventData['endTime'] = endTimeStr;
        eventData['time'] = '$startTimeStr – $endTimeStr';
      }

      // Only store endDate if multi-day AND dates actually differ
      final sameDay = _selectedDate.year == _endDate.year &&
          _selectedDate.month == _endDate.month &&
          _selectedDate.day == _endDate.day;
      if (_isMultiDay && !sameDay) {
        eventData['endDate'] = Timestamp.fromDate(_endDate);
      } else {
        eventData['endDate'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.docId)
          .update(eventData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Event updated successfully!'),
          backgroundColor: _navyBlue,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update event: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : Colors.white,
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: _navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                    'Event Name', 'e.g., Tech Conference', Icons.event),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Date picker
              InkWell(
                onTap: () => _selectDate(),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _isMultiDay ? 'Start Date' : 'Date',
                    prefixIcon: Icon(Icons.calendar_today, color: _navyBlue),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: cs.outline.withOpacity(0.5)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(_selectedDate)),
                      Icon(Icons.arrow_drop_down, color: _navyBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Multi-day checkbox
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isMultiDay,
                      activeColor: _navyBlue,
                      onChanged: (v) => setState(() {
                        _isMultiDay = v ?? false;
                        if (_isMultiDay &&
                            _endDate.isBefore(_selectedDate)) {
                          _endDate =
                              _selectedDate.add(const Duration(days: 1));
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Multi-day event',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              if (_isMultiDay) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _selectDate(isEndDate: true),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      prefixIcon: Icon(Icons.event, color: _navyBlue),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: cs.outline.withOpacity(0.5)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDate(_endDate)),
                        Icon(Icons.arrow_drop_down, color: _navyBlue),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Custom time checkbox
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isCustomTime,
                      activeColor: _navyBlue,
                      onChanged: (v) =>
                          setState(() => _isCustomTime = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Custom time (e.g. TBA, All Day)',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Time input
              if (_isCustomTime)
                TextFormField(
                  controller: _customTimeController,
                  decoration: _buildInputDecoration(
                      'Time', 'e.g., TBA, All Day, Morning', Icons.access_time),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(isStartTime: true),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Time',
                            prefixIcon: Icon(Icons.access_time,
                                color: _navyBlue, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: cs.outline.withOpacity(0.5)),
                            ),
                          ),
                          child: Text(_formatTimeOfDay(_startTime)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–',
                          style: TextStyle(
                              fontSize: 18, color: cs.onSurface)),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(isStartTime: false),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Time',
                            prefixIcon: Icon(Icons.access_time,
                                color: _navyBlue, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: cs.outline.withOpacity(0.5)),
                            ),
                          ),
                          child: Text(_formatTimeOfDay(_endTime)),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: _buildInputDecoration('Location',
                    'e.g., Room C301, Main Auditorium', Icons.location_on_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: _buildInputDecoration(
                    'Description',
                    'Enter event description...',
                    Icons.description_outlined,
                    multiline: true),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _updateEvent,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                style: FilledButton.styleFrom(
                  backgroundColor: _navyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen for triggering class schedule notifications immediately
class ScheduleNotifierScreen extends StatefulWidget {
  const ScheduleNotifierScreen({super.key});

  @override
  State<ScheduleNotifierScreen> createState() => _ScheduleNotifierScreenState();
}

class _ScheduleNotifierScreenState extends State<ScheduleNotifierScreen> {
  bool _sending = false;
  List<Map<String, dynamic>> _todayClasses = [];
  bool _loadingClasses = true;
  
  // Custom notification form
  final _customFormKey = GlobalKey<FormState>();
  final _customTitleController = TextEditingController();
  final _customBodyController = TextEditingController();
  bool _sendingCustom = false;

  @override
  void initState() {
    super.initState();
    _loadTodayClasses();
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _customBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayClasses() async {
    setState(() => _loadingClasses = true);
    try {
      final classes = await NotificationService().getTodayClasses();
      if (mounted) setState(() => _todayClasses = classes);
    } catch (e) {
      debugPrint('Failed to load classes: $e');
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  Future<void> _pushNotificationToFirebase(Map<String, dynamic> classItem) async {
    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final String className = classItem['name'] as String;
      final String room = classItem['room'] as String;
      final String time = classItem['time'] as String;

      await FirebaseFirestore.instance.collection('class_notifications').add({
        'title': 'Class at $room! 📚',
        'body': '$className starts at $time!',
        'className': className,
        'room': room,
        'time': time,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification pushed for $className!'),
          backgroundColor: _navyBlue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to push: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pushAllNotifications() async {
    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final batch = FirebaseFirestore.instance.batch();
      
      for (final classItem in _todayClasses) {
        final String className = classItem['name'] as String;
        final String room = classItem['room'] as String;
        final String time = classItem['time'] as String;

        final docRef = FirebaseFirestore.instance.collection('class_notifications').doc();
        batch.set(docRef, {
          'title': 'Class at $room! 📚',
          'body': '$className starts at $time!',
          'className': className,
          'room': room,
          'time': time,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': uid,
        });
      }
      
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All class notifications pushed!'),
          backgroundColor: _navyBlue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to push notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pushCustomNotification() async {
    if (!_customFormKey.currentState!.validate()) return;
    setState(() => _sendingCustom = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('class_notifications').add({
        'title': _customTitleController.text.trim(),
        'body': _customBodyController.text.trim(),
        'className': 'Custom',
        'room': '',
        'time': '',
        'isCustom': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Custom notification pushed!'),
          backgroundColor: _navyBlue,
        ),
      );
      _customTitleController.clear();
      _customBodyController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to push: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingCustom = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, {bool multiline = false}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: multiline
          ? Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Icon(icon, color: _navyBlue),
            )
          : Icon(icon, color: _navyBlue),
      alignLabelWithHint: multiline,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navyBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : Colors.white,
      appBar: AppBar(
        title: const Text('Schedule Notifier'),
        backgroundColor: _navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _navyBlue.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navyBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.cloud_upload, color: _gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Push class notifications to Firebase. Users will receive them when they open the app or check notifications.',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Today's Classes section
              Row(
                children: [
                  Icon(Icons.class_, color: _navyBlue),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Classes",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (_loadingClasses)
                Center(child: CircularProgressIndicator(color: _navyBlue))
              else if (_todayClasses.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 48, color: _navyBlue.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No classes scheduled for today',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...[ 
                  // Individual class cards
                  ..._todayClasses.map((classItem) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _navyBlue.withOpacity(isDark ? 0.3 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _navyBlue.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.class_, color: _navyBlue),
                        ),
                        title: Text(
                          classItem['name'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.w600, color: _navyBlue),
                        ),
                        subtitle: Text(
                          '${classItem['time'] ?? ''} • Room ${classItem['room'] ?? ''}',
                        ),
                        trailing: IconButton(
                          onPressed: _sending ? null : () => _pushNotificationToFirebase(classItem),
                          icon: _sending 
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _navyBlue),
                              )
                            : Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _gold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.cloud_upload, color: _gold, size: 20),
                              ),
                          tooltip: 'Push to Firebase',
                        ),
                      ),
                    ),
                  )),
                  const SizedBox(height: 8),
                  // Send all button
                  FilledButton.icon(
                    onPressed: _sending ? null : _pushAllNotifications,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_sending ? 'Pushing...' : 'Push All to Firebase'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              
              const SizedBox(height: 24),
              Divider(color: _navyBlue.withOpacity(0.2)),
              const SizedBox(height: 16),

              // Custom notification form
              Row(
                children: [
                  Icon(Icons.campaign, color: _navyBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Custom Notification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Form(
                key: _customFormKey,
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _customTitleController,
                          decoration: _buildInputDecoration('Title', 'e.g., Class Cancelled! 📢', Icons.title),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customBodyController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _buildInputDecoration('Message', 'Enter notification message...', Icons.message_outlined, multiline: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _sendingCustom ? null : _pushCustomNotification,
                          icon: _sendingCustom
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send),
                          label: Text(_sendingCustom ? 'Sending...' : 'Push Custom Notification'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Divider(color: _navyBlue.withOpacity(0.2)),
              const SizedBox(height: 16),

              // Notification history section
              Row(
                children: [
                  Icon(Icons.history, color: _navyBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Notification History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHighest : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navyBlue.withOpacity(0.2)),
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('class_notifications')
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Failed to load.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error, fontSize: 12),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: _navyBlue));
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, size: 48, color: _navyBlue.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No class notifications sent yet',
                              style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: _navyBlue.withOpacity(0.1)),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final d = doc.data();
                        final ts = d['createdAt'];
                        final isCustom = d['isCustom'] == true;
                        final title = isCustom ? d['title'] : (d['className'] ?? d['title'] ?? '');
                        String dateStr = '';
                        if (ts is Timestamp) {
                          final dt = ts.toDate();
                          dateStr = '${dt.month}/${dt.day} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        final subtitle = isCustom 
                            ? '${d['body'] ?? ''}'
                            : '${d['time'] ?? ''} • Room ${d['room'] ?? ''}';
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCustom ? _gold.withOpacity(0.2) : _navyBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCustom ? Icons.campaign : Icons.class_,
                              color: isCustom ? _gold : _navyBlue,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            title ?? '',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: _navyBlue),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }
}