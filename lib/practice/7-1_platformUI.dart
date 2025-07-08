import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

void main() {
  runApp(platformUI());
}

Widget platformUI() {
  if (Platform.isWindows) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Cupertino Title'),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CupertinoButton(
              onPressed: () {},
              child: Text('click'),
            ),
            Center(
              child: Text('HelloWorld'),
            ),
          ],
        ),
      ),
    );
  } else if (Platform.isAndroid) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Material Title'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {},
              child: Text('click'),
            ),
            Center(
              child: Text('HelloWorld'),
            ),
          ],
        ),
      ),
    );
  } else {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Unknown Device',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
        ),
      ),
    );
  }
}
