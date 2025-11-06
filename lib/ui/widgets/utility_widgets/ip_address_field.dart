import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IPAddressField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final String? defaultValue;

  const IPAddressField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.defaultValue,
  });

  @override
  IPAddressFieldState createState() => IPAddressFieldState();
}

class IPAddressFieldState extends State<IPAddressField> {
  @override
  void initState() {
    super.initState();
    // Set default value if provided and controller is empty
    if (widget.defaultValue != null && widget.controller.text.isEmpty) {
      widget.controller.text = widget.defaultValue!;
    }
  }

  void _onIPChanged(String value) {
    // Ensures only numbers and dots are allowed
    String filtered = value.replaceAll(RegExp(r'[^0-9.]'), '');

    // Prevents multiple consecutive dots
    if (filtered.contains('..')) {
      filtered = filtered.replaceAll('..', '.');
    }

    // Limits the number of dots to 3 (for IPv4)
    int dotCount = '.'.allMatches(filtered).length;
    if (dotCount > 3) {
      filtered = filtered.substring(0, filtered.lastIndexOf('.'));
    }

    // Ensures each section of the IP is between 0 and 255
    List<String> sections = filtered.split('.');
    for (int i = 0; i < sections.length; i++) {
      if (sections[i].isNotEmpty) {
        int? num = int.tryParse(sections[i]);
        if (num != null && num > 255) {
          sections[i] = '255';
        }
      }
    }

    setState(() {
      widget.controller.text = sections.join('.');
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData(
          textSelectionTheme: TextSelectionThemeData(
            selectionColor: AppColors.secondary
                .withAlpha(26), // Text selection background color
            selectionHandleColor:
                AppColors.secondary, // Handle (drag cursor) color
          ),
        ),
        child: TextField(
          controller: widget.controller,
          cursorColor: AppColors.secondary,
          style: TextStyle(
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
              labelText: "IP Address",
              labelStyle: TextStyle(color: AppColors.primary),
              border: OutlineInputBorder(),
              hintStyle: TextStyle(color: AppColors.primary),
              hoverColor: AppColors.secondary,
              focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: AppColors.secondary, width: 2.0)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.primary), // Default border color
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.secondary,
                    width: 2.0), // Border when there's an error
                borderRadius: BorderRadius.circular(8),
              )),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'[0-9.]')), // Only allows valid IP format
          ],
          onChanged: _onIPChanged,
          onTap: () {
            widget.controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: widget.controller.text.length,
            );
          },
          onSubmitted:
              widget.onSubmitted, // Calls the provided function when submitted
        ));
  }
}
