import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'nfc_host_card_emulation_platform_interface.dart';
import 'nfc_host_card_emulation_method_channel.dart';

late NfcState _nfcState;
NFCTag? _nfcTag = null; // Holds the NFC tag that is read

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _nfcState = await NfcState.enabled;
  print('NFC State initialized: $_nfcState');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool apduAdded = false;

  final port = 0;
  final data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

  NfcApduCommand? nfcApduCommand;

  @override
  void initState() {
    super.initState();
    print('App initialized');

    // Listen for NFC commands (for emulation)
    NfcHce.stream.listen((command) {
      print('NFC APDU command received: $command');
      setState(() => nfcApduCommand = command);
    });
  }

  Future<void> _readNfcTag() async {
    print('Attempting to read NFC tag...');
    try {
      // Start reading NFC tag
      _nfcTag = await FlutterNfcKit.poll();
      print('NFC tag read successfully: ${_nfcTag?.id}');
      setState(() {
        // After reading, update the UI with the tag's information
      });
    } catch (e) {
      // Handle errors here, e.g., NFC not supported or canceled
      print('Error reading NFC tag: $e');
    } finally {
      // End NFC session
      await FlutterNfcKit.finish();
      print('NFC reading session finished');
    }
  }

  Future<void> _emulateNfcCard() async {
    print('Attempting to emulate NFC card...');
    try {
     /* NFCTag? _nfcTag = null;
      _nfcTag = await FlutterNfcKit.poll();
      if (_nfcTag != null) {
        final cardId = _nfcTag!.id;
        print('NFC tag detected for emulation: $cardId');

        // A000DADADADADA  ---- A0000000000001 */
        await NfcHce.init(
          // aid: Uint8List.fromList([0xA0, 0x00, 0xDA, 0xDA, 0xDA, 0xDA, 0xDA]),
          aid: Uint8List.fromList([0xA0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
          permanentApduResponses: false,
          listenOnlyConfiguredPorts: false,
        );
        print('NFC HCE initialized');

        // Pass the card ID to the APDU response
        final cardId = _nfcTag!.id;
        await NfcHce.addApduResponse(port, cardId.codeUnits);
        print('APDU response added for emulation with card ID: $cardId');
        setState(() => apduAdded = true);
      /* } else {
        print('No NFC tag found for emulation');
      } */
    } catch (e) {
      print('Error during NFC card emulation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _nfcState == NfcState.enabled
        ? Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            'NFC State is ${_nfcState.name}',
            style: const TextStyle(fontSize: 20),
          ),
          if (_nfcTag != null)
            Text(
              'NFC Tag read: ${_nfcTag?.id ?? 'Unknown'}',
              style: const TextStyle(fontSize: 20),
            ),
          ElevatedButton(
            onPressed: _readNfcTag,
            child: const Text('Read NFC Tag'),
          ),
          SizedBox(
            height: 200,
            width: 300,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  apduAdded ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              onPressed: () async {
                if (!apduAdded) {
                  print('Start NFC card emulation button pressed');
                  await _emulateNfcCard();
                } else {
                  print('Stop NFC card emulation button pressed');
                  await NfcHce.removeApduResponse(port);
                  setState(() => apduAdded = false);
                  print('APDU response removed, emulation stopped');
                }
              },
              child: FittedBox(
                child: Text(
                  apduAdded
                      ? 'Stop emulating\n$_nfcTag'
                      : 'Start emulating\n$_nfcTag',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    color: apduAdded ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          if (nfcApduCommand != null)
            Text(
              'Received command on port ${nfcApduCommand!.port}:\n'
                  '${nfcApduCommand!.command}\n'
                  'with data ${nfcApduCommand!.data}',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    )
        : Center(
      child: Text(
        'Oh no...\nNFC is ${_nfcState.name}',
        style: const TextStyle(fontSize: 20),
        textAlign: TextAlign.center,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NFC HCE example app'),
        ),
        body: body,
      ),
    );
  }
}
