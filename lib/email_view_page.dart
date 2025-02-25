import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EmailViewPage extends StatefulWidget {
  final String htmlContent;
  final String? subject;
  final List<dynamic> attachments;

  const EmailViewPage({
    super.key,
    required this.htmlContent,
    this.subject,
    required this.attachments,
  });

  @override
  EmailViewPageState createState() => EmailViewPageState();
}

class EmailViewPageState extends State<EmailViewPage> {
  late final WebViewController _controller;
  bool isLoading = true;

  String _replaceAttachmentCids(String htmlContent, List<dynamic> attachments) {
    String modifiedContent = htmlContent;
    for (final attachment in attachments) {
      final String filename = attachment['filename'] as String;
      final String downloadUrl = attachment['downloadUrl'] as String;
      modifiedContent =
          modifiedContent.replaceAll("cid:$filename", downloadUrl);
      modifiedContent =
          modifiedContent.replaceAll("'cid:$filename'", "'$downloadUrl'");
      modifiedContent =
          modifiedContent.replaceAll('"cid:$filename"', '"$downloadUrl"');
    }
    return modifiedContent;
  }

  @override
  void initState() {
    super.initState();
    final delegate = NavigationDelegate(
      onPageFinished: (_) {
        if (isLoading) {
          _controller.reload();
          setState(() {
            isLoading = false;
          });
        }
      },
      onNavigationRequest: (_) => NavigationDecision.navigate,
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(delegate);
    if (widget.htmlContent.isNotEmpty) {
      final modifiedHtmlContent = _replaceAttachmentCids(widget.htmlContent, widget.attachments);
      _controller.loadRequest(Uri.dataFromString(
        modifiedHtmlContent,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ));
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
