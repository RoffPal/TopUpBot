import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

import 'util/database_Helper.dart';
import 'util/sensitive_info.dart' as private;
import 'util/process_top_up.dart' as pay;

final BOT_TOKEN = private.TELEGRAM_BOT_TOKEN;
final bot = Telegram(BOT_TOKEN);
final keeper = StoreRef.main();
final cancel = "❌ Cancel";
ReplyKeyboardMarkup showMainKeyboard = ReplyKeyboardMarkup(keyboard: [
  [KeyboardButton(text: private.topUpButton)]
], resize_keyboard: true);
Database userDB;
Database awaitingTopUpDB;
Database authenticator;
TeleDart tele;
final RELOADLY_AUDIENCE = 'https://topups-sandbox.reloadly.com';

void main(List<String> arguments) {
  initializeBot();

  tele.onPhoneNumber().listen((event) async {
    onNumberReceived(event);
  });

  tele.onCommand().listen((event) {
    onCommandReceived(event);
  });

  tele.onMessage().listen((event) {
    print("go5t ${event.text}");
    onMessageReceived(event);
  });
}

void initializeBot() {
  tele = TeleDart(bot, Event());

  tele.start().then((me) {
    print('${me.username} is initialised');
  });

  databaseFactoryIo
      .openDatabase(join('bin/util/Database', 'Users.db'))
      .then((value) {
    userDB = value;
  });
  databaseFactoryIo
      .openDatabase(join('bin/util/Database', 'AwaitingTopUp.db'))
      .then((value) {
    awaitingTopUpDB = value;
  });

  databaseFactoryIo
      .openDatabase(join('bin/util/Database', 'Authenticate.db'))
      .then((value) {
    authenticator = value;
  });
}

Future<dynamic> getDetailFromDB(Database db, dynamic key) =>
    keeper.record(key).get(db);

Future deleteFromDB(Database db, dynamic key) => keeper.record(key).delete(db);

Future updateDB(Database db, dynamic key, dynamic newValue) =>
    keeper.record(key).update(db, newValue);

Future onNumberReceived(TeleDartMessage event) async {
  dynamic details = await getDetailFromDB(awaitingTopUpDB, event.from.id);
  if (details != null) {
    updateDB(awaitingTopUpDB, event.from.id, {'number': event.text});
    event.reply(private.ask4amount, parse_mode: 'markdown');
  }
}

Future onMessageReceived(TeleDartMessage event) async {
  dynamic user = await getDetailFromDB(userDB, event.from.id);

  // only goes through this (if statement 1st condition) if user has nt been registered
  if (user == null) {
    // Since the User has to enter both auth token and pin (for verifying transactions) before registration caused all this
    //  wahala below
    dynamic auth = await getDetailFromDB(authenticator, event.text) ??
        await getDetailFromDB(
            authenticator,
            event.from
                .id); // searches for User's token with the text entered by user

    print("This is auth: $auth");
    if (auth == null)
      event.reply(private.invalidToken(event.text), parse_mode: 'markdown');
    else if (auth is Map) {
      if (event.text == "✅ Confirm") {
        registerUser(event, auth["pin"]);
        bot.deleteMessage(event.from.id, auth["id"]);
        event.reply(private.successfulRegistration,
            reply_markup: showMainKeyboard);
      } else if (event.text == "🗝 Change Pin") {
        updateDB(authenticator, event.from.id, 'pin');
        event.reply(private.ask4pin,
            parse_mode: 'markdown',
            reply_markup: ReplyKeyboardRemove(remove_keyboard: true));
        bot.deleteMessage(event.from.id, auth["id"]);
      }
    } else if (auth == 'pin') {
      // adds new authenticator to allow user confirm pin
      updateDB(
          authenticator, event.from.id, {'pin': 'pin', 'id': event.message_id});
      event.reply(private.confirmPin,
          parse_mode: 'markdown',
          reply_markup: ReplyKeyboardMarkup(keyboard: [
            [
              KeyboardButton(text: '✅ Confirm'),
              KeyboardButton(text: '🗝 Change Pin')
            ]
          ], resize_keyboard: true));
    } else {
      deleteFromDB(authenticator, event.text);

      // adds new authenticator to allow user input pin on next message
      keeper.record(event.from.id).add(authenticator, 'pin');
      event.reply(private.ask4pin, parse_mode: 'markdown');
    }
  } else {
    dynamic topUp = await getDetailFromDB(awaitingTopUpDB, event.from.id);
    if (topUp != null) {
      dealWithAwaitingTopUp(event, topUp);
    } else if (event.text == private.topUpButton) {
      keeper.record(event.from.id).add(awaitingTopUpDB, "awaiting");
      event.reply(private.ask4NumberToTopUp,
          reply_markup: ReplyKeyboardMarkup(keyboard: [
            [KeyboardButton(text: cancel)]
          ], resize_keyboard: true));
    }
  }
}

Future onCommandReceived(TeleDartMessage event) async {
  print('got ${event.text}');
  if (event.text.contains(private.setNewAuth) &&
      event.text.split(' ').length > 1) {
    bot.deleteMessage(event.from.id, event.message_id);
    keeper
        .record(event.text.split(' ')[1])
        .add(authenticator, event.text.split(' ')[1])
        .then((value) {
      if (value)
        event.reply("Successfully added");
      else
        event.reply("Failed to add");
    });
    return;
  }

  dynamic topUp = await getDetailFromDB(awaitingTopUpDB, event.from.id);

  if (topUp != null) {
  }

// On_Start Command
  else if (event.text.contains('start')) {
    print('UserID: ${event.from.id} And chatID: ${event.chat.id}');
    if (await getDetailFromDB(userDB, event.from.id) == null)
      event.reply(private.welcomeMsg, parse_mode: 'markdown');
  }
}

Future registerUser(TeleDartMessage event, String pin) =>
    keeper.record(event.from.id).add(
        userDB,
        MyUser(pin, "${event.from.first_name} ${event.from.last_name}")
            .toMap());

Future dealWithAwaitingTopUp(TeleDartMessage event, dynamic topUp) async {
  if (topUp == 'awaiting')
    event.reply('Please enter a valid mobile number!');
  else if (topUp['amount'] == null) {
    try {
      double amount = double.parse(event.text);
      final user = MyUser.fromMap(await getDetailFromDB(userDB, event.from.id));

      if (amount + user.usedToday > user.max)
        event.reply(private.overUsedCredit(user), parse_mode: 'markdown');
      else
        pay.Airtime.determineOperator(event, topUp);
    } catch (FormatException) {
      event.reply('Please input a valid amount!');
    }
  }
}

// {} []
