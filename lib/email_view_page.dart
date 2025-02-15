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
    final String contentBase64 =
        base64Encode(const Utf8Encoder().convert(widget.htmlContent));
    _controller.loadRequest(
        Uri.parse('data:text/html;charset=utf-8;base64,$contentBase64'));
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
