import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'reminder_main.dart';

showToast(String msg) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0);
}

class AuthWidget extends StatefulWidget {
  @override
  AuthWidgetState createState() => AuthWidgetState();
}

class AuthWidgetState extends State<AuthWidget> {
  final _formKey = GlobalKey<FormState>();

  late String email;
  late String password;
  late String name;
  bool isSignIn = true; // true: login, false: signup

  signIn() async {
    try {
      final value = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (value.user!.emailVerified) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(value.user!.uid)
            .get();

        String fetchedName = doc['name'];

        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => MainHomeScreen(userName: fetchedName)));
      } else {
        showToast('이메일 인증이 필요합니다.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        showToast('존재하지 않는 사용자입니다.');
      } else if (e.code == 'wrong-password') {
        showToast('비밀번호가 틀렸습니다.');
      } else {
        showToast('로그인 오류: ${e.code}');
      }
    }
  }

  signUp() async {
    try {
      final value = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (value.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(value.user!.uid)
            .set({'name': name, 'email': email});

        await value.user!.sendEmailVerification();
        showToast('회원가입 성공! 이메일 인증 후 로그인 해주세요.');

        setState(() {
          isSignIn = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        showToast('약한 비밀번호입니다.');
      } else if (e.code == 'email-already-in-use') {
        showToast('이미 사용 중인 이메일입니다.');
      } else {
        showToast('회원가입 오류: ${e.code}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("로그인 / 회원가입")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: '이메일'),
                validator: (value) =>
                value!.isEmpty ? '이메일을 입력해주세요' : null,
                onSaved: (value) => email = value!,
              ),
              if (!isSignIn)
                TextFormField(
                  decoration: InputDecoration(labelText: '이름'),
                  validator: (value) =>
                  value!.isEmpty ? '이름을 입력해주세요' : null,
                  onSaved: (value) => name = value!,
                ),
              TextFormField(
                decoration: InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                validator: (value) =>
                value!.isEmpty ? '비밀번호를 입력해주세요' : null,
                onSaved: (value) => password = value!,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      isSignIn ? signIn() : signUp();
                    }
                  },
                  child: Text(isSignIn ? '로그인' : '회원가입')),
              SizedBox(height: 10),
              RichText(
                text: TextSpan(
                    text: isSignIn ? "계정이 없으신가요? " : "계정이 있으신가요? ",
                    style: TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                          text: isSignIn ? "회원가입" : "로그인",
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              setState(() {
                                isSignIn = !isSignIn;
                              });
                            })
                    ]),
              )
            ],
          ),
        ),
      ),
    );
  }
}
