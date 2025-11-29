import 'package:flutter/material.dart';
import 'package:sticampuscentralguide/Widgets/event_carousel.dart';
import 'package:sticampuscentralguide/Widgets/class_schedule.dart';
import 'package:sticampuscentralguide/Widgets/todo_list.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Carousel Title (outside of card)
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Event Carousel
              const EventCarousel(),
              const SizedBox(height: 24),
              
              // Class Schedule Title (outside of card)
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Text(
                  'Class Schedule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Class Schedule
              const ClassSchedule(),
              const SizedBox(height: 24),
              
              // Todo Title (outside of card)
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Text(
                  'Todo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Todo List
              const TodoList(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

