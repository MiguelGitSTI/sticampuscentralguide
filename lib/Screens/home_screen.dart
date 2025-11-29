import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sticampuscentralguide/Widgets/carousel_image.dart';
import 'package:sticampuscentralguide/Widgets/announcement_bar.dart';
import 'package:sticampuscentralguide/Widgets/navigation_bar.dart';
import 'package:sticampuscentralguide/Widgets/gradient_buttons.dart';
import 'package:sticampuscentralguide/Widgets/profile_button.dart';
import 'package:sticampuscentralguide/Widgets/buttons.dart';
import 'package:sticampuscentralguide/Screens/settings_screen.dart';
import 'package:sticampuscentralguide/Screens/faq_screen.dart';
import 'package:sticampuscentralguide/Screens/notification_screen.dart';
import 'package:sticampuscentralguide/Screens/map_screen.dart';
import 'package:sticampuscentralguide/Screens/hub_screen.dart';
import 'package:sticampuscentralguide/utils/messaging.dart';
import 'package:sticampuscentralguide/utils/notification_service.dart';

class HomeScreen extends StatefulWidget {
	const HomeScreen({super.key});

	@override
	State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
	int _index = 0;
	int _previousIndex = 0;
	late AnimationController _animationController;
	late Animation<Offset> _slideAnimation;
	late final List<Widget> _tabs;
	final GlobalKey _mapKey = GlobalKey();

	@override
	void initState() {
		super.initState();
		// Ensure device is subscribed to relevant FCM topics.
		MessagingHelper.ensureTopicSubscriptions();
		// Start listening for Firebase class notifications
		NotificationService().startFirebaseNotificationListener();
		_animationController = AnimationController(
			duration: const Duration(milliseconds: 300),
			vsync: this,
		);
		_slideAnimation = Tween<Offset>(
			begin: Offset.zero,
			end: Offset.zero,
		).animate(CurvedAnimation(
			parent: _animationController,
			curve: Curves.easeInOut,
		));

			// Prebuild tabs so they stay alive across index changes
			_tabs = [
				_HomeTab(
					onNavigateToMap: () => _onTabChanged(1),
					onLocateRequest: (String buildingId) {
						// Forward highlight to map then switch tab
						final st = _mapKey.currentState as dynamic;
						try { st?.highlightBuilding(buildingId); } catch (_) {}
						_onTabChanged(1);
					},
				),
				MapScreen(key: _mapKey),
				const HubScreen(),
			];
	}

	@override
	void dispose() {
		_animationController.dispose();
		super.dispose();
	}

	void _onTabChanged(int newIndex) {
		if (newIndex == _index) return;
		
		setState(() {
			_previousIndex = _index;
			_index = newIndex;
			
			// Determine slide direction based on tab order: Home(0) <-> Map(1) <-> Hub(2)
			final bool slideLeft = newIndex > _previousIndex;
			
			_slideAnimation = Tween<Offset>(
				begin: slideLeft ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
				end: Offset.zero,
			).animate(CurvedAnimation(
				parent: _animationController,
				curve: Curves.easeInOut,
			));
			
			_animationController.forward(from: 0.0);
		});
	}

	@override
	Widget build(BuildContext context) {
				return Scaffold(
				// Let the body paint under the floating navbar to avoid a visible stripe
				extendBody: true,
				// Align scaffold background with surface to match the fade and navbar color
					backgroundColor: Theme.of(context).brightness == Brightness.dark
							? Theme.of(context).colorScheme.background
							: Theme.of(context).colorScheme.surface,
			body: AnimatedBuilder(
				animation: _animationController,
				builder: (context, child) {
					return SlideTransition(
						position: _slideAnimation,
							child: IndexedStack(
								index: _index,
								children: _tabs,
							),
					);
				},
			),
			// Floating, rounded bottom navigation
			bottomNavigationBar: BottomNavBarFb2(
				currentIndex: _index,
				onTap: _onTabChanged,
			),
		);
	}
}

class _HomeTab extends StatefulWidget {
	final VoidCallback? onNavigateToMap;
	final ValueChanged<String>? onLocateRequest;
	const _HomeTab({this.onNavigateToMap, this.onLocateRequest});

	@override
	State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
	final GlobalKey<ProfileButtonState> _profileButtonKey = GlobalKey<ProfileButtonState>();
	final GlobalKey<NotificationButtonWithBadgeState> _notificationButtonKey = GlobalKey<NotificationButtonWithBadgeState>();

