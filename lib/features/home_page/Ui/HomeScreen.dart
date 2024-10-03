import 'dart:async'; // Added for Timer
import 'dart:io';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> message = [];
  ChatUser currentuser = ChatUser(id: '0', firstName: "User");
  ChatUser geminiuser = ChatUser(id: '1', firstName: "Gemini", profileImage: "https://th.bing.com/th/id/OIP.AsXti9JBcuEGIODbisEAYwHaEK?w=307&h=180&c=7&r=0&o=5&dpr=1.5&pid=1.7");

  // Track if loading (show typing dots)
  bool isTyping = false;
  String typingDots = "";
  Timer? _typingTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("GEMINI APP"),
      ),
      body: buildUI(),
    );
  }

  Widget buildUI() {
    return Column(
      children: [
        Expanded(
          child: DashChat(
            inputOptions: InputOptions(trailing: [
              IconButton(onPressed: _sendMessageImage, icon: const Icon(Icons.image))
            ]),
            currentUser: currentuser,
            onSend: _sendMessage,
            messages: message,
          ),
        ),
        if (isTyping) Text("Gemini is typing$typingDots")
      ],
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      message = [chatMessage, ...message];
    });

    // Show typing indicator before starting the AI response
    _startTypingIndicator();

    try {
      String question = chatMessage.text;
      List<Uint8List>? images; // Corrected to be a list of Uint8List

      // If there is an image, convert it to Uint8List (binary data)
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }

      // Pass the question and images (if any) to gemini
      gemini.streamGenerateContent(question, images: images).listen(
            (event) {
          // Stop typing indicator when response is received
          _stopTypingIndicator();

          ChatMessage? lastmessage = message.firstOrNull;
          if (lastmessage != null && lastmessage.user == geminiuser) {
            lastmessage = message.removeAt(0);
            String response = event.content?.parts?.fold("", (previous, current) => "$previous ${current.text}") ?? "";
            lastmessage.text += response;
            setState(() {
              message = [lastmessage!, ...message];
            });
          } else {
            String response = event.content?.parts?.fold("", (previous, current) => "$previous ${current.text}") ?? "";
            ChatMessage messages = ChatMessage(user: geminiuser, createdAt: DateTime.now(), text: response);
            setState(() {
              message = [messages, ...message];
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      _stopTypingIndicator(); // Ensure to stop typing indicator in case of error
    }
  }

  void _sendMessageImage() async {
    ImagePicker image = ImagePicker();
    XFile? file = await image.pickImage(source: ImageSource.gallery);
    if (file != null) {
      ChatMessage userChat = ChatMessage(
        user: currentuser,
        createdAt: DateTime.now(),
        text: "Describe this Picture!",
        medias: [
          ChatMedia(url: file.path, fileName: "", type: MediaType.image)
        ],
      );
      _sendMessage(userChat);
    }
  }

  // Method to start the typing indicator
  void _startTypingIndicator() {
    setState(() {
      isTyping = true;
      typingDots = "";
    });

    _typingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        if (typingDots.length >= 3) {
          typingDots = "";
        } else {
          typingDots += ".";
        }
      });
    });
  }

  // Method to stop the typing indicator
  void _stopTypingIndicator() {
    _typingTimer?.cancel();
    setState(() {
      isTyping = false;
      typingDots = "";
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }
}
