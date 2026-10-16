import 'package:flutter/material.dart';

/// Icons are saved by name so the app never stores raw code points
/// (that keeps release builds small and safe).
class IconGroup {
  final String name;
  final Map<String, IconData> icons;
  const IconGroup(this.name, this.icons);
}

const iconGroups = <IconGroup>[
  IconGroup('Work', {
    'work': Icons.work_outline, 'business': Icons.business_center, 'briefcase': Icons.cases_outlined,
    'apartment': Icons.apartment, 'badge': Icons.badge_outlined, 'assignment': Icons.assignment_outlined,
    'task': Icons.task_alt, 'checklist': Icons.checklist, 'inventory': Icons.inventory_2_outlined,
    'meeting': Icons.groups_outlined, 'handshake': Icons.handshake_outlined, 'presentation': Icons.co_present_outlined,
    'chart': Icons.bar_chart, 'pie': Icons.pie_chart_outline, 'trending': Icons.trending_up,
    'timeline': Icons.timeline, 'leaderboard': Icons.leaderboard_outlined, 'analytics': Icons.analytics_outlined,
    'insights': Icons.insights, 'flag': Icons.flag_outlined, 'target': Icons.track_changes,
    'rocket': Icons.rocket_launch_outlined, 'lightbulb': Icons.lightbulb_outline, 'campaign': Icons.campaign_outlined,
    'support': Icons.support_agent, 'engineering': Icons.engineering_outlined, 'gavel': Icons.gavel,
    'balance': Icons.balance, 'verified': Icons.verified_outlined, 'workspace': Icons.workspace_premium_outlined,
  }),
  IconGroup('Money', {
    'money': Icons.payments_outlined, 'wallet': Icons.account_balance_wallet_outlined, 'bank': Icons.account_balance,
    'card': Icons.credit_card, 'savings': Icons.savings_outlined, 'receipt': Icons.receipt_long_outlined,
    'dollar': Icons.attach_money, 'euro': Icons.euro, 'pound': Icons.currency_pound,
    'rupee': Icons.currency_rupee, 'yen': Icons.currency_yen, 'bitcoin': Icons.currency_bitcoin,
    'sell': Icons.sell_outlined, 'shop': Icons.storefront_outlined, 'cart': Icons.shopping_cart_outlined,
    'bag': Icons.shopping_bag_outlined, 'price': Icons.price_change_outlined, 'calc': Icons.calculate_outlined,
    'request': Icons.request_quote_outlined, 'exchange': Icons.currency_exchange,
  }),
  IconGroup('Design', {
    'palette': Icons.palette_outlined, 'brush': Icons.brush_outlined, 'draw': Icons.draw_outlined,
    'edit': Icons.edit_outlined, 'format': Icons.format_paint_outlined, 'colorize': Icons.colorize,
    'crop': Icons.crop, 'image': Icons.image_outlined, 'photo': Icons.photo_library_outlined,
    'camera': Icons.photo_camera_outlined, 'video': Icons.videocam_outlined, 'movie': Icons.movie_outlined,
    'gradient': Icons.gradient, 'layers': Icons.layers_outlined, 'grid': Icons.grid_view,
    'dashboard': Icons.dashboard_outlined, 'web': Icons.web, 'auto': Icons.auto_awesome,
    'style': Icons.style_outlined, 'shapes': Icons.category_outlined, 'animation': Icons.animation,
    'font': Icons.text_fields, 'title': Icons.title, 'brand': Icons.branding_watermark_outlined,
  }),
  IconGroup('Code', {
    'code': Icons.code, 'terminal': Icons.terminal, 'bug': Icons.bug_report_outlined,
    'api': Icons.api, 'data': Icons.data_object, 'storage': Icons.storage, 'cloud': Icons.cloud_outlined,
    'dns': Icons.dns_outlined, 'router': Icons.router_outlined, 'memory': Icons.memory,
    'devices': Icons.devices, 'phone': Icons.smartphone, 'laptop': Icons.laptop_mac,
    'desktop': Icons.desktop_windows_outlined, 'tablet': Icons.tablet_mac, 'watch': Icons.watch_outlined,
    'wifi': Icons.wifi, 'bluetooth': Icons.bluetooth, 'security': Icons.security, 'lock': Icons.lock_outline,
    'key': Icons.key, 'build': Icons.build_outlined, 'settings': Icons.settings_outlined,
    'integration': Icons.integration_instructions_outlined, 'hub': Icons.hub_outlined, 'link': Icons.link,
    'webhook': Icons.webhook, 'merge': Icons.merge_type, 'fork': Icons.fork_right, 'android': Icons.android,
  }),
  IconGroup('Writing', {
    'note': Icons.sticky_note_2_outlined, 'notes': Icons.notes, 'article': Icons.article_outlined,
    'book': Icons.menu_book_outlined, 'library': Icons.local_library_outlined, 'bookmark': Icons.bookmark_outline,
    'description': Icons.description_outlined, 'folder': Icons.folder_outlined, 'folderopen': Icons.folder_open_outlined,
    'file': Icons.insert_drive_file_outlined, 'attach': Icons.attach_file, 'clipboard': Icons.content_paste,
    'quote': Icons.format_quote, 'list': Icons.format_list_bulleted, 'numbered': Icons.format_list_numbered,
    'translate': Icons.translate, 'spellcheck': Icons.spellcheck, 'newspaper': Icons.newspaper,
    'mail': Icons.mail_outline, 'inbox': Icons.inbox_outlined, 'send': Icons.send_outlined,
    'chat': Icons.chat_bubble_outline, 'forum': Icons.forum_outlined, 'comment': Icons.comment_outlined,
    'mic': Icons.mic_none, 'podcast': Icons.podcasts, 'rss': Icons.rss_feed, 'print': Icons.print_outlined,
  }),
  IconGroup('Study', {
    'school': Icons.school_outlined, 'science': Icons.science_outlined, 'biotech': Icons.biotech_outlined,
    'psychology': Icons.psychology_outlined, 'calculate': Icons.functions, 'history': Icons.history_edu,
    'language': Icons.language, 'public': Icons.public, 'quiz': Icons.quiz_outlined, 'help': Icons.help_outline,
    'grade': Icons.grade_outlined, 'emoji': Icons.emoji_objects_outlined, 'architecture': Icons.architecture,
    'straighten': Icons.straighten, 'compass': Icons.explore_outlined, 'map': Icons.map_outlined,
    'piano': Icons.piano, 'music': Icons.music_note, 'headphones': Icons.headphones, 'album': Icons.album_outlined,
  }),
  IconGroup('Home & life', {
    'home': Icons.home_outlined, 'house': Icons.house_outlined, 'bed': Icons.bed_outlined,
    'chair': Icons.chair_outlined, 'kitchen': Icons.kitchen_outlined, 'cleaning': Icons.cleaning_services_outlined,
    'laundry': Icons.local_laundry_service_outlined, 'plant': Icons.local_florist_outlined, 'yard': Icons.yard_outlined,
    'pets': Icons.pets, 'child': Icons.child_care, 'family': Icons.family_restroom, 'people': Icons.people_outline,
    'person': Icons.person_outline, 'cake': Icons.cake_outlined, 'gift': Icons.card_giftcard, 'celebration': Icons.celebration_outlined,
    'favorite': Icons.favorite_border, 'heart': Icons.volunteer_activism_outlined, 'mood': Icons.mood,
    'light': Icons.light_outlined, 'water': Icons.water_drop_outlined, 'bolt': Icons.bolt, 'recycle': Icons.recycling,
    'tools': Icons.handyman_outlined, 'plumbing': Icons.plumbing, 'key2': Icons.vpn_key_outlined, 'calendar': Icons.calendar_month_outlined,
    'event': Icons.event_outlined, 'alarm': Icons.alarm, 'timer': Icons.timer_outlined, 'hourglass': Icons.hourglass_empty,
  }),
  IconGroup('Food', {
    'restaurant': Icons.restaurant, 'fastfood': Icons.fastfood_outlined, 'pizza': Icons.local_pizza_outlined,
    'cafe': Icons.local_cafe_outlined, 'coffee': Icons.coffee_outlined, 'bar': Icons.local_bar_outlined,
    'bakery': Icons.bakery_dining_outlined, 'icecream': Icons.icecream_outlined, 'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined, 'breakfast': Icons.breakfast_dining_outlined, 'ramen': Icons.ramen_dining_outlined,
    'egg': Icons.egg_outlined, 'grocery': Icons.local_grocery_store_outlined, 'liquor': Icons.liquor_outlined,
    'blender': Icons.blender_outlined, 'outdoorgrill': Icons.outdoor_grill_outlined, 'set_meal': Icons.set_meal_outlined,
  }),
  IconGroup('Health', {
    'fitness': Icons.fitness_center, 'run': Icons.directions_run, 'walk': Icons.directions_walk,
    'bike': Icons.directions_bike, 'pool': Icons.pool, 'yoga': Icons.self_improvement, 'spa': Icons.spa_outlined,
    'medical': Icons.medical_services_outlined, 'hospital': Icons.local_hospital_outlined, 'medication': Icons.medication_outlined,
    'monitor_heart': Icons.monitor_heart_outlined, 'sleep': Icons.bedtime_outlined, 'sports': Icons.sports_soccer,
    'basketball': Icons.sports_basketball, 'tennis': Icons.sports_tennis, 'cricket': Icons.sports_cricket,
    'esports': Icons.sports_esports_outlined, 'hiking': Icons.hiking, 'skate': Icons.skateboarding, 'surf': Icons.surfing,
  }),
  IconGroup('Travel', {
    'flight': Icons.flight, 'train': Icons.train_outlined, 'bus': Icons.directions_bus_outlined, 'car': Icons.directions_car_outlined,
    'boat': Icons.directions_boat_outlined, 'taxi': Icons.local_taxi_outlined, 'hotel': Icons.hotel_outlined,
    'luggage': Icons.luggage_outlined, 'beach': Icons.beach_access_outlined, 'park': Icons.park_outlined,
    'landscape': Icons.landscape_outlined, 'mountain': Icons.terrain, 'place': Icons.place_outlined,
    'navigation': Icons.navigation_outlined, 'local_gas': Icons.local_gas_station_outlined, 'parking': Icons.local_parking,
    'museum': Icons.museum_outlined, 'castle': Icons.castle_outlined, 'camping': Icons.cabin_outlined, 'tour': Icons.tour_outlined,
  }),
  IconGroup('Symbols', {
    'star': Icons.star_outline, 'stars': Icons.stars_outlined, 'diamond': Icons.diamond_outlined, 'fire': Icons.local_fire_department_outlined,
    'eco': Icons.eco_outlined, 'sun': Icons.wb_sunny_outlined, 'moon': Icons.dark_mode_outlined, 'cloudy': Icons.cloud_queue,
    'snow': Icons.ac_unit, 'thunder': Icons.thunderstorm_outlined, 'umbrella': Icons.umbrella_outlined, 'puzzle': Icons.extension_outlined,
    'trophy': Icons.emoji_events_outlined, 'military': Icons.military_tech_outlined, 'pin': Icons.push_pin_outlined, 'label': Icons.label_outline,
    'tag': Icons.local_offer_outlined, 'bell': Icons.notifications_none, 'visibility': Icons.visibility_outlined, 'search': Icons.search,
    'check': Icons.check_circle_outline, 'pending': Icons.pending_outlined, 'pause': Icons.pause_circle_outline, 'play': Icons.play_circle_outline,
    'stop': Icons.stop_circle_outlined, 'block': Icons.block, 'error': Icons.error_outline, 'info': Icons.info_outline,
    'warning': Icons.warning_amber, 'priority': Icons.priority_high, 'loop': Icons.loop, 'sync': Icons.sync,
    'review': Icons.rate_review_outlined, 'hourglass_top': Icons.hourglass_top, 'schedule': Icons.schedule, 'done_all': Icons.done_all,
    'archive': Icons.archive_outlined, 'delete': Icons.delete_outline, 'cancel': Icons.cancel_outlined, 'circle': Icons.circle_outlined,
    'square': Icons.crop_square, 'change': Icons.change_history, 'hexagon': Icons.hexagon_outlined, 'pentagon': Icons.pentagon_outlined,
    'all_inclusive': Icons.all_inclusive, 'waves': Icons.waves, 'grain': Icons.grain, 'blur': Icons.blur_on,
  }),
];

final Map<String, IconData> allIcons = {for (final g in iconGroups) ...g.icons};

IconData iconOf(String? key) => allIcons[key] ?? Icons.folder_outlined;

int get iconCount => allIcons.length;
