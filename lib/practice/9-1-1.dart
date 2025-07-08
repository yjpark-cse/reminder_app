import 'package:flutter/material.dart';

void main(){
  runApp(MyApp());
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

  _printValue() {
    setState(() {
      textCounter = controller.text.length;
    });
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
      Text(''),
      TextField(
        style: TextStyle(fontSize: 15.0),
        controller: controller,
        decoration: InputDecoration(
          labelText: '메시지를 입력하세요.',
          prefixIcon: Icon(Icons.input),
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        minLines: 2,
        maxLines: 5,
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context, controller.text);},
        child: Text('메시지 전송'),
      ),
    ],);
  }
}
