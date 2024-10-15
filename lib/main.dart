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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: NewChatScreen(),
    );
  }
}

class Message {
  String text;
  final String sender;
  final String role; // 添加角色属性，用于请求

  Message({required this.text, required this.sender, required this.role});
}

// 新增的 NewChatScreen，用于输入 URL 和选择模型名称
class NewChatScreen extends StatefulWidget {
  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _urlController = TextEditingController(text: "http://sanyouhe.cloud:11434");
  String _selectedModel = 'qwen2.5:7b'; // 默认模型
  List<String> _models = [
    'qwen2.5:7b',
    'qwen2.5:3b',
  ];

  void _startChat() {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入 Ollama 的 URL')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新的聊天'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Ollama URL',
                hintText: '例如：http://sanyouhe.cloud:11434',
              ),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              items: _models.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModel = value!;
                });
              },
              decoration: InputDecoration(
                labelText: '选择模型',
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startChat,
              child: Text('开始聊天'),
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
      // 添加用户消息到列表
      _messages.insert(0, Message(text: text, sender: '你', role: 'user'));
      _isLoading = true;
    });

    _getBotResponse();
  }

  Future<void> _getBotResponse() async {
    try {
      // 构建请求中的 messages 列表，包括历史记录
      List<Map<String, String>> messages = _messages
          .map((message) => {'role': message.role, 'content': message.text})
          .toList()
          .reversed
          .toList(); // 需要反转列表，因为我们是从最新的消息开始存储的

      // 构建请求体
      var requestBody = jsonEncode({
        "model": widget.modelName,
        "messages": messages,
      });

      // 打印请求信息
      print("发送请求到：${widget.ollamaUrl}/api/chat");
      print("请求体：$requestBody");

      var client = http.Client();
      var request = http.Request('POST', Uri.parse('${widget.ollamaUrl}/api/chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = requestBody;

      var response = await client.send(request);

      // 检查响应状态码
      if (response.statusCode == 200) {
        // 流式读取响应
        var decodedResponse = utf8.decoder.bind(response.stream);
        String assistantContent = '';

        // 初始化机器人的消息
        setState(() {
          _messages.insert(0, Message(text: '', sender: '机器人', role: 'assistant'));
        });

        await for (var chunk in decodedResponse.transform(const LineSplitter())) {
          print("Received chunk: $chunk");
          var data = jsonDecode(chunk);

          // 检查是否有 message 字段
          if (data.containsKey('message')) {
            String content = data['message']['content'];
            assistantContent += content;
            setState(() {
              _messages[0].text = assistantContent;
            });
          }

          // 如果有 done 字段且为 true，表示响应结束
          if (data.containsKey('done') && data['done'] == true) {
            setState(() {
              _isLoading = false;
            });
            break;
          }
        }

        client.close(); // 关闭客户端
      } else {
        setState(() {
          _messages.insert(0, Message(text: "机器人回复出错了，请稍后再试。", sender: '机器人', role: 'assistant'));
          _isLoading = false;
        });
        client.close(); // 关闭客户端
      }
    } catch (e) {
      // 打印异常信息
      print("请求发生异常：$e");
      setState(() {
        _messages.insert(0, Message(text: "请求失败，请检查网络连接。", sender: '机器人', role: 'assistant'));
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
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[100] : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(10),
              child: Text(message.text),
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
            child: CircularProgressIndicator(),
          )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('聊天'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // 返回到新的聊天界面
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
                bool isMe = message.sender == '你';
                return _buildMessage(message, isMe);
              },
            ),
          ),
          //_buildLoadingIndicator(),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration.collapsed(
                      hintText: '发送消息',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
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
