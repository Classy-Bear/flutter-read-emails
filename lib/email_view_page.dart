import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EmailViewPage extends StatefulWidget {
  final String htmlContent;
  final String? subject;

  const EmailViewPage({super.key, required this.htmlContent, this.subject});

  @override
  EmailViewPageState createState() => EmailViewPageState();
}

class EmailViewPageState extends State<EmailViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // You can update a progress indicator here if needed
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    if (widget.htmlContent.isNotEmpty) {
      final String contentBase64 =
          base64Encode(const Utf8Encoder().convert(widget.htmlContent));
      _controller.loadRequest(
          Uri.parse('data:text/html;charset=utf-8;base64,$contentBase64'));
    } else {
      _controller.loadHtmlString('''
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>404 Not Found</title>
            <style>
              body { 
                font-family: Arial, sans-serif; 
                background-color: #f2f2f2; 
                margin: 0; 
                padding: 20px; 
                display: flex; 
                justify-content: center; 
                align-items: center; 
                height: 100vh; 
              }
              .container { 
                text-align: center; 
              }
              h1 { 
                color: #d9534f; 
                font-size: 72px; 
                margin: 0; 
              }
              p { 
                font-size: 24px; 
                color: #555; 
              }
            </style>
          </head>
          <body>
            <div class="container">
              <h1>404</h1>
              <p>Page Not Found</p>
            </div>
          </body>
        </html>
      ''');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject ?? 'Email Content'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
