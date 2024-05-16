import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  AppSettingsState createState() => AppSettingsState();
}

class AppSettingsState extends State<AppSettings> {
  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      title: "Settings",
      children: [
        TextInputSettingsTile(
          title: "Gemini API key",
          settingKey: "api_key",
          validator: (ak) => (ak != null && ak.isNotEmpty)
              ? null
              : "An API key is required.",
        ),
        TextInputSettingsTile(
          title: "System instruction",
          settingKey: "system_instruction",
          initialValue: "Explain this image with the most thorough detail possible.",
          validator: (ak) => (ak != null && ak.isNotEmpty)
              ? null
              : "A system instruction is required",
        ),
        const AboutListTile(
            icon: Icon(Icons.info),
            applicationLegalese: "\u{a9} 2024 Kevin López Brante"),
      ],
    );
  }
}