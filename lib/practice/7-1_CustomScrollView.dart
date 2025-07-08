import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
                leading: IconButton(
                  icon: Icon(Icons.expand),
                  onPressed: () {},
                ),
                expandedHeight: 200,
                floating: true,
                pinned: false,
                snap: true,
                elevation: 50,
                backgroundColor: Colors.pink,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                      image: DecorationImage(
                          image: AssetImage('images/signt.png'),
                          fit: BoxFit.fill)
                  ),
                ),
                title: Text('AppBar Title'),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.add_alert),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone),
                    onPressed: () {},
                  ),
                ]),
            SliverFixedExtentList(
              itemExtent: 50,
              delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  return ListTile(
                    title: Text('Hello World Item $index'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
