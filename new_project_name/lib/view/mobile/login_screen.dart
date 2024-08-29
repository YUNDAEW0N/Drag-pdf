import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drag_pdf/api/loginvalidation.dart'; // checkBranchCode 함수가 정의된 파일을 import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchCodeController = TextEditingController();
  bool _isLoading = false;
  String? _branchCodeError;
  String? _branchName; // 지점 이름을 저장할 변수
  String affCd = 'SHB'; // 여기에 실제 고객사 코드를 입력

  @override
  void dispose() {
    _branchCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveBranchCode(String branchCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('branchCode', branchCode);
  }

  String? _validateBranchCode(String? value) {
    if (value == null || value.isEmpty) {
      return '지점코드를 입력하세요';
    }
    if (value.length != 4 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return '유효한 4자리 숫자 지점코드를 입력하세요';
    }
    return null;
  }

  Future<void> _checkBranchCode(String branchCode) async {
    setState(() {
      _isLoading = true;
      _branchCodeError = null;
      _branchName = null;
    });

    try {
      final branchName = await checkBranchCode(affCd, branchCode);
      if (branchName == null) {
        setState(() {
          _branchCodeError = '존재하지 않는 지점 코드입니다';
        });
      } else {
        setState(() {
          _branchName = branchName;
        });
        _saveBranchCode(branchCode);
      }
    } catch (e) {
      setState(() {
        _branchCodeError = '지점코드 확인 중 오류가 발생했습니다';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      String branchCode = _branchCodeController.text;
      _checkBranchCode(branchCode).then((_) {
        if (_branchName != null) {
          // 지점 이름이 존재하면 로그인 성공 후 메인 화면으로 이동
          Navigator.pushReplacementNamed(context, '/home_screen_mobile');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _branchCodeController,
                decoration: InputDecoration(
                  labelText: '지점코드',
                  errorText: _branchCodeError,
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: _validateBranchCode,
                onFieldSubmitted: (_) => _login(),
              ),
              if (_branchName != null) ...[
                const SizedBox(height: 10),
                Text('지점 이름: $_branchName',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),
              if (_isLoading) const CircularProgressIndicator(),
              if (!_isLoading)
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('로그인'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