	@override
	void initState() {
		super.initState();
		// Refresh profile info (in case user just logged in)
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_profileButtonKey.currentState?.loadProfileImage();
		});
		// Schedule class notifications when home tab loads
		_scheduleClassNotifications();
	}

	Future<void> _scheduleClassNotifications() async {
		try {
			await NotificationService().scheduleClassNotifications();
		} catch (e) {
			debugPrint('Failed to schedule class notifications: $e');
		}
	}

	@override
	Widget build(BuildContext context) {
		final isDark = Theme.of(context).brightness == Brightness.dark;
		final media = MediaQuery.of(context);
		final sw = media.size.width / 411.0;
		// Responsive sizing anchored to 1080x2400-class device
		double iconHeight = (220 * sw).clamp(140.0, 240.0);
		double buttonHPad = (100 * sw).clamp(70.0, 120.0);
		double buttonVPad = (10 * sw).clamp(14.0, 20.0);
		double buttonFont = (20 * sw).clamp(18.0, 22.0);

		return Container(
			child: Stack(
				children: [
					if (!isDark)
						Positioned.fill(
							child: IndexedStack(
								index: 0,
								children: [
									Builder(
										builder: (context) {
											const double zoom = 1.65; // really zoomed in
											final int targetWidthPx =
													(media.size.width * media.devicePixelRatio * zoom).round();
											// Cap decode size for memory safety
											final int cappedWidthPx = math.min(targetWidthPx, 4096);
											return Transform.scale(
												scale: zoom,
												alignment: Alignment.topRight,
												child: Image.asset(
													'assets/images/home_background.webp',
													fit: BoxFit.cover,
													alignment: Alignment.topRight,
													cacheWidth: cappedWidthPx,
												),
											);
										},
									),
								],
							),
						),
					// Bottom fade for light mode only
					if (!isDark)
						Positioned.fill(
							child: IgnorePointer(
								ignoring: true,
								child: DecoratedBox(
									decoration: BoxDecoration(
										gradient: LinearGradient(
											begin: Alignment.topCenter,
											end: Alignment.bottomCenter,
											colors: [
												Colors.transparent,
												Theme.of(context).colorScheme.surface.withOpacity(0.06),
												Theme.of(context).colorScheme.surface.withOpacity(0.12),
												Theme.of(context).colorScheme.surface.withOpacity(0.20),
												Theme.of(context).colorScheme.surface.withOpacity(0.45),
												Theme.of(context).colorScheme.surface,
											],
											// Raised and subtle: start higher with gentle ramp to full surface at bottom
											stops: const [0.48, 0.62, 0.74, 0.87, 0.96, 1.0],
										),
									),
								),
							),
						),
					SafeArea(
						top: false, // Extend to status bar
						child: Padding(
							padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									// Add status bar height spacing
									SizedBox(height: MediaQuery.of(context).padding.top),
									// Top navigation bar
									Padding(
										padding: const EdgeInsets.symmetric(horizontal: 16.0),
										child: Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												ProfileButton(
													key: _profileButtonKey,
													onTap: () async {
														await Navigator.of(context).push(
															MaterialPageRoute(
																builder: (context) => const SettingsScreen(),
															),
														);
														// Refresh profile button when returning from settings
														_profileButtonKey.currentState?.loadProfileImage();
													},
												),
												TopButtons(
													onFaqTap: () {
														Navigator.of(context).push(
															MaterialPageRoute(
																builder: (context) => const FaqScreen(),
															),
														);
													},
													onNotificationTap: () async {
														await Navigator.of(context).push(
															MaterialPageRoute(
																builder: (context) => const NotificationScreen(),
															),
														);
														// Refresh badge when returning from notification screen
														_notificationButtonKey.currentState?.refreshBadge();
													},
													notificationButtonKey: _notificationButtonKey,
												),
											],
										),
									),
									const SizedBox(height: 4),
									// Announcement bar just below profile/top buttons
									const AnnouncementBar(),
									const SizedBox(height: 8),
																		// Adaptive content that fits without scrolling
																		Expanded(
																			child: LayoutBuilder(
																				builder: (context, constraints) {
																					final maxH = constraints.maxHeight;
																					final spacingTop = (maxH * 0.02).clamp(8.0, 16.0);
																					final spacingMid = (maxH * 0.03).clamp(12.0, 24.0);
																					final imgH = math.min(iconHeight, maxH * 0.28);
																					// Slightly reduce button padding on very short screens
																					final shortScreen = maxH < 560;
																					final btnHpad = shortScreen ? buttonHPad * 0.9 : buttonHPad;
																					final btnVpad = shortScreen ? math.max(10.0, buttonVPad * 0.9) : buttonVPad;
																					final btnFont = shortScreen ? math.max(16.0, buttonFont - 2) : buttonFont;
																					return Column(
																						children: [
																							SizedBox(height: spacingTop),
																							SizedBox(
																								height: imgH,
																								child: Center(
																									child: Image.asset(
																										'assets/images/icon_complete.webp',
																										height: imgH,
																										fit: BoxFit.contain,
																									),
																								),
																							),
																							SizedBox(height: spacingMid),
																							Center(
																								child: GradientButtonFb1(
																									text: 'Explore',
																									onPressed: () {
																										widget.onNavigateToMap?.call();
																									},
																									horizontalPadding: btnHpad,
																									verticalPadding: btnVpad,
																									fontSize: btnFont,
																								),
																							),
																							const SizedBox(height: 12),
																							// Let carousel take remaining space without forcing scrolling
																																															Expanded(
																																																child: CustomCarouselFB2(
																																																	onNavigateToMap: widget.onNavigateToMap,
																																																	onLocate: widget.onLocateRequest,
																																																),
																																															),
																							const SizedBox(height: 8),
																						],
																					);
																				},
																			),
																		),
								],
							),
						),
					),
				],
			),
		);
	}
}