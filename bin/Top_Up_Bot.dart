import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

import 'util/database_Helper.dart';
import 'util/sensitive_info.dart' as private;

final BOT_TOKEN = private.TELEGRAM_BOT_TOKEN;
final bot = Telegram(BOT_TOKEN);
final keeper = StoreRef.main();
ReplyKeyboardMarkup showMainKeyboard = ReplyKeyboardMarkup(keyboard: [
  [KeyboardButton(text: "📲 Top-Up A Number")]
], resize_keyboard: true);
Database userDB;
Database awaitingTopUpDB;
Database authenticator;
TeleDart tele;
final RELOADLY_AUDIENCE = 'https://topups-sandbox.reloadly.com';

void main(List<String> arguments) {
  initializeBot();

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

Future onMessageReceived(TeleDartMessage event) async {
  //await event.reply("hshs");
  dynamic user = await getDetailFromDB(userDB, event.from.id);

  // only goes through this (if statement) if user has nt been registered
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
      event.reply(private.invalidToken);
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
  }
}

Future onCommandReceived(TeleDartMessage event) async {
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
    keeper.record(event.from.id).add(userDB, MyUser(pin).toMap());

// {} []
