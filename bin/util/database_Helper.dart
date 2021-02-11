import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path/path.dart';

class AwaitingTopUp {
  String number;
  int amount;

  AwaitingTopUp({this.amount, this.number});

  AwaitingTopUp.fromMap(Map<String, dynamic> data) {
    amount = data['amount'];
    number = data['number'];
  }

  Map<String, dynamic> toMap() => {'amount': amount, 'number': number};
}

class MyUser {
  // named MyUser to avoid naming conflict5 with Telegram User Object
  String pin, name;
  int max = 500, usedToday = 0;
  MyUser(this.pin, this.name);

  MyUser.fromMap(dynamic data) {
    name = data['name'];
    pin = data['pin'];
    usedToday = data['usedToday'];
    max = data['max'];
  }

  Map<String, dynamic> toMap() =>
      {'name': name, 'pin': pin, 'max': max, 'usedToday': usedToday};
}

final keeper = StoreRef.main();
