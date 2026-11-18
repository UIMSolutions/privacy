/// Technical clients for outbound notification channels (implement the gateway port).
module uim.myfiori.infrastructure.clients;

@safe:

import vibe.core.log;
import vibe.data.json;
import uim.myfiori.ports.gateways;

/// Writes notifications to the application log (default channel, e.g. collected by CF logging).
class DLogNotificationClient : INotificationGateway {
  size_t sent;

  void send(string recipient, string subject, string message) {
    logWarn("[notify] to=%s subject=%s: %s", recipient, subject, message);
    sent++;
  }

  string describe() { return "log"; }
}

/// POSTs notifications as JSON to a webhook (chat ops, ticketing, mail relay). Falls back to the log.
class DWebhookNotificationClient : INotificationGateway {
  private string _url;
  private DLogNotificationClient _fallback;

  this(string url) {
    _url = url;
    _fallback = new DLogNotificationClient;
  }

  void send(string recipient, string subject, string message) @trusted {
    import vibe.http.client : requestHTTP;
    import vibe.http.common : HTTPMethod;
    auto body_ = Json.emptyObject;
    body_["recipient"] = recipient;
    body_["subject"] = subject;
    body_["text"] = message;
    try {
      requestHTTP(_url, (scope req) { req.method = HTTPMethod.POST; req.writeJsonBody(body_); },
          (scope res) {
            if (res.statusCode >= 300) logWarn("Webhook %s answered %d", _url, res.statusCode);
            res.dropBody();
          });
    } catch (Exception e) {
      logWarn("Webhook delivery failed (%s), logging instead", e.msg);
      _fallback.send(recipient, subject, message);
    }
  }

  string describe() { return "webhook:" ~ _url; }
}
