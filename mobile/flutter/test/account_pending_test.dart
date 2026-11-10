import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartas/data/mobile_api.dart';

DioException _error(int status, Object? body) {
  final request = RequestOptions(path: '/mobile/bootstrap');
  return DioException(
    requestOptions: request,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  test('reconhece conta em espera pelo code account_pending', () {
    expect(
      MobileApi.isAccountPending(
        _error(403, {'message': 'x', 'code': 'account_pending'}),
      ),
      isTrue,
    );
  });

  test('outros 403 e outros erros não são conta em espera', () {
    expect(MobileApi.isAccountPending(_error(403, {'message': 'x'})), isFalse);
    expect(
      MobileApi.isAccountPending(_error(401, {'code': 'account_pending'})),
      isFalse,
    );
    expect(MobileApi.isAccountPending(StateError('x')), isFalse);
  });
}
