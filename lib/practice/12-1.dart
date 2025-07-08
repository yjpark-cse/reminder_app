import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    NativeCallWidget(),
    NativeCallWidget2(),
    NativeCallWidget3(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('Integrating Platforms Example'),
        ),
        body: _widgetOptions[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'First',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business),
              label: 'Second',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'Third',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.amber[800],
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

class NativeCallWidget extends StatefulWidget {
  @override
  NativeCallWidgetState createState() => NativeCallWidgetState();
}

class NativeCallWidgetState extends State<NativeCallWidget> {
  String? resultMessage;
  String? receiveMessage;

  Future<Null> nativeCall() async {
    const channel =
    BasicMessageChannel<String>('myMessageChannel', StringCodec());
    String? result = await channel.send('Hello from Dart');
    setState(() {
      resultMessage = result;
    });
    channel.setMessageHandler((String? message) async {
      setState(() {
        receiveMessage = message;
      });
      return 'Reply from Dart';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.deepPurpleAccent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (<Widget>[
              Text('resultMessage : \n$resultMessage\n', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),),
              Text('receiveMessage : \n$receiveMessage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),),
              ElevatedButton(
                child: Text('native call'),
                onPressed: () {
                  nativeCall();
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class NativeCallWidget2 extends StatefulWidget {
  @override
  NativeCallWidgetState2 createState() => NativeCallWidgetState2();
}

class NativeCallWidgetState2 extends State<NativeCallWidget2> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  String? resultMessage;
  String? receiveMessage;

  Future<Null> nativeCall() async {
    const channel = const MethodChannel('myMethodChannel');

    try {
      String username = usernameController.text;
      String password = passwordController.text;

      var details = {'Username': username, 'Password': password};
      final Map result = await channel.invokeMethod("oneMethod", details);
      setState(() {
        resultMessage = "${result["status"]}";
      });
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'twoMethod':
            setState(() {
              receiveMessage = "${call.arguments}";
            });
            return 'Reply from Dart';
        }
      });
    } on PlatformException catch (e) {
      print("Failed: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.deepPurpleAccent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (<Widget>[
              TextField(
                controller: usernameController,
                style: TextStyle(fontSize: 15.0),
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
                minLines: 1,
                maxLines: 5,
              ),
              TextField(
                controller: passwordController,
                style: TextStyle(fontSize: 15.0),
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
                minLines: 1,
                maxLines: 5,
              ),
              ElevatedButton(
                  child: Text('Login'),
                  onPressed: () {
                    nativeCall();
                  }),
              Text(
                '\nResult : $resultMessage',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                ),
              ),
              Text(
                'Receive Message : \n$receiveMessage',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class NativeCallWidget3 extends StatefulWidget {
  @override
  NativeCallWidgetState3 createState() => NativeCallWidgetState3();
}

class NativeCallWidgetState3 extends State<NativeCallWidget3> {
  String? receiveMessage;

  @override
  void initState() {
    super.initState();
    nativeCall();
  }

  Future<Null> nativeCall() async {
    const channel = EventChannel('eventChannel');
    channel.receiveBroadcastStream().listen((dynamic event) {
      setState(() {
        receiveMessage = '$event';
      });
    }, onError: (dynamic error) {
      print('Received error: ${error.message}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.deepPurpleAccent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (<Widget>[
              Text(
                '$receiveMessage',
                style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}