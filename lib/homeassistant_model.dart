import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:rate_limiter/rate_limiter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeAssistantModel extends ChangeNotifier {
  final String _uri;
  final String _entityId;
  final String _accessToken;

  WebSocketChannel? _channel;
  StreamIterator? _channelIterator;

  int _messageId = 1;
  final Map<int, Completer> _messageListeners = {};
  final Map<int, Function> _triggerSubscribers = {};
  final Map<int, Function> _eventSubscribers = {};

  HomeAssistantModel(dynamic config)
      : _uri = config['websocket'],
        _entityId = config['entity_id'],
        _accessToken = config['access_token'] {
    _channel = WebSocketChannel.connect(Uri.parse(config['websocket']));
    _channelIterator = StreamIterator(_channel!.stream);
    log("Connecting to websocket at $_uri...", name: "at.metalab.smart");
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _pingTimer?.cancel();
    super.dispose();
  }

  RestartableTimer? _pingTimer;

  bool connected = false;
  HSLColor _lampState = const HSLColor.fromAHSL(1, 0, 0, 0);
  int? _lampColorTemperature;

  HSLColor get lampState {
    return _lampState;
  }

  int? get lampColorTemperature {
    return _lampColorTemperature;
  }

  final pushLampState =
      debounce((Function sendCommand, Map<String, dynamic> settings) async {
    log("pushLampState = $settings", name: "at.metalab.smart.lampstate");
    final Map<String, dynamic> command;
    if (settings['temperature'] != null) {
      command = {
        "domain": "light",
        "service": "turn_on",
        "service_data": {
          "entity_id": settings['entity_id'],
          "color_temp": settings['temperature']
        },
      };
    } else if (settings['color'] != null) {
      final color = settings['color'];
      command = (color.lightness == 0)
          ? {
              "domain": "light",
              "service": "turn_off",
              "target": {
                "entity_id": settings['entity_id'],
              },
            }
          : {
              "domain": "light",
              "service": "turn_on",
              "service_data": {
                "entity_id": settings['entity_id'],
                "hs_color": [color.hue, color.saturation * 100],
                "brightness": color.lightness * 255,
                "transition": 0,
              },
            };
    } else {
      return;
    }
    log("command: $command", name: "at.metalab.smart.lampstate");
    await sendCommand("call_service", command);
  }, const Duration(milliseconds: 100));

  set lampState(HSLColor color) {
    if (color != _lampState) {
      log("Change color from $_lampState to $color", name: "at.metalab.smart");

      pushLampState([
        sendCommand,
        {
          "color": color,
          "entity_id": _entityId,
        }
      ]);
    }
  }

  set lampColorTemperature(int? value) {
    _lampColorTemperature = value;
    if (value != null) {
      pushLampState([
        sendCommand,
        {
          "temperature": value,
          "entity_id": _entityId,
        }
      ]);
    }
  }

  setLamp(bool state) {
    sendCommand("call_service", {
      "domain": "light",
      "service": state ? "turn_on" : "turn_off",
      "target": {
        "entity_id": _entityId,
      },
    });
  }

  Future<Map<String, dynamic>?> _recv() async {
    var channelIterator = _channelIterator;
    if (channelIterator != null && await channelIterator.moveNext()) {
      return jsonDecode(channelIterator.current as String);
    }
    return null;
  }

  void _setup() {
    subscribeEvent("state_changed", (event) {
      var data = event["data"];
      if (data != null) {
        if (data["entity_id"] == _entityId) {
          log("event: $data", name: "at.metalab.smart.event");
          var state = data["new_state"];
          if (state != null) {
            if (state["state"] == "off") {
              if (_lampState.lightness != 0) {
                _lampState = const HSLColor.fromAHSL(1, 0, 0, 0);
                notifyListeners();
              }
            } else {
              var changed = false;
              var attributes = state["attributes"];
              if (attributes != null) {
                var colorValues = attributes["hs_color"];
                var brightness = attributes["brightness"];
                if (colorValues != null && brightness != null) {
                  var newColor = HSLColor.fromAHSL(1, colorValues[0],
                      colorValues[1] / 100, brightness / 255);
                  if (_lampState != newColor) {
                    _lampState = newColor;
                    changed = true;
                  }
                }
                var temp = attributes["color_temp"];
                if (temp != null) {
                  if (_lampColorTemperature != temp) {
                    _lampColorTemperature = temp;
                    changed = true;
                  }
                } else if (_lampColorTemperature != null) {
                  _lampColorTemperature = null;
                  changed = true;
                }
              }
              if (changed) {
                notifyListeners();
              }
            }
          }
        }
      }
    });
    _pingTimer = RestartableTimer(const Duration(seconds: 10), () async {
      await sendCommand("ping", {});
      _pingTimer?.reset();
    });
  }

  void _connect() async {
    var authRequired = await _recv();
    if (authRequired == null || authRequired['type'] != 'auth_required') {
      log('Invalid response from server: expected auth_required',
          name: "at.metalab.smart", error: authRequired);
      return;
    }
    _channel?.sink.add(jsonEncode({
      "type": "auth",
      "access_token": _accessToken,
    }));
    var authResult = await _recv();
    if (authResult == null) {
      log("Server closed connection during authentication",
          name: "at.metalab.smart");
      return;
    }
    switch (authResult["type"]) {
      case "auth_ok":
        log("Websocket authenticated!", name: "at.metalab.smart");
        connected = true;
        notifyListeners();
        _messageHandler();
        _setup();
        break;
      case "auth_invalid":
        log("Authentication failed",
            name: "at.metalab.smart", error: authResult);
        break;
      default:
        log("Invalid response to authentication",
            name: "at.metalab.smart", error: authResult);
    }
  }

  void _messageHandler() async {
    log("Started message handler", name: "at.metalab.smart");
    var channelIterator = _channelIterator;
    if (channelIterator != null) {
      while (await channelIterator.moveNext()) {
        _pingTimer?.reset();
        var message = jsonDecode(channelIterator.current);
        switch (message["type"]) {
          case "trigger":
            var listener = _triggerSubscribers[message["id"]];
            if (listener != null) {
              listener(message);
            } else {
              log("Trigger received without having any subscriber for it!",
                  name: "at.metalab.smart");
            }
            break;
          case "event":
            var listener = _eventSubscribers[message["id"]];
            if (listener != null) {
              listener(message["event"]);
            } else {
              log("Event received without having any subscriber for it!",
                  name: "at.metalab.smart");
            }
            break;
          default:
            var completer = _messageListeners.remove(message["id"]);
            if (completer != null) {
              completer.complete(message);
            } else {
              log("Message received with unknown id: $message",
                  name: "at.metalab.smart");
            }
        }
      }
    }
    log("Connection closed.", name: "at.metalab.smart");
    // TODO: reconnect
  }

  Future<Map<String, dynamic>?> sendCommand(
      String type, Map<String, dynamic> command) async {
    var message = Map.from(command);
    message["type"] = type;
    message["id"] = _messageId;
    var completer = Completer();
    _messageListeners[_messageId] = completer;
    _messageId++;
    log("Send message: $message", name: "at.metalab.smart");
    _channel?.sink.add(jsonEncode(message));
    _pingTimer?.reset();
    return await completer.future;
  }

  Future<int?> subscribeTrigger(String platform,
      Map<String, dynamic> conditions, Function listener) async {
    var trigger = Map.from(conditions);
    trigger["platform"] = platform;
    var id = _messageId;
    var response = await sendCommand("subscribe_trigger", {
      "trigger": trigger,
    });
    log("subscribeTrigger response: $response", name: "at.metalab.smart");
    if (response != null && response["success"]) {
      _triggerSubscribers[id] = listener;
      return id;
    }
    return null;
  }

  Future<bool> unsubscribeTrigger(int id) async {
    var response = await sendCommand("unsubscribe_trigger", {
      "subscription": id,
    });
    _triggerSubscribers.remove(id);
    if (response != null) {
      return response["success"] ?? false;
    }
    return false;
  }

  Future<int?> subscribeEvent(String type, Function listener) async {
    var id = _messageId;
    var response = await sendCommand("subscribe_events", {
      "event_type": type,
    });
    log("subscribeEvent response: $response", name: "at.metalab.smart");
    if (response != null && response["success"]) {
      _eventSubscribers[id] = listener;
      return id;
    }
    return null;
  }

  Future<bool> unsubscribeEvent(int id) async {
    var response = await sendCommand("unsubscribe_event", {
      "subscription": id,
    });
    _eventSubscribers.remove(id);
    if (response != null) {
      return response["success"] ?? false;
    }
    return false;
  }
}
