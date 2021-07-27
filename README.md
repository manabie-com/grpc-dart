The [Dart](https://www.dart.dev/) implementation of
[gRPC](https://grpc.io/): A high performance, open source, general RPC framework that puts mobile and HTTP/2 first.

[![CI status](https://github.com/grpc/grpc-dart/workflows/Dart/badge.svg)](https://github.com/grpc/grpc-dart/actions?query=workflow%3A%22Dart%22+branch%3Amaster)
[![pub package](https://img.shields.io/pub/v/grpc.svg)](https://pub.dev/packages/grpc)


## Learn more

- [Quick Start](https://grpc.io/docs/languages/dart/quickstart) - get an app running in minutes
- [Examples](example)
- [API reference](https://grpc.io/docs/languages/dart/api)

For complete documentation, see [Dart gRPC](https://grpc.io/docs/languages/dart).

## Supported platforms

- [Dart native](https://dart.dev/platforms)
- [Flutter](https://flutter.dev)

> **Note:** [grpc-web](https://github.com/grpc/grpc-web) is supported by `package:grpc/grpc_web.dart`.
> **UDS-unix domain socket** is supported with sdk version >= 2.8.0.

## Contributing

If you experience problems or have feature requests, [open an issue](https://github.com/dart-lang/grpc-dart/issues/new).

Note that we have limited bandwidth to accept PRs, and that all PRs require signing the [EasyCLA](https://lfcla.com).



# manabie_grpc

## **Tutorial:**
### **Async interceptor feature:**
```dart
asyncInterceptor = () async {
  // Implement
}
```

### **Ignore interceptor feature:**
```dart
CallOptions(metadata: {
  // Others metadata
  ignoreInterceptorKey: true.toString(),
})
```

### **Headers callback feature:**
```dart
grpcHeadersCallback = (Map<String, String> values) {
  // Implement
};
```

### **Check internet feature for iOS:**
```dart
partnerWebApiHost = flavorConfig.webHostApi;
```

------
## **Upgrading latest stable grpc library and add custom features: async interceptor, ignore interceptor, headers callback:**


### **Step 1: Check out and create new branch**
- Check the latest stable tag at https://github.com/grpc/grpc-dart/releases

- Check out the latest stable tag

  - Example: `git checkout 2.8.0`

- Create new branch for current checkout to implement the custom features
  - Example: `git switch -c custom_2.8.0`
### **Prepare next step:**
- Creating a `grpc_utils.dart` file in `src/shared/` then add following code:
```dart
Future<Map<String, String>> Function() asyncInterceptor;
Function(Map<String, String> headers) grpcHeadersCallback;
String ignoreInterceptorKey = 'ignore_interceptor';
```


- Add exports in `lib/grpc.dart`:
```dart
export 'src/client/channel.dart' show ClientChannelBase;
export 'src/shared/grpc_utils.dart'; 
```
### **Step 2: Implement async interceptor feature:**
- In `lib/src/client/call.dart`, change from `final CallOptions options;` to `CallOptions options;` 

- For native:
In `lib/src/client/http2_connection.dart` add following these code:

From:
```dart
  void dispatchCall(ClientCall call) {
    if (_transportConnection != null) {
      _refreshConnectionIfUnhealthy();
    }
    switch (_state) {
      case ConnectionState.ready:
        _startCall(call);
        break;
      case ConnectionState.shutdown:
        _shutdownCall(call);
        break;
      default:
        _pendingCalls.add(call);
        if (_state == ConnectionState.idle) {
          _connect();
        }
    }
  }
```
To:
```dart
  void dispatchCall(ClientCall call) async {
    if (_transportConnection != null) {
      _refreshConnectionIfUnhealthy();
    }
    // Difference
    if (asyncInterceptor != null) {
      call.options = CallOptions(
        metadata: (await asyncInterceptor())..addAll(call.options.metadata),
        timeout: call.options.timeout,
        providers: call.options.metadataProviders,
      );
    }
    switch (_state) {
      case ConnectionState.ready:
        _startCall(call);
        break;
      case ConnectionState.shutdown:
        _shutdownCall(call);
        break;
      default:
        _pendingCalls.add(call);
        if (_state == ConnectionState.idle) {
          _connect();
        }
    }
  }
```

- For web:
In `lib/src/client/transport/xhr_transport.dart` add following code:

From:
```dart
    _outgoingMessages.stream
        .map(frame)
        .listen((data) => _request.send(data), cancelOnError: true);
```
To:
```dart
    _outgoingMessages.stream.map(frame).listen((data) async {
      // Difference
      if (asyncInterceptor != null) {
        final metadata = await asyncInterceptor();
        for (final header in metadata.keys) {
          _request.setRequestHeader(header, metadata[header]);
        }
      }
      return _request.send(data);
    }, cancelOnError: true);
```    

### **Step 3: Implement ignore interceptor feature:**
- For native:
In `lib/src/client/http2_connection.dart` add these following code:

From:
```dart
if (asyncInterceptor != null)
```

To:
```dart
if (asyncInterceptor != null &&
        call.options.metadata[ignoreInterceptorKey] != true.toString())
```


- For web in `lib/src/client/transport/xhr_transport.dart`:
  - Add `final bool ignoreInterceptor;` in `XhrTransportStream` class
  - Add following code:

From:
```dart
XhrTransportStream(this._request, {onError, onDone})
```
To:
```dart
XhrTransportStream(this._request, this.ignoreInterceptor, {onError, onDone})
```

From:
```dart
  @override
  GrpcTransportStream makeRequest(String path, Duration timeout,
      Map<String, String> metadata, ErrorHandler onError,
      {CallOptions callOptions}) {
    // gRPC-web headers.
    if (_getContentTypeHeader(metadata) == null) {
      metadata['Content-Type'] = 'application/grpc-web+proto';
      metadata['X-User-Agent'] = 'grpc-web-dart/0.1';
      metadata['X-Grpc-Web'] = '1';
    }

    var requestUri = uri.resolve(path);
    if (callOptions is WebCallOptions &&
        callOptions.bypassCorsPreflight == true) {
      requestUri = cors.moveHttpHeadersToQueryParam(metadata, requestUri);
    }

    final HttpRequest request = createHttpRequest();
    request.open('POST', requestUri.toString());
    if (callOptions is WebCallOptions && callOptions.withCredentials == true) {
      request.withCredentials = true;
    }
    // Must set headers after calling open().
    _initializeRequest(request, metadata);

    final XhrTransportStream transportStream =
        XhrTransportStream(request, onError: onError, onDone: _removeStream);
    _requests.add(transportStream);
    return transportStream;
  }
```
To:
```dart
  @override
  GrpcTransportStream makeRequest(String path, Duration timeout,
      Map<String, String> metadata, ErrorHandler onError,
      {CallOptions callOptions}) {
    // Difference
    final ignoreInterceptor = metadata == null
        ? false
        : metadata[ignoreInterceptorKey] == true.toString();
    metadata.remove(ignoreInterceptorKey);

    // gRPC-web headers.
    if (_getContentTypeHeader(metadata) == null) {
      metadata['Content-Type'] = 'application/grpc-web+proto';
      metadata['X-User-Agent'] = 'grpc-web-dart/0.1';
      metadata['X-Grpc-Web'] = '1';
    }

    var requestUri = uri.resolve(path);
    if (callOptions is WebCallOptions &&
        callOptions.bypassCorsPreflight == true) {
      requestUri = cors.moveHttpHeadersToQueryParam(metadata, requestUri);
    }

    final HttpRequest request = createHttpRequest();
    request.open('POST', requestUri.toString());
    if (callOptions is WebCallOptions && callOptions.withCredentials == true) {
      request.withCredentials = true;
    }
    // Must set headers after calling open().
    _initializeRequest(request, metadata);

    // Difference
    final XhrTransportStream transportStream = XhrTransportStream(
        request, ignoreInterceptor,
        onError: onError, onDone: _removeStream);
    _requests.add(transportStream);
    return transportStream;
  }
```
### **Step 4: Implement headers callback feature:**
- In `lib/src/client/channel.dart` at `createCall<Q, R>` function add following code:

From:
```dart
  @override
  ClientCall<Q, R> createCall<Q, R>(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options) {
    final call = ClientCall(
        method,
        requests,
        options,
        isTimelineLoggingEnabled
            ? timelineTaskFactory(filterKey: clientTimelineFilterKey)
            : null);
    getConnection().then((connection) {
      if (call.isCancelled) return;
      connection.dispatchCall(call);
    }, onError: call.onConnectionError);
    return call;
  }
```
To:
```dart
  @override
  ClientCall<Q, R> createCall<Q, R>(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options) {
    final call = ClientCall(
        method,
        requests,
        options,
        isTimelineLoggingEnabled
            ? timelineTaskFactory(filterKey: clientTimelineFilterKey)
            : null);
    getConnection().then((connection) {
      if (call.isCancelled) return;
      connection.dispatchCall(call);
    }, onError: call.onConnectionError);

    // Difference
    call.headers.then((Map<String, String> value) {
      if (grpcHeadersCallback != null) {
        grpcHeadersCallback(value);
      }
    });
    return call;
  }
```

### **Step 5: Check internet feature for iOS:**
- In `lib/src/client/channel.dart` at `getConnection()` function add following code:

From:
```dart
  Future<ClientConnection> getConnection() async {
    if (_isShutdown) throw GrpcError.unavailable('Channel shutting down.');
    if (!_connected) {
      _connection = createConnection();
      _connected = true;
    }
    return _connection;
  }
```
To:
```dart
  Future<ClientConnection> getConnection() async {
    if (_isShutdown) throw GrpcError.unavailable('Channel shutting down.');
    if (!_connected) {
      _connection = createConnection();
      _connected = true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await http.get(Uri.parse(partnerWebApiHost));
    }
    return _connection;
  }
```
