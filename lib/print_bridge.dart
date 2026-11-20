import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _jsWindow;

void triggerBrowserPrint() {
  _jsWindow.callMethod('print'.toJS);
}

void registerPrintEventListeners({
  required void Function() onBeforePrint,
  required void Function() onAfterPrint,
}) {
  _jsWindow.callMethod(
    'addEventListener'.toJS,
    'beforeprint'.toJS,
    onBeforePrint.toJS,
  );
  _jsWindow.callMethod(
    'addEventListener'.toJS,
    'afterprint'.toJS,
    onAfterPrint.toJS,
  );
}