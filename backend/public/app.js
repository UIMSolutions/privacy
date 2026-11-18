// GDPR Privacy Manager – glue between htmx, BeerCSS and native <dialog>.
(function () {
  "use strict";

  function toast(text, isError) {
    var t = document.getElementById("toast");
    if (!t) return;
    t.textContent = text;
    t.classList.toggle("error", !!isError);
    t.classList.toggle("primary", !isError);
    t.classList.add("active");
    clearTimeout(t._timer);
    t._timer = setTimeout(function () { t.classList.remove("active"); }, isError ? 8000 : 3500);
  }

  // success messages: server sends  HX-Trigger: {"notify": "..."}
  document.addEventListener("notify", function (e) { toast(e.detail.value, false); });

  // error responses are not swapped; the message goes into the open dialog or a snackbar
  document.addEventListener("htmx:beforeSwap", function (e) {
    var xhr = e.detail.xhr;
    if (xhr.status < 400) return;
    e.detail.shouldSwap = false;
    var msg = xhr.responseText || ("Error " + xhr.status);
    var elt = (e.detail.requestConfig && e.detail.requestConfig.elt) || e.detail.elt;
    var dlg = (elt && elt.closest && elt.closest("dialog")) || document.querySelector("dialog[open]");
    var box = dlg ? dlg.querySelector(".form-error") : null;
    if (box) { box.textContent = msg; box.hidden = false; } else { toast(msg, true); }
  });
  document.addEventListener("htmx:sendError", function () { toast("Server not reachable", true); });

  document.addEventListener("click", function (e) {
    var opener = e.target.closest("[data-open]");
    if (opener) {
      var d = document.getElementById(opener.getAttribute("data-open"));
      if (d) {
        d.querySelectorAll(".form-error").forEach(function (x) { x.hidden = true; });
        d.showModal();
      }
    }
    var closer = e.target.closest("[data-close]");
    if (closer && closer.closest("dialog")) closer.closest("dialog").close();
    var tab = e.target.closest(".tabs > a");
    if (tab) {
      tab.parentNode.querySelectorAll("a").forEach(function (a) { a.classList.remove("active"); });
      tab.classList.add("active");
    }
  });
})();
