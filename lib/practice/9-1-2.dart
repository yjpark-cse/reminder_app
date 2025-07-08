import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main(){
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  List items = [];

  onPressClient() async {
    var client = http.Client();
    try {
      http.Response response = await client.get(Uri.parse('https://jsonplaceholder.typicode.com/posts'));
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          items = json.decode(response.body);
        });
      } else {
        print('error......');
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
                expandedHeight: 50,
                floating: true,
                pinned: true,
                snap: true,
                elevation: 50,
                backgroundColor: Colors.yellow,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                      image: DecorationImage(
                          image: AssetImage('images/signt.png'),
                          fit: BoxFit.fill)
                  ),
                ),
                title: Text('Jsonplaceholder Contents'),
                actions: <Widget>[
                  IconButton(
                    onPressed: onPressClient,
                    icon: const Icon(Icons.add),
                  ),
                ]),
            SliverFixedExtentList(
              itemExtent: 80,
              delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  return ListTile(
                      title: Text('${items[index]['id']}'),
                      subtitle: Text('${items[index]['title']}')
                  );
                },
                childCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}