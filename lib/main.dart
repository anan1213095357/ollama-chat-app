import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const OllamaChatApp());
}

class OllamaChatApp extends StatelessWidget {
  const OllamaChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ollama Chat App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.cyanAccent,
        fontFamily: 'Orbitron',
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.cyanAccent),
          bodyMedium: TextStyle(color: Colors.cyanAccent),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
          primary: Colors.cyanAccent,
          secondary: Colors.pinkAccent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.cyanAccent),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.pinkAccent),
          ),
          labelStyle: TextStyle(color: Colors.cyanAccent),
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      home: NewChatScreen(),
    );
  }
}

class Message {
  String text;
  final String sender;
  final String role;

  Message({required this.text, required this.sender, required this.role});
}

class NewChatScreen extends StatefulWidget {
  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _urlController =
      TextEditingController(text: "http://sanyouhe.cloud:11434");
  String _selectedModel = 'qwen2.5:7b';
  List<String> _models = [
    'qwen2.5:7b',
    'qwen2.5:3b',
  ];

  void _startChat() {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter Ollama s URL')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          ollamaUrl: url,
          modelName: _selectedModel,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required String hint}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.cyanAccent),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.black,
      value: _selectedModel,
      items: _models.map((model) {
        return DropdownMenuItem(
          value: model,
          child: Text(
            model,
            style: TextStyle(color: Colors.cyanAccent),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedModel = value!;
        });
      },
      decoration: InputDecoration(
        labelText: 'Select Model',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 设置背景为黑色
      appBar: AppBar(
        title: Text('New Chat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(
              controller: _urlController,
              label: 'Ollama URL',
              hint: 'http://sanyouhe.cloud:11434',
            ),
            SizedBox(height: 20),
            _buildDropdown(),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.black,
              ),
              child: Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String ollamaUrl;
  final String modelName;

  ChatScreen({required this.ollamaUrl, required this.modelName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.insert(0, Message(text: text, sender: 'you', role: 'user'));
      _isLoading = true;
    });

    _getBotResponse();
  }

  Future<void> _getBotResponse() async {
    try {
      List<Map<String, String>> messages = _messages
          .map((message) => {'role': message.role, 'content': message.text})
          .toList()
          .reversed
          .toList();

      var requestBody = jsonEncode({
        "model": widget.modelName,
        "messages": messages,
      });

      print("Send：${widget.ollamaUrl}/api/chat");
      print("Send：$requestBody");

      var client = http.Client();
      var request =
          http.Request('POST', Uri.parse('${widget.ollamaUrl}/api/chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = requestBody;

      var response = await client.send(request);

      if (response.statusCode == 200) {
        var decodedResponse = utf8.decoder.bind(response.stream);
        String assistantContent = '';

        setState(() {
          _messages.insert(
              0, Message(text: '', sender: 'Ollama', role: 'assistant'));
        });

        await for (var chunk in decodedResponse.transform(const LineSplitter())) {
          print("Received chunk: $chunk");
          var data = jsonDecode(chunk);

          if (data.containsKey('message')) {
            String content = data['message']['content'];
            assistantContent += content;
            setState(() {
              _messages[0].text = assistantContent;
            });
          }

          if (data.containsKey('done') && data['done'] == true) {
            setState(() {
              _isLoading = false;
            });
            break;
          }
        }

        client.close();
      } else {
        setState(() {
          _messages.insert(
              0,
              Message(
                  text: "The ollama replied incorrectly, please try again later.",
                  sender: 'ollama',
                  role: 'assistant'));
          _isLoading = false;
        });
        client.close();
      }
    } catch (e) {
      print("error$e");
      setState(() {
        _messages.insert(
            0,
            Message(
                text: "Request failed, please check network connection.", 
                sender: 'ollama', role: 'assistant'));
        _isLoading = false;
      });
    }
  }

  Widget _buildMessage(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.pinkAccent,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.pinkAccent.withOpacity(0.2)
                    : Colors.cyanAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? Colors.pinkAccent : Colors.cyanAccent,
                ),
              ),
              padding: EdgeInsets.all(10),
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLoadingIndicator() {
    return _isLoading
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
            ),
          )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 设置背景为黑色
      appBar: AppBar(
        title: Text('Chat with Ollama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => NewChatScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                Message message = _messages[index];
                bool isMe = message.sender == 'you';
                return _buildMessage(message, isMe);
              },
            ),
          ),
          _buildLoadingIndicator(),
          Divider(height: 1, color: Colors.cyanAccent),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: Colors.cyanAccent),
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.pinkAccent),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
