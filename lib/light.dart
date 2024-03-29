import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:smartlab_ui/homeassistant_model.dart';

class LightWidget extends StatelessWidget {
  const LightWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeAssistantModel>(builder: (context, ha, child) {
      final on = ha.lampState.lightness > 0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Slider(
                value: (ha.lampColorTemperature ?? 250).toDouble(),
                onChanged: (value) {
                  log("slider changed: $value", name: "at.metalab.smart");
                  ha.lampColorTemperature = value.toInt();
                },
                min: 250,
                max: 454),
          ),
          HueRingPicker(
              pickerColor: ha.lampState.toColor(),
              onColorChanged: (color) {
                ha.lampState = HSLColor.fromColor(color);
              },
              hueRingStrokeWidth: 30,
              enableAlpha: false,
              displayThumbColor: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ElevatedButton(
                      onPressed: () {
                        ha.setLamp(!on);
                      },
                      style: ButtonStyle(
                          backgroundColor: on
                              ? MaterialStateProperty.all(
                                  Theme.of(context).colorScheme.secondary)
                              : null,
                          padding: MaterialStateProperty.all(
                              const EdgeInsets.all(20))),
                      child: Text(on ? "Turn Off" : "Turn On",
                          style: const TextStyle(fontSize: 40)))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: () {
                          ha.startup();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child:
                              Text("Startup", style: TextStyle(fontSize: 24)),
                        )),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: () {
                          ha.shutdown();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child:
                              Text("Shutdown", style: TextStyle(fontSize: 24)),
                        )),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    });
  }
}
