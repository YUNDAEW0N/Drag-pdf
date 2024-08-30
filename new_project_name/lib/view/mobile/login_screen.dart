import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drag_pdf/api/loginvalidation.dart';
import 'package:go_router/go_router.dart';

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
  bool _isBranchCodeValid = false; // 지점 코드의 유효성을 추적
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
      _isBranchCodeValid = false; // 유효성을 초기화
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
          _isBranchCodeValid = true; // 유효한 지점 코드로 설정
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
    if (_isBranchCodeValid) {
      context.go('/home_screen_mobile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인 페이지',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'DIGITAL JOY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _branchCodeController,
                      decoration: InputDecoration(
                        labelText: '지점코드',
                        errorText: _branchCodeError,
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      validator: _validateBranchCode,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _checkBranchCode(_branchCodeController.text),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _branchName ?? '인증하기', // 인증 성공 시 지점명을 표시
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isBranchCodeValid
                          ? _login
                          : null, // 지점 코드가 유효할 때만 활성화
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: _isBranchCodeValid
                            ? Colors.green[200]
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
