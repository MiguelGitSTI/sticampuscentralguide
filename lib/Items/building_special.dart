
/// Declarative overlay specs for buildings. Each entry defines:
///  - title: heading on the info card
///  - description: short body text
///  - alignmentX/Y: normalized position relative to map center (same space as BuildingItem)
///  - optional width constraint for the card
class BuildingOverlaySpec {
	final String id;
	final String title;
	final String description;
	final String? navigateText;
	final String? roomsText;
	final double alignmentX; // [-1,1]
	final double alignmentY; // [-1,1]
	final double maxWidth;

	const BuildingOverlaySpec({
		required this.id,
		required this.title,
		required this.description,
		this.navigateText,
		this.roomsText,
		required this.alignmentX,
		required this.alignmentY,
		this.maxWidth = 240,
	});
}

/// Manual overlay positions (base is center 0,0; offsets chosen for clarity).
/// Adjust alignmentX/alignmentY to fine‑tune placement.
const Map<String, BuildingOverlaySpec> kBuildingOverlays = {
	'building_b': BuildingOverlaySpec(
		id: 'building_b',
		title: 'Building B',
		description: 'A building filled with classrooms and a cafeteria, also with proware where you could try out and get clothes.',
		alignmentX: -0.15,
		alignmentY: -0.55,
	),
	'gym_top_right': BuildingOverlaySpec(
		id: 'gym_top_right',
		title: 'Gym',
		description: 'A place where official events are held. You can also find students partaking in their PE class below.',
		alignmentX: 0.70,
		alignmentY: -0.75,
	),
	'building_c': BuildingOverlaySpec(
		id: 'building_c',
		title: 'Building C',
		description: 'A building filled with classrooms and a cafeteria, with a PE area below the building.',
		alignmentX: 0.68,
		alignmentY: 0.05,
	),
	'cottage': BuildingOverlaySpec(
		id: 'cottage',
		title: 'Cottage',
		description: 'Outdoor seating & informal meetups.',
		alignmentX: -0.55,
		alignmentY: 0.15,
	),
	'gate': BuildingOverlaySpec(
		id: 'gate',
		title: 'Gate',
		description: 'Campus entrance & security post.',
		alignmentX: -0.90,
		alignmentY: 0.45,
	),
	'airport': BuildingOverlaySpec(
		id: 'airport',
		title: 'Airport',
		description: 'A building where you can find most of the admin offices (registrar, cashier).',
		alignmentX: 0.82,
		alignmentY: 0.58,
		maxWidth: 260,
	),
};

