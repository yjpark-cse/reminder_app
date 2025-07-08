import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyDataModel1 with ChangeNotifier {
  int count = 0;
  String data = "Mobile";
  void increment() {
    count++;
    notifyListeners();
  }

  void toggleText() {
    data = data == "Mobile" ? "Programming" : "Mobile";
    notifyListeners();
  }
}

class MyDataModel2 with ChangeNotifier {
  String text = "Hello";

  void toggleText() {
    text = text == "Hello" ? "World" : "Hello";
    notifyListeners();
  }
}

void main() {
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider<MyDataModel1>.value(value: MyDataModel1()),
      ChangeNotifierProvider<MyDataModel2>.value(value: MyDataModel2()),
      StreamProvider<int>(create: (context) => streamFun(), initialData: 0)

    ],child: MyApp()),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    FirstScreen(),
    SecondScreen(),
    ThirdScreen(),
    FourthScreen(),
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
          title: Text('Provider Package'),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Fourth',
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

class FirstScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SubWidget();
  }
}

class SubWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var mydatamodel1 = Provider.of<MyDataModel1>(context);
    var mydatamodel2 = Provider.of<MyDataModel2>(context);
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Counter : ${mydatamodel1.count}'),
            Text('String : ${mydatamodel2.text}'),
          ],
        ),
      ),
    );
  }
}

Stream<int> streamFun() async*{
  for(int i = 1; i<100; i++){
    await Future.delayed(Duration(seconds:1));
    yield i;
  }
}

class SecondScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<int>(
          create: (context) => streamFun(), initialData: 0)
      ],
      child: SubWidgetS(),
    );
  }
}

class SubWidgetS extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var streamState = Provider.of<int>(context);
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Stream : ${streamState}'),
          ],
        ),
      ),
    );
  }
}

class ThirdScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HomeWidget();
  }
}

class HomeWidget extends StatelessWidget {
  @override build(BuildContext context) {
    return Container(
        child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Consumer2<MyDataModel1, MyDataModel2>(
                  builder: (context, model1, model2, child) {
                    return SubWidget1(model1, model2, child);
                  },
                  child: SubWidget2(),
                ),
                Column(
                  children:[
                    ElevatedButton(
                      onPressed: () {
                        var model1 = Provider.of<MyDataModel1>(context, listen: false);
                        model1.increment();
                      },
                      child: Text('Count Increment'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        var model2 = Provider.of<MyDataModel2>(context, listen: false);
                        model2.toggleText();
                      },
                      child: Text('Toggle Text'),
                    ),
                  ],
                )
              ],
            )
        )
    );
  }
}

class SubWidget1 extends StatelessWidget {
  MyDataModel1 model1; MyDataModel2 model2; Widget? child;
  SubWidget1(this.model1, this.model2, this.child);
  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.green,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'I am SubWidget1',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            ),
            Text(
              'Counter : ${model1.count}',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            ),
            Text(
              'String : ${model2.text}',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            ),
            child!
          ],
        ));
  }
}

class SubWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print("SubWidget2 build...");
    return Container(
      color: Colors.deepPurpleAccent,
      padding: EdgeInsets.all(20),
      child: Text(
        'I am SubWidget2 ',
        style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
        ),
      ),
    );
  }
}

class FourthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HomeWidgetF();
  }
}

class HomeWidgetF extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Selector<MyDataModel1, String>(
              builder: (context, data, child) {
                return Container(
                  color: Colors.cyan,
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Selector String : ${data}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
              selector: (context, model) => model.data,
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    var model1 =
                        Provider.of<MyDataModel1>(context, listen: false);
                    model1.toggleText();
                  },
                  child: Text('Toggle Text'),
                )
              ]
            )
          ]
        )
      )
    );
  }
}
