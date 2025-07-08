import 'dart:async';
import 'package:flutter/material.dart';

void main(){
  runApp(MyApp());
}

Future<int> funA() {
  return Future.delayed(Duration(seconds: 3), () {  // 3초 뒤에 반환
    return 0;
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => OneScreen(),
        '/two': (context) => TwoScreen(),
        '/three': (context) => ThreeScreen(),
      },
    );
  }
}

class User {
  final String name;
  final String phone;

  User({required this.name, required this.phone});
}

class OneScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow,
      body: Center(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TwoScreen()),
            );
          },
          child: Container(
            margin: EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                  image: AssetImage('images/cat.png'), fit: BoxFit.cover),
            ),
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }
}

class TwoScreen extends StatelessWidget {
  final List<User> users = [
    User(name: '홍길동', phone: '010-1111-1111'),
    User(name: '김철수', phone: '010-2222-2222'),
    User(name: '이영희', phone: '010-3333-3333'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('친구 목록'),
      ),
      body: Center(
        child: FutureBuilder( //FutureBuilder를 이용하여 3초 대기 후 친구 목록을 화면에 나타냄
          future: funA(),
          builder: (context, snapshot) {
            if(snapshot.hasData) {
              return Center(
                child: ListView.separated(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: AssetImage('images/cat.png'),
                      ),
                      title: Text(users[index].name),
                      subtitle: Text(users[index].phone),
                      trailing: Icon(Icons.more_vert),
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/three',
                          arguments: {
                            "arg1": users[index].name,
                          },
                        );
                        if(result is String) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("메시지 내용"),
                                content: Text(result),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("확인"))
                                ],
                              );
                            },
                          );
                        }
                      },
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(
                      height: 2,
                      color: Colors.black,
                    );
                  },
                ),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(),
                  ),
                  Text(
                    'Waiting...',
                    style: TextStyle(color: Colors.black, fontSize: 20),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ThreeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as
    Map<String, Object>?;

    final arg1 = args?["arg1"] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text('$arg1에게 메시지 보내기'),
      ),
      body: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  TestState createState() => TestState();
}

class TestState extends State<TestScreen> {
  final controller = TextEditingController();
  int textCounter = 0;
  int count = 3;
  Timer? timer;

  _printValue() {
    setState(() {
      textCounter = controller.text.length;
    });
  }

  void Count() {
    setState(() {
      count = 3;
    });

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        count--;
      });

      if (count == 0) {
        timer.cancel();
        setState(() {
        });
        sendMessage();
      }
    });
  }

  void sendMessage() {
    Navigator.pop(context, controller.text);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_printValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('TextField Test'),
      TextField(
        style: TextStyle(fontSize: 15.0),
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Data',
          prefixIcon: Icon(Icons.input),
          border: OutlineInputBorder(),
          helperText: "메시지를 입력하세요",
        ),
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        minLines: 2,
        maxLines: 5,
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context, controller.text);},
        child: Text('메시지 전송 및 돌아가기'),
      ),
      ElevatedButton(
        onPressed: () {Count();},
        child: Text('예약 메시지 발송 ($count 초 후 전송)'),
      ),
    ],);
  }
}