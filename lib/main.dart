import 'package:flutter/material.dart';
import 'package:widget_lab/app.dart';
import 'package:widget_lab/presentation/widget_error.dart';

void main() {
  // Any widget that fails to build or paint shows this tile in its own place. The rest of
  // the app keeps running, and the failure looks the same as the card-level error states.
  ErrorWidget.builder = (details) => WidgetErrorTile(message: details.exceptionAsString());
  runApp(const WidgetLabApp());
}
