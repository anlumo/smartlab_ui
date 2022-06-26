import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartlab_ui/homeassistant_model.dart';
import 'package:smartlab_ui/light.dart';
import 'package:yaml/yaml.dart';

Future<void> main() async {
  final configFile = File(const String.fromEnvironment('config',
      defaultValue: 'smartlab_config.yaml'));
  final yamlString = await configFile.readAsString();
  final dynamic config = loadYaml(yamlString);

  runApp(ChangeNotifierProvider(
      create: (context) => HomeAssistantModel(config), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartLab',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        colorScheme: ColorScheme.fromSwatch(
            primarySwatch: const MaterialColor(0xff182E46, <int, Color>{
              50: Color(0xffb3b5b8),
              100: Color(0xff3e9ac4),
              200: Color(0xff0085b3),
              300: Color(0xff007fb4),
              400: Color(0xff0070a0),
              500: Color(0xff094f73),
              600: Color(0xff334B6A),
              700: Color(0xff003960),
              800: Color(0xff1C3654),
              900: Color(0xff182E46),
            }),
            accentColor: const Color(0xffcc6427)),
      ),
      home: const MyHomePage(title: 'SmartLab Control'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: LightWidget(),
        ));
  }
}
