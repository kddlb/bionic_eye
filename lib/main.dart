import 'dart:io';

import 'package:bionic_eye/app_settings.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mime/mime.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cross_file/cross_file.dart';

void main() async {
  await Settings.init();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainPage(),
      title: "Bionic Eye",
      theme: ThemeData(colorSchemeSeed: Colors.lightGreen, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.lightGreen,
          brightness: Brightness.dark,
          useMaterial3: true),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool progressIsVisible = false;
  final clipboard = SystemClipboard.instance;
  Uint8List? image;
  String result = "";
  late ScrollController scrollController;

  @override
  void initState() {
    scrollController = ScrollController();
    super.initState();
    var key = Settings.getValue<String>("api_key");
    if (key == null || key.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text("A Gemini API key is required."),
            content: const Text("The API key is only sent to Google."),
            actions: <Widget>[
              TextButton(
                  onPressed: () => {
                        launchUrlString(
                            "https://aistudio.google.com/app/apikey")
                      },
                  child: const Text("Get API key from Google AI Studio")),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AppSettings()));
                  },
                  child: const Text("Set"))
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isWide =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              pasteImage,
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              pasteImage,
        },
        child: Scaffold(
            appBar: AppBar(
                title: const Text("Bionic Eye"),
                bottom: progressIsVisible
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(6.0),
                        child: LinearProgressIndicator(
                          value: null,
                        ))
                    : null,
                leading: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const AppSettings()));
                  },
                  icon: const Icon(Icons.settings),
                  tooltip: "Settings",
                ),
                actions: [
                  IconButton(
                    onPressed: () async {
                      var result = await FilePicker.platform
                          .pickFiles(type: FileType.image);
                      if (result != null) {
                        var file = File(result.files.single.path!);
                        setState(() {
                          try {
                            image = file.readAsBytesSync();
                          } catch (err) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Error: ${err.toString()}")));
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.file_open_outlined),
                    tooltip: "Open image",
                  ),
                  if (clipboard != null)
                    IconButton(
                        onPressed: pasteImage,
                        icon: const Icon(Icons.paste),
                        tooltip: "Paste"),
                  if (Platform.isAndroid || Platform.isIOS)
                    IconButton(
                        onPressed: () {
                          summonCamera(context);
                        },
                        icon: const Icon(Icons.camera_alt))
                ]),
            floatingActionButton: image != null
                ? FloatingActionButton(
                    onPressed: progressIsVisible ? null : runGemini,
                    tooltip: "Process",
                    child: const Icon(Icons.remove_red_eye),
                  )
                : null,
            body: Center(
                child: Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              children: [
                Expanded(
                    child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                        child: image != null ? Image.memory(image!) : null)
                  ],
                )),
                Expanded(
                    child: SelectionArea(
                        child: Markdown(
                  controller: scrollController,
                  data: result,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                )))
              ],
            ))));
  }

  Future<void> summonCamera(BuildContext context) async {
    final XFile result =
        await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return CameraAwesomeBuilder.awesome(
          onMediaTap: (mc) {
            mc.captureRequest.when(single: (single) {
              Navigator.pop(context, single.file!);
            });
          },
          enablePhysicalButton: true,
          saveConfig: SaveConfig.photo(
              exifPreferences: ExifPreferences(saveGPSLocation: false)));
    }));

    if (!context.mounted) return;

    var imageBytes = await result.readAsBytes();

    setState(() {
      image = imageBytes;
    });
  }

  void pasteImage() async {
    final reader = await clipboard!.read();
    if (reader.canProvide(Formats.png)) {
      reader.getFile(Formats.png, (fl) async {
        var bytes = await fl.readAll();
        setState(() {
          image = bytes;
        });
      });
      return;
    }
    if (reader.canProvide(Formats.jpeg)) {
      reader.getFile(Formats.jpeg, (fl) async {
        var bytes = await fl.readAll();
        setState(() {
          image = bytes;
        });
      });
      return;
    }
    if (reader.canProvide(Formats.heic)) {
      reader.getFile(Formats.heic, (fl) async {
        var bytes = await fl.readAll();
        setState(() {
          image = bytes;
        });
      });
      return;
    }
    if (reader.canProvide(Formats.heif)) {
      reader.getFile(Formats.heif, (fl) async {
        var bytes = await fl.readAll();
        setState(() {
          image = bytes;
        });
      });
      return;
    }
    if (reader.canProvide(Formats.tiff)) {
      reader.getFile(Formats.tiff, (fl) async {
        var bytes = await fl.readAll();
        setState(() {
          image = bytes;
        });
      });
      return;
    }
  }

  void runGemini() {
    var apiKey = Settings.getValue<String>("api_key");

    if (apiKey == null || apiKey.isEmpty) {
      var errorSnackBar = SnackBar(
          content: const Text("An API key has not been set."),
          action: SnackBarAction(
              label: "Set",
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const AppSettings()))));
      ScaffoldMessenger.of(context).showSnackBar(errorSnackBar);
    } else {
      setState(() {
        progressIsVisible = true;
      });
      final model = GenerativeModel(
          model: "gemini-1.5-pro-latest",
          apiKey: apiKey,
          requestOptions: const RequestOptions(apiVersion: "v1beta"),
          safetySettings: [
            SafetySetting(
                HarmCategory.dangerousContent, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
            SafetySetting(
                HarmCategory.sexuallyExplicit, HarmBlockThreshold.none)
          ],
          systemInstruction:
              Content.system(Settings.getValue<String>("system_instruction")!));

      final genStream = model.generateContentStream(
          [Content.data(lookupMimeType("", headerBytes: image!)!, image!)]);

      result = "";

      genStream.listen((data) {
        setState(() {
          result += data.text ?? "";
          scrollController.animateTo(scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 125),
              curve: Curves.easeOut);
        });
      }, onDone: () {
        setState(() {
          progressIsVisible = false;
        });
      }, onError: (err) {
        progressIsVisible = false;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${err.toString()}")));
      });
    }
  }
}
