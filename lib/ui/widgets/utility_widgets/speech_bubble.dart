import 'dart:async';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';

class SpeechBubble extends StatefulWidget {
  final Stream<String> textStream;
  final Function(String) onAccept;
  final VoidCallback? onClear;

  const SpeechBubble(
      {super.key,
      required this.textStream,
      required this.onAccept,
      this.onClear});

  @override
  SpeechBubbleState createState() => SpeechBubbleState();
}

class SpeechBubbleState extends State<SpeechBubble> {
  final TextEditingController _textController = TextEditingController();
  String _lastReceivedText = "";
  String _accumulatedText = "";

  @override
  void initState() {
    super.initState();
    widget.textStream.listen((newText) {
      if (!mounted) return;

      setState(() {
        if (newText.isEmpty) {
          _lastReceivedText = "";
          _accumulatedText = "";
          _textController.text = "";
        } else {
          // Process the new text
          _accumulatedText =
              _getCorrectedText(_accumulatedText, _lastReceivedText, newText);
          _lastReceivedText = newText;
          _textController.text = _accumulatedText;
        }
      });
    });
  }

  String _getCorrectedText(
      String accumulatedText, String lastText, String newText) {
    // No previous accumulation yet
    if (accumulatedText.isEmpty) return newText;

    // Empty new text shouldn't change anything
    if (newText.isEmpty) return accumulatedText;

    // Check if new text is just extending the last text segment
    // (Speech recognition refining the same utterance)
    if (lastText.isNotEmpty &&
        (newText.startsWith(lastText) || lastText.startsWith(newText))) {
      // Replace the last segment with the new text
      if (accumulatedText.endsWith(lastText)) {
        return accumulatedText.substring(
                0, accumulatedText.length - lastText.length) +
            newText;
      }
    }

    // Check if it might be a continuation of the accumulated text
    if (newText.length <= 5 && !accumulatedText.endsWith(" ")) {
      // Short fragment and no space at the end - likely continuation
      return "$accumulatedText $newText";
    }
    // Check if this is a completely new phrase (usually longer)
    if (newText.length > 5 &&
        !accumulatedText
            .toLowerCase()
            .contains(newText.substring(0, 3).toLowerCase())) {
      // Add new text as continuation
      return "$accumulatedText $newText";
    }
    // Default: if unsure, just add it with a space
    return "$accumulatedText $newText";
  }

  void _clearState() {
    setState(() {
      _textController.text = "";
      _lastReceivedText = "";
      _accumulatedText = "";
    });
    // Notify parent to clear the stream controller
    widget.onClear?.call();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_textController.text.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      SizedBox(
        width: 200,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Theme(
              data: ThemeData(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: AppColors.secondary
                      .withAlpha(25), // Text selection background color
                  selectionHandleColor:
                      AppColors.secondary, // Handle (drag cursor) color
                ),
              ),
              child: TextField(
                  controller: _textController,
                  cursorColor: AppColors.secondary,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "",
                  ),
                  style: TextStyle(
                    fontSize: _calculateFontSize(_textController.text),
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: () {
              String text = _textController.text;
              _clearState();
              widget.onAccept(text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.text),
            child: const Text("Accept"),
          ),
          ElevatedButton(
            onPressed: () {
              _clearState();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.text),
            child: const Text("Discard"),
          ),
        ],
      ),
    ]);
  }

  double _calculateFontSize(String text) {
    if (text.length < 20) return 16;
    if (text.length < 40) return 14;
    return 12;
  }
}
