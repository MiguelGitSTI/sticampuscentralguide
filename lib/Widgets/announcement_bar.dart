import 'package:flutter/scheduler.dart' show Ticker;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticampuscentralguide/theme/theme_provider.dart';

/// Model representing a single announcement item.
class AnnouncementItem {
	final int id;
	final String title;
	final String message;
	final String type;

	const AnnouncementItem({
		required this.id,
		required this.title,
		required this.message,
		required this.type,
	});

	factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
		return AnnouncementItem(
			id: json['id'] as int,
			title: json['title'] as String,
			message: json['message'] as String,
			type: json['type'] as String? ?? 'info',
		);
	}
}

/// A slim announcement bar that horizontally scrolls announcement items.
///
/// This widget is designed to live just below the profile + top buttons row
/// on the home screen.
class AnnouncementBar extends StatefulWidget {
	const AnnouncementBar({super.key});

	@override
	State<AnnouncementBar> createState() => _AnnouncementBarState();
}

class _AnnouncementBarState extends State<AnnouncementBar>
		with SingleTickerProviderStateMixin {
	late final Future<String> _sectionFuture;
	final ScrollController _scrollController = ScrollController();
	// Smooth marquee ticker
	late final Ticker _ticker;
	Duration? _lastTick;
	// px per second scroll speed
	static const double _speed = 40.0;

	// Items and measurement for seamless loop
	List<AnnouncementItem> _items = const <AnnouncementItem>[];
	final GlobalKey _sequenceKey = GlobalKey(); // Key for measuring single sequence width
	double _contentWidth = 0.0; // width of one sequence of items (including spacer)
	bool _hasMeasured = false; // Track if we've measured the content

  @override
  void initState() {
    super.initState();
		_sectionFuture = _loadUserSection();
    _ticker = Ticker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

	Future<String> _loadUserSection() async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getString('user_section') ?? 'MAWD302';
	}

	Color _chipColorForType(BuildContext context, String type) {
		// Background color of individual chips is transparent so they blend
		// into the solid navy bar.
		return Colors.transparent;
	}

	Color _chipBorderColorForType(BuildContext context, String type) {
		// No visible border for a cleaner ticker look.
		return Colors.transparent;
	}


	void _onTick(Duration elapsed) {
		if (!_scrollController.hasClients || _items.isEmpty) {
			_lastTick = elapsed;
			return;
		}

		final dt = _lastTick == null
				? 0.0
				: (elapsed - _lastTick!).inMicroseconds / 1e6;
		_lastTick = elapsed;

		if (dt <= 0) return;

		// Advance offset
		final dx = _speed * dt;
		final controller = _scrollController;
		double next = controller.offset + dx;

		// Wrap seamlessly when we pass one full sequence width
		if (_contentWidth > 0 && next >= _contentWidth) {
			next = next - _contentWidth;
		}
		controller.jumpTo(next);
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final isDark = theme.brightness == Brightness.dark;

		return FutureBuilder<String>(
			future: _sectionFuture,
			builder: (context, sectionSnap) {
				if (sectionSnap.connectionState == ConnectionState.waiting) {
					// Keep the bar height stable but show a subtle shimmer/placeholder.
					return _buildContainer(
						context,
						child: Align(
							alignment: Alignment.centerLeft,
							child: Container(
								width: 120,
								height: 18,
								decoration: BoxDecoration(
									color: Colors.white.withOpacity(isDark ? 0.25 : 0.4),
									borderRadius: BorderRadius.circular(999),
								),
							),
						),
					);
				}

				final query = FirebaseFirestore.instance
					.collection('notifications_outbox')
					.limit(50);

				return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
					stream: query.snapshots(),
					builder: (context, snap) {
						if (snap.hasError) {
							return _buildContainer(
								context,
								child: Align(
									alignment: Alignment.centerLeft,
									child: Text(
										'Announcements unavailable',
										style: theme.textTheme.bodySmall?.copyWith(
											color: Colors.white70,
										),
									),
								),
							);
						}

						if (!snap.hasData) {
							return _buildContainer(
								context,
								child: Align(
									alignment: Alignment.centerLeft,
									child: Container(
										width: 120,
										height: 18,
										decoration: BoxDecoration(
											color: Colors.white.withOpacity(isDark ? 0.25 : 0.4),
											borderRadius: BorderRadius.circular(999),
										),
									),
								),
							);
						}

						final docs = snap.data!.docs;
						if (docs.isEmpty) {
							return _buildContainer(
								context,
								child: Align(
									alignment: Alignment.centerLeft,
									child: Text(
										'No announcements at this time',
										style: theme.textTheme.bodySmall?.copyWith(
											color: Colors.white70,
										),
									),
								),
							);
						}

						// Map Firestore docs, sort by createdAt desc, and reset items
						final enriched = docs.map((doc) {
							final d = doc.data();
							final from = (d['from'] as String?)?.trim();
							final topic = (d['topic'] as String?)?.trim();
							final message = (d['message'] as String?) ?? '';
							final ts = d['createdAt'];
							DateTime when;
							if (ts is Timestamp) {
								when = ts.toDate();
							} else if (ts is DateTime) {
								when = ts;
							} else {
								when = DateTime.now();
							}
							return (
								item: AnnouncementItem(
									id: 0,
									title: (topic == null || topic.isEmpty)
											? ((from == null || from.isEmpty) ? 'Announcement' : from)
											: topic,
									message: message,
									type: 'info',
								),
								createdAt: when,
							);
						}).toList(growable: false)
							..sort((a, b) => b.createdAt.compareTo(a.createdAt));

						// Re-assign stable ids after sorting
						_items = List.generate(enriched.length, (i) {
							final it = enriched[i].item;
							return AnnouncementItem(
								id: i,
								title: it.title,
								message: it.message,
								type: it.type,
							);
						});

						// Ensure ticker is running
						if (!_ticker.isActive) _ticker.start();

						// Reset measurement when items change
						_hasMeasured = false;

						// Build two consecutive sequences to allow seamless wrap
						return _buildContainer(
							context,
							child: LayoutBuilder(
								builder: (context, constraints) {
									// Build the first sequence with a key to measure it
									final firstSequence = Row(
										key: _sequenceKey,
										mainAxisSize: MainAxisSize.min,
										children: [
											..._buildChipWidgets(context, theme, _items),
											const SizedBox(width: 32), // Gap between sequences
										],
									);
									
									// Build the second sequence (duplicate for seamless loop)
									final secondSequence = Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											..._buildChipWidgets(context, theme, _items),
											const SizedBox(width: 32), // Gap between sequences
										],
									);

									// Measure after frame
									WidgetsBinding.instance.addPostFrameCallback((_) {
										if (!_hasMeasured) {
											final ctx = _sequenceKey.currentContext;
											if (ctx != null) {
												final render = ctx.findRenderObject();
												if (render is RenderBox && render.hasSize) {
													final width = render.size.width;
													if (width > 0 && _contentWidth != width) {
														_contentWidth = width;
														_hasMeasured = true;
													}
												}
											}
										}
									});

									return SingleChildScrollView(
										controller: _scrollController,
										scrollDirection: Axis.horizontal,
										physics: const NeverScrollableScrollPhysics(),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: [firstSequence, secondSequence],
										),
									);
								},
							),
						);
					},
				);
			},
		);
	}

	// Build a list of chip widgets from items
	List<Widget> _buildChipWidgets(BuildContext context, ThemeData theme, List<AnnouncementItem> items) {
		return List.generate(items.length, (index) {
			final item = items[index];
			return Container(
				margin: const EdgeInsets.only(right: 8),
				padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
				decoration: BoxDecoration(
					color: _chipColorForType(context, item.type),
					borderRadius: BorderRadius.circular(999),
					border: Border.all(color: _chipBorderColorForType(context, item.type)),
				),
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Icon(Icons.campaign_rounded, size: 16, color: Colors.white),
						const SizedBox(width: 6),
						Text(
							'${item.title}: ${item.message}',
							softWrap: false,
							style: theme.textTheme.bodySmall?.copyWith(
								color: Colors.white,
								fontWeight: FontWeight.w600,
							),
						),
					],
				),
			);
		});
	}

	Widget _buildContainer(BuildContext context, {required Widget child}) {
		// Use the app's branded navy blue from ThemeProvider for the bar color.
		const navy = ThemeProvider.navyBlue;
		return Container(
			height: 30,
			margin: const EdgeInsets.only(top: 4, bottom: 2),
			padding: const EdgeInsets.symmetric(horizontal: 8),
			decoration: BoxDecoration(
				color: navy,
				borderRadius: BorderRadius.circular(0),
			),
			child: child,
		);
	}
}

