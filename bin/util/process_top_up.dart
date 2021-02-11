import 'dart:convert';

import 'package:teledart/model.dart';

import 'sensitive_info.dart' as private;
import 'package:http/http.dart' as http;
import '../Top_Up_Bot.dart' as main;

final RELOADLY_AUDIENCE = "https://topups-sandbox.reloadly.com";

class Airtime {
  static int expiry, timeTokenGenerated;
  static String token;
  static Map<String, String> headers;
  static String dailCode = '234';

  static String purifyNumber(String number) => (number.length == 11)
      ? dailCode.padRight(dailCode.length + 1, number.substring(1))
      : number;

  static Future<void> getToken() {
    Map<String, String> header = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    dynamic body = "{\"client_id\": \"${private.RELOADLY_CLIENT_ID}\"," +
        "\"client_secret\": \"${private.RELOADLY_API_SECRET}\"," +
        "\"grant_type\": \"client_credentials\",\"audience\": \"${RELOADLY_AUDIENCE}\"\n}";

    if (token == null ||
        DateTime.now().millisecondsSinceEpoch - timeTokenGenerated >= expiry)
      return http
          .post("https://auth.reloadly.com/oauth/token",
              headers: header, body: body)
          .then((value) {
        token = JsonDecoder().convert(value.body)["access_token"];
        expiry = JsonDecoder().convert(value.body)["expires_in"];
        timeTokenGenerated = DateTime.now().millisecondsSinceEpoch;
        headers = {
          'Accept': 'application/com.reloadly.topups-v1+json',
          'Authorization': 'Bearer $token'
        };
      });
  }

  Future<dynamic> getBalance() async {
    await getToken();
    return http
        .get("$RELOADLY_AUDIENCE/accounts/balance", headers: headers)
        .then((value) => JsonDecoder().convert(value.body));
  }

  static Future<void> determineOperator(
      TeleDartMessage event, dynamic details) async {
    await getToken();
    http
        .get(
            '$RELOADLY_AUDIENCE/operators/auto-detect/phone/${details['number']}/countries/NG?&includeBundles=false',
            headers: headers)
        .then((value) async {
      dynamic air = JsonDecoder().convert(value.body);
      print(air);
      if (air.keys.contains('errorCode'))
        event.reply(air['message']);
      else {
        event.reply(
            'Are you sure you want to send *"${event.text}"* of *${air["name"].split(" ")[0]} Top Up* to *${details["number"]}*?',
            reply_markup: ReplyKeyboardMarkup(keyboard: [
              [KeyboardButton(text: '✅ Confirm')],
              [KeyboardButton(text: ''), KeyboardButton(text: main.cancel)]
            ], resize_keyboard: true),
            parse_mode: 'markdown');
        main.updateDB(main.awaitingTopUpDB, event.from.id, {
          'amount': event.text,
          'operatorID': air['id']
        }); // Adds withdrawal address to the awaiting database
      }
    });
  }

  static Future<void> topUpNumber(
      TeleDartMessage event, dynamic details) async {
    await getToken();
    // To finalize Top Up
    String number = purifyNumber(details['number']);

    dynamic header = {
      'Content-Type': 'application/json',
      'Accept': 'application/com.reloadly.topups-v1+json',
      'Authorization': 'Bearer $token'
    };

    dynamic body = '''
{
  "recipientPhone": {
    "countryCode": "NG",
    "number": $number
  },
  "senderPhone": {
    "countryCode": "US",
    "number": "234836791612" 
  },
  "operatorId": ${details['operatorID']},
  "amount": ${details['amount']}
}''';

    http
        .post('$RELOADLY_AUDIENCE/topups', headers: header, body: body)
        .then((value) {
      main.deleteFromDB(main.authenticator, event.from.id);

      dynamic response = JsonDecoder().convert(value.body);
      if (response.keys.contains('errorCode'))
        event.reply('${response['message']}\n\nPlease retry again.',
            reply_markup: main.showMainKeyboard);
      else
        event.reply(value.body,
            parse_mode: 'markdown', reply_markup: main.showMainKeyboard);
    });
  }
}
