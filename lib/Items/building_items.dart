import 'package:flutter/material.dart';

/// Canonical map canvas size that all positions are relative to.
/// The backing image `assets/images/map_map.png` is 1024x768.
class MapSpec {
  static const double width = 1024;
  static const double height = 768;
  static const Size size = Size(width, height);
}

/// Normalized building metadata positioned on top of the map.
/// Coordinates x,y are relative to the map center in the range [-1, 1],
/// where (0,0) is center, (-1,-1) top-left, (1,1) bottom-right.
class BuildingItem {
  final String id;
  final String asset;
  final double x; // relative to center, [-1, 1]
  final double y; // relative to center, [-1, 1]
  final double scale; // width as fraction of map width; height preserves aspect
  final int z; // stacking order (higher = on top)
  final String? label;
  final bool hidden; // when true, do not render the building

  const BuildingItem({
    required this.id,
    required this.asset,
    required this.x,
    required this.y,
    required this.scale,
    this.z = 0,
    this.label,
    this.hidden = false,
  });
}

/// Approximate placements scaled from the composite base image.
/// Tweak these values visually to refine alignment if needed.
const List<BuildingItem> kBuildingItems = [
  // Main multi-story building (centered for now)
  BuildingItem(
    id: 'building_b',
    asset: 'assets/images/map_buildingb.png',
    x: -0.345,
    y: -0.11,
    scale: 0.125, // width fraction
    z: 2,
    label: 'Building B',
    hidden: false,
  ),
  // Top-right gym building (centered for now)
  BuildingItem(
    id: 'gym_top_right',
    asset: 'assets/images/map_gym.png',
    x: 0.49,
    y: -0.28,
    scale: 0.119,
    z: 1,
    label: 'Gym',
    hidden: false,
  ),
  // Bottom-right curved-roof building (centered for now)
  BuildingItem(
    id: 'building_c',
    asset: 'assets/images/map_buildingc.png',
    x: 0.47,
    y: 0.178,
    scale: 0.103,
    z: 2,
    label: 'Building C',
    hidden: false,
  ),
  // Gazebo + tree (centered for now)
  BuildingItem(
    id: 'cottage',
    asset: 'assets/images/map_cottage.png',
    x: -0.25,
    y: 0.042,
    scale: 0.017,
    z: 4,
    label: 'Cottage',
    hidden: false,
  ),
  // Guardhouse/gate (centered for now)
  BuildingItem(
    id: 'gate',
    asset: 'assets/images/map_gate.png',
    x: -0.95,
    y: 0.24,
    scale: 0.023,
    z: 5,
    label: 'Gate',
    hidden: false,
  ),
  // Airport (new) – approximate placement; adjust x,y & scale as needed
  BuildingItem(
    id: 'airport',
    asset: 'assets/images/map_airport.png',
    x: -0.56, // near far right
    y: 0.25, // lower area
    scale: 0.14, // adjust after visRual check
    z: 3,
    label: 'Airport',
    hidden: false,
  ),
];
