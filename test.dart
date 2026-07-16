import 'dart:async';

Future<String> myFunc() async {
  try {
    return 'hello';
  } finally {
    print('finally');
  }
}

void main() async {
  print('before');
  final res = await myFunc();
  print('after: ' + res);
}
