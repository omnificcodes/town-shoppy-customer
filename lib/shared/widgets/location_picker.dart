import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location/location_result.dart';
import '../../core/location/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';

/// A draggable-pin map for "where is this business" -- the mobile twin of
/// the merchant web app's Leaflet `LocationPicker`: OpenStreetMap tiles,
/// tap to place, drag to fine-tune, and a "Use my location" shortcut.
/// Same default centre (Kerala) and zoom levels as the web so a pin
/// dropped on either client lands in the same place.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.value, required this.onChanged, this.errorText, this.height = 280});

  final LatLng? value;
  final ValueChanged<LatLng> onChanged;
  final String? errorText;
  final double height;

  static final defaultCenter = LatLng(10.8505, 76.2711);

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _controller = MapController();
  bool _locating = false;
  String? _locationNote;

  @override
  void didUpdateWidget(covariant LocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != null && value != oldWidget.value) {
      _controller.move(value, _controller.camera.zoom < 15 ? 15 : _controller.camera.zoom);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });
    final result = await const LocationService().getCurrentLocation();
    if (!mounted) return;
    switch (result) {
      case LocationAvailable(:final latitude, :final longitude):
        widget.onChanged(LatLng(latitude, longitude));
      case LocationServiceDisabled():
        _locationNote = 'Turn on location services to use your current position.';
      case LocationPermissionDenied():
      case LocationPermissionDeniedForever():
        _locationNote = 'Location permission was not granted -- tap the map to place the pin instead.';
    }
    setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              border: Border.all(color: hasError ? AppColors.error : AppColors.border, width: hasError ? 1.5 : 1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: value ?? LocationPicker.defaultCenter,
                    initialZoom: value != null ? 15 : 8,
                    onTap: (_, point) => widget.onChanged(point),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.townshoppy.customer',
                    ),
                    if (value != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: value,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_pin, color: AppColors.crimson, size: 44),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(
                      showFlutterMapAttribution: false,
                      attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                    ),
                  ],
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    elevation: 2,
                    child: AppButton(
                      label: _locating ? 'Locating…' : 'Use my location',
                      icon: Icons.my_location_rounded,
                      variant: AppButtonVariant.text,
                      size: AppButtonSize.sm,
                      expand: false,
                      isLoading: _locating,
                      onPressed: _locating ? null : _useMyLocation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.errorText ??
              _locationNote ??
              (value == null
                  ? 'Tap the map, or use "Use my location", to pin your business\'s exact location.'
                  : 'Pinned at ${value.latitude.toStringAsFixed(5)}, ${value.longitude.toStringAsFixed(5)}'),
          style: AppTypography.caption.copyWith(color: hasError ? AppColors.error : AppColors.textSecondary),
        ),
      ],
    );
  }
}
