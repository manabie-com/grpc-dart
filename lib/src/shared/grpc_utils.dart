import '../../grpc_connection_interface.dart';

Future<Map<String, String>> Function()? asyncInterceptor;
Function(Map<String, String> headers)? grpcHeadersCallback;
ClientConnection Function()? getClientConnection;
String ignoreInterceptorKey = 'ignore_interceptor';
String partnerWebApiHost = '';
