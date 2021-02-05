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
  String pin;
  int max = 500, usedToday = 0;
  MyUser(this.pin);

  MyUser.fromMap(dynamic data) {
    pin = data['pin'];
    usedToday = data['usedToday'];
    max = data['max'];
  }

  Map<String, dynamic> toMap() =>
      {'pin': pin, 'max': max, 'usedToday': usedToday};
}

final keeper = StoreRef.main();
main(List<String> args) async {
  Database authenticator;
  await databaseFactoryIo
      .openDatabase(join('bin/util/Database', 'Authenticate.db'))
      .then((value) {
    authenticator = value;
  });

  keeper.record("key").add(authenticator, "key");
}
