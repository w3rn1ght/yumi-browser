/* Yumi challenge watchdog — только диагностика Cloudflare.
 *
 * Задача: понять, почему на iOS 12 не появляется виджет проверки.
 * Скрипт ничего не нажимает и не мешает челленджу: он лишь сообщает
 * приложению, какие маркеры найдены на странице.
 */
(function () {
  if (window.__yumiChallengeWatchdog) return;
  window.__yumiChallengeWatchdog = true;

  if (window !== window.top) return;

  function send(payload) {
    try {
      if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.yumi) return;
      window.webkit.messageHandlers.yumi.postMessage(payload);
    } catch (e) {}
  }

  var reported = false;

  function detect() {
    if (reported) return;
    try {
      var markers = [
        '#cf-challenge-running',
        '#challenge-stage',
        '#challenge-form',
        '#cf-please-wait',
        '.cf-turnstile',
        'iframe[src*="challenges.cloudflare.com"]',
        'iframe[src*="cdn-cgi/challenge-platform"]'
      ];
      var found = [];
      for (var i = 0; i < markers.length; i++) {
        try { if (document.querySelector(markers[i])) found.push(markers[i]); } catch (e) {}
      }
      var hasTurnstile = (typeof window.turnstile !== 'undefined');
      if (!found.length && !hasTurnstile) return;

      reported = true;
      send({
        type: 'cf',
        page: location.href,
        markers: found.join(','),
        turnstile: hasTurnstile ? 1 : 0,
        ua: navigator.userAgent,
        webdriver: (navigator.webdriver === undefined) ? 'none' : String(navigator.webdriver),
        top: 1
      });
    } catch (e) {}
  }

  setTimeout(detect, 1500);
  setTimeout(detect, 5000);
  setTimeout(detect, 10000);
  try {
    document.addEventListener('DOMContentLoaded', detect);
  } catch (e) {}
})();
