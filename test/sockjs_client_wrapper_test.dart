@TestOn('browser')
library sockjs_client.test.sockjs_client_test;

import 'dart:async';

import 'package:sockjs_client_wrapper/sockjs_client_wrapper.dart';
import 'package:test/test.dart';

import 'package:sockjs_client_wrapper/src/client.dart';

final _echoUri = Uri.parse('http://localhost:8000/echo');
final _corUri = Uri.parse('http://localhost:8000/cor');
final _fofUri = Uri.parse('http://localhost:8600/404');

void main() {
  group('SockJS Client', () {
    group('default', () {
      SockJSClient createEchoClient() => new SockJSClient(_echoUri);
      SockJSClient createCorClient() => new SockJSClient(_corUri);
      SockJSClient create404Client() => new SockJSClient(_fofUri);

      _integrationSuite(
          'websocket', createEchoClient, createCorClient, create404Client);
    });

    group('websocket', () {
      final websocketOptions = new SockJSOptions(transports: ['websocket']);
      SockJSClient createEchoClient() =>
          new SockJSClient(_echoUri, options: websocketOptions);
      SockJSClient createCorClient() =>
          new SockJSClient(_corUri, options: websocketOptions);
      SockJSClient create404Client() =>
          new SockJSClient(_fofUri, options: websocketOptions);

      _integrationSuite(
          'websocket', createEchoClient, createCorClient, create404Client);
    });

    group('xhr-streaming', () {
      final xhrStreamingOptions =
          new SockJSOptions(transports: ['xhr-streaming']);
      SockJSClient createEchoClient() =>
          new SockJSClient(_echoUri, options: xhrStreamingOptions);
      SockJSClient createCorClient() =>
          new SockJSClient(_corUri, options: xhrStreamingOptions);
      SockJSClient create404Client() =>
          new SockJSClient(_fofUri, options: xhrStreamingOptions);

      _integrationSuite(
          'xhr-streaming', createEchoClient, createCorClient, create404Client);
    });

    group('xhr-polling', () {
      final xhrPollingOptions = new SockJSOptions(transports: ['xhr-polling']);
      SockJSClient createEchoClient() =>
          new SockJSClient(_echoUri, options: xhrPollingOptions);
      SockJSClient createCorClient() =>
          new SockJSClient(_corUri, options: xhrPollingOptions);
      SockJSClient create404Client() =>
          new SockJSClient(_fofUri, options: xhrPollingOptions);

      _integrationSuite(
          'xhr-polling', createEchoClient, createCorClient, create404Client);
    });

    test('disposal should close the client', () async {
      final client = new SockJSClient(_echoUri);
      await client.onOpen.first;
      // ignore: unawaited_futures
      client.dispose();
      await Future.wait([client.onClose.first, client.didDispose]);
    });

    test('closing the client should trigger disposal', () async {
      final client = new SockJSClient(_echoUri);
      await client.onOpen.first;
      client.close();
      await Future.wait([client.onClose.first, client.didDispose]);
    });
  });
}

void _integrationSuite(
  String expectedTransport,
  SockJSClient createEchoClient(),
  SockJSClient createCorClient(),
  SockJSClient create404Client(),
) {
  SockJSClient client;

  tearDown(() async {
    await client.dispose();
    client = null;
  });

  test('connecting to a SockJS server', () async {
    client = createEchoClient();
    expect((await client.onOpen.first).transport, equals(expectedTransport));
  });

  test('sending and receiving messages', () async {
    client = createEchoClient();
    await client.onOpen.first;

    final c = new Completer<Null>();
    final echos = <String>[];
    client.onMessage.listen((message) {
      echos.add(message.data);
      if (echos.length == 2) {
        c.complete();
      }
    });
    client..send('message1')..send('message2');

    await c.future;
    client.close();

    expect(echos, equals(['message1', 'message2']));
  });

  test('client closing the connection', () async {
    client = createEchoClient();
    await client.onOpen.first;
    client.close();
    await client.onClose.first;
  });

  test('client closing the connection with code and reason', () async {
    client = createEchoClient();
    await client.onOpen.first;
    client.close(4001, 'Custom close.');
    final event = await client.onClose.first;
    expect(event.code, equals(4001));
    expect(event.reason, equals('Custom close.'));
  });

  test('server closing the connection', () async {
    client = createCorClient();
    await client.onOpen.first;
    client.send('close');
    await client.onClose.first;
  });

  test('server closing the connection with code and reason', () async {
    client = createCorClient();
    await client.onOpen.first;
    client.send('close::4001::Custom close.');
    final event = await client.onClose.first;
    expect(event.code, equals(4001));
    expect(event.reason, equals('Custom close.'));
  });

  test('handle failed connection', () async {
    client = create404Client();
    await client.onClose.first;
  });
}
