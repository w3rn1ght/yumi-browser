/* Yumi diagnostics — сообщает приложению об ошибках JS и незагруженных ресурсах.
 * Ничего не исправляет и не вмешивается в страницу: только слушает события.
 */
(function () {
  if (window.__yumiDiagnostics) return;
  window.__yumiDiagnostics = true;

  var sent = 0;
  var MAX = 25;

  function send(payload) {
    if (sent > MAX) return;
    sent += 1;
    try {
      if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.yumi) return;
      payload.type = 'jserror';
      payload.page = location.href;
      payload.top = (window === window.top) ? 1 : 0;
      window.webkit.messageHandlers.yumi.postMessage(payload);
    } catch (e) {}
  }

  function short(text, limit) {
    var s = String(text || '');
    return s.length > (limit || 220) ? s.slice(0, limit || 220) + '…' : s;
  }

  window.addEventListener('error', function (event) {
    try {
      if (event && event.target && event.target !== window && event.target.tagName) {
        send({
          kind: 'resource',
          tag: String(event.target.tagName).toLowerCase(),
          url: short(event.target.src || event.target.href || '', 300)
        });
        return;
      }
      send({
        kind: 'error',
        message: short(event && event.message),
        source: short(event && event.filename, 200),
        line: (event && event.lineno) || 0
      });
    } catch (e) {}
  }, true);

  window.addEventListener('unhandledrejection', function (event) {
    try {
      var reason = event && event.reason;
      var text = reason && (reason.message || reason.toString());
      send({ kind: 'rejection', message: short(text) });
    } catch (e) {}
  });
})();
