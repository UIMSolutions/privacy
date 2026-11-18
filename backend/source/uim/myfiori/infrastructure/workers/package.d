/// Background tasks: periodic deadline monitoring (DSR one-month and breach 72-hour deadlines).
module uim.myfiori.infrastructure.workers;

@safe:

import core.time : minutes;
import vibe.core.core : setTimer, Timer;
import vibe.core.log;
import uim.myfiori.ports.services;

class DDeadlineMonitorWorker {
  private IDeadlineService _service;
  private int _intervalMinutes;
  private Timer _timer;

  this(IDeadlineService service, int intervalMinutes) {
    _service = service;
    _intervalMinutes = intervalMinutes;
  }

  void start() {
    if (_intervalMinutes <= 0) return;
    _timer = setTimer(_intervalMinutes.minutes, () nothrow { run(); }, true);
    logInfo("Deadline monitor active (every %d min)", _intervalMinutes);
  }

  void stop() { if (_timer) _timer.stop(); }

  /// One monitoring cycle; never throws (runs inside a timer callback).
  void run() nothrow {
    try {
      auto n = _service.notifyResponsibles();
      if (n) logInfo("Deadline monitor: %d alert(s) sent", n);
    } catch (Exception e) {
      logException(e, "Deadline monitor failed");
    }
  }
}
