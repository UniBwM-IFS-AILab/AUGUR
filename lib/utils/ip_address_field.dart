import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IPAddressField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const IPAddressField({
    Key? key,
    required this.controller,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  _IPAddressFieldState createState() => _IPAddressFieldState();
}

class _IPAddressFieldState extends State<IPAddressField> {
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
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: "IP Address",
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), // Only allows valid IP format
      ],
      onChanged: _onIPChanged,
      onTap: () {
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );
      },
      onSubmitted: widget.onSubmitted, // Calls the provided function when submitted
    );
  }
}
