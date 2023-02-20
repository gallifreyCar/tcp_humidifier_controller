import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isCanSend = true;
  bool isConnected = false;
  late Socket socket;

  //主机地址和端口
  static const defaultHost = '192.168.0.251';
  static const defaultPort = 1234;
  String host = defaultHost;
  int port = defaultPort;

  //要接收的下位机数据
  String receivedData = '';
  int temperature = 0;
  int humidity = 0;
  int waterLevel = 0;
  int humidityWarning = 1;
  int waterLevelWarning = 1;
  //要发送到下位机数据
  SfRangeValues _humidityValues = const SfRangeValues(30.0, 60.0);
  SfRangeValues _waterLevelValues = const SfRangeValues(60.0, 90.0);
  double _steeringGearAngleValue = 0.0;
  bool isManual = true;
  bool isRun = true;

  //发送信息到下位机
  Future<void> sendToPeer(String data) async {
    isCanSend = false;
    socket.write(data);
    await socket.flush().onError((error, stackTrace) => {debugPrint(error.toString())});
    isCanSend = true;
  }

  //监听数据流
  Future<void> dataListener() async {
    socket.listen((event) {
      // print(event);
      String data = utf8.decode(event);

      setState(() {
        receivedData = data;
        if (receivedData != '') {
          temperature = int.parse(receivedData.split(',')[0]);
          humidity = int.parse(receivedData.split(',')[1]);
          waterLevel = int.parse(receivedData.split(',')[2]);
          humidityWarning = int.parse(receivedData.split(',')[3]);
          waterLevelWarning = int.parse(receivedData.split(',')[4]);
        }
      });
    });
  }

  //建立tcp链接
  void tcpConnect() async {
    socket = await Socket.connect(host, port);
    setState(() {
      isConnected = true;
    });
    dataListener();
  }

  //关闭tcp链接
  void tcpCloseConnect() async {
    await socket.close();
    setState(() {
      isConnected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('加湿器TCP控制器'),
      ),
      body: Column(
        children: [
          Row(),
          _buildInputField(),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: !isConnected ? tcpConnect : tcpCloseConnect,
              child: !isConnected ? const Text('建立连接') : const Text('断开连接')),
          _buildRougeSliver(const Icon(Icons.hot_tub), 'hum'),
          _buildRougeSliver(const Icon(Icons.water_sharp), 'water'),
          _buildNormalSliver(),
          const SizedBox(height: 20),
          _buildModeSwitcher(isManual ? '运行模式：手动' : '运行模式：自动', 'mode'),
          _buildModeSwitcher(
              !isManual
                  ? '自动设置：自动'
                  : isRun
                      ? '手动设置：运行'
                      : '手动设置：关闭',
              'Run'),
          Column(
            children: [
              _buildTextRow("温度：", Icons.sunny, Colors.black, temperature, ' °C'),
              _buildTextRow("湿度：", Icons.hot_tub, Colors.black, temperature, ' %RH'),
              _buildTextRow("水位：", Icons.water_sharp, Colors.black, temperature, ' m'),
            ],
          ),
          _buildSafeTextRow(
              humidityWarning == 1
                  ? "湿度正常"
                  : humidityWarning == 2
                      ? "湿度过高"
                      : "湿度过低",
              humidityWarning),
          _buildSafeTextRow(waterLevelWarning == 1 ? "水位安全" : "水位异常", waterLevelWarning),
        ],
      ),
    );
  }

  //输入框ui
  Widget _buildInputField() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "主机地址",
              hintText: "例：192.168.0.251",
            ),
            onChanged: (e) => {
              setState(() {
                host = e;
              })
            },
          ),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "端口", hintText: "例：1234"),
            onChanged: (e) => {
              setState(() {
                port = int.parse(e);
              })
            },
          ),
        ],
      ),
    );
  }

  //上下限设置ui
  Widget _buildRougeSliver(Icon icon, String tips) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        SizedBox(
          width: 300,
          child: SfRangeSlider(
            values: tips == 'hum' ? _humidityValues : _waterLevelValues,
            min: 0,
            max: 150,
            interval: 30,
            showLabels: true,
            showTicks: true,
            enableTooltip: true,
            enableIntervalSelection: true,
            minorTicksPerInterval: 1,
            onChanged: (SfRangeValues value) {
              setState(() {
                tips == 'hum' ? _humidityValues = value : _waterLevelValues = value;
              });
            },
            onChangeEnd: (dynamic value) {
              if (isConnected) {
                tips == 'hum'
                    ? sendToPeer('$tips:${_humidityValues.start.toInt()},${_humidityValues.end.toInt()}\r\n')
                    : sendToPeer('$tips:${_waterLevelValues.start.toInt()},${_waterLevelValues.end.toInt()}\r\n');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNormalSliver() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.change_circle_rounded),
        SizedBox(
          width: 300,
          child: SfSlider(
            min: 0.0,
            max: 180.0,
            value: _steeringGearAngleValue,
            interval: 30,
            showTicks: true,
            showLabels: true,
            enableTooltip: true,
            minorTicksPerInterval: 1,
            onChanged: (dynamic e) {
              setState(() {
                _steeringGearAngleValue = e;
              });
            },
            onChangeEnd: (dynamic value) {
              if (isConnected) {
                sendToPeer('servo:${value.toInt()}\r\n');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitcher(String text, String myValue) {
    return SizedBox(
      height: 45,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 40),
          Transform.scale(
              scale: 1.7,
              child: Switch(
                  value: myValue == 'mode' ? isManual : isRun,
                  onChanged: (value) {
                    if (myValue == 'mode') {
                      setState(() {
                        isManual = value;
                      });
                      if (isConnected) {
                        isManual == true ? sendToPeer('mode:1\r\n') : sendToPeer('mode:0\r\n');
                      }
                    } else {
                      setState(() {
                        isRun = value;
                      });
                      if (isConnected) {
                        isRun == true ? sendToPeer('key:1\r\n') : sendToPeer('key:0\r\n');
                      }
                    }
                  })),
        ],
      ),
    );
  }

  //收到的信息行ui
  Widget _buildTextRow(String text, IconData icon, Color color, int data, String unit) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return Column(
      children: [
        const SizedBox(height: 5),
        Row(
          children: [
            const SizedBox(width: 150),
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(width: 5),
            Text(text, style: textStyle),
            Text(data.toString() + unit, style: textStyle),
          ],
        ),
      ],
    );
  }

  //收到安全警告ui
  Widget _buildSafeTextRow(String text, int safe) {
    final textStyle = TextStyle(color: safe == 1 ? Colors.green : Colors.redAccent, fontSize: 18);
    return Column(
      children: [
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              safe == 1 ? Icons.safety_check : Icons.warning,
              color: safe == 1 ? Colors.green : Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 5),
            Text(text, style: textStyle),
            // Text(ascii.decode(utf8.decode(receivedData))),
          ],
        ),
      ],
    );
  }
}
