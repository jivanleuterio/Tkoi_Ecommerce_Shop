import 'package:flutter/material.dart';

import '../services/current_location_service.dart';
import '../theme/app_colors.dart';

class CurrentLocationButton extends StatefulWidget {
  final TextEditingController controller;

  const CurrentLocationButton({super.key, required this.controller});

  @override
  State<CurrentLocationButton> createState() => _CurrentLocationButtonState();
}

class _CurrentLocationButtonState extends State<CurrentLocationButton> {
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _locating = true);
    try {
      final address = await CurrentLocationService().getCurrentAddress();
      if (!mounted) return;
      widget.controller.value = TextEditingValue(
        text: address,
        selection: TextSelection.collapsed(offset: address.length),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Current address added.')));
    } on CurrentLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not determine your address. Please enter it manually.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _locating ? 'Finding current location' : 'Use current location',
      child: IconButton(
        tooltip: 'Use current location',
        onPressed: _locating ? null : _useCurrentLocation,
        icon: _locating
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const Icon(Icons.my_location_rounded, color: AppColors.pondBlue),
      ),
    );
  }
}
