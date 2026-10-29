// 욕망의 무지개 웹 체험: 큰 일을 쪼갠 단계를 두 물음으로 가른다.
// 규칙은 앱과 같다 (TodoSplitAdvisor) — 조각은 15분까지(fragmentMaxHours), 덩어리는 45분부터(blockMinHours).
// 둘 다 '예'면 조각, 시동이 필요하거나 45분 이상이면 덩어리, 나머지는 짧은 덩어리.
// 앱은 적은 말(한국어 · 영어 낱말)도 보고 답하지만, 체험은 어느 언어에서나 같게 시간만 보고 먼저 답한다.
// 사용자가 뒤집은 답은 앱처럼 판정보다 세다 (FragmentPick).
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);

  const MINUTES = [5, 10, 15, 20, 30, 45, 60, 90, 120];
  const steps = T.steps.map((title, i) => ({ title, min: [30, 5, 90, 60, 5][i], start: null, closing: null }));
  let sel = 1;

  const fmt = m => m < 60 ? T.min.replace("{n}", m)
    : m % 60 ? T.hrmin.replace("{h}", Math.floor(m / 60)).replace("{m}", m % 60) : T.hr.replace("{h}", m / 60);
  const answers = s => ({
    start: s.start ?? true,                    // 앞에서 막고 있는 것이 안 보인다
    closing: s.closing ?? s.min <= 15,         // 15분까지만 조각 안에 들어간다
  });
  const kind = s => {
    const a = answers(s);
    if (a.start && a.closing) return "fragment";
    return !a.start || s.min >= 45 ? "block" : "short";
  };

  root.innerHTML = `
    <div class="sp-stage">
      <div class="sp-head"><strong>${T.task}</strong><span class="muted small sp-total"></span></div>
      <ol class="sp-list"></ol>
      <p class="sp-now"><span>⚡ ${T.pickNow}</span> <b></b></p>
    </div>
    <div class="sp-panel">
      <div class="sp-title"></div>
      <div class="sp-time">
        <span class="muted">${T.time}</span>
        <button type="button" class="sp-step" data-d="-1" aria-label="−">−</button>
        <output aria-live="polite"></output>
        <button type="button" class="sp-step" data-d="1" aria-label="+">+</button>
      </div>
      ${["start", "closing"].map((q, i) => `
      <fieldset class="sp-q" data-q="${q}">
        <legend>${T.questions[i].q}</legend>
        <p class="muted small">${T.questions[i].why}</p>
        <div class="sp-seg">
          <button type="button" data-a="1">${T.yes}</button><button type="button" data-a="0">${T.no}</button>
        </div>
      </fieldset>`).join("")}
      <p class="sp-verdict" aria-live="polite"></p>
      <button type="button" class="sp-reset">${T.reset}</button>
      <p class="muted small">${T.note}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const list = $(".sp-list"), verdict = $(".sp-verdict");

  function render() {
    list.innerHTML = steps.map((s, i) => {
      const k = kind(s);
      return `<li><button type="button" class="sp-row${i === sel ? " on" : ""}" data-i="${i}" aria-pressed="${i === sel}">
        <span class="sp-name">${s.title}</span>
        <span class="sp-badge ${k}">${k === "fragment" ? "⚡ " : ""}${T.kinds[k]}</span>
        <span class="muted small">${fmt(s.min)}</span></button></li>`;
    }).join("");
    $(".sp-total").textContent = `${T.total} ${fmt(steps.reduce((n, s) => n + s.min, 0))}`;
    const now = steps.filter(s => kind(s) === "fragment").map(s => s.title);
    $(".sp-now b").textContent = now.length ? now.join(", ") : T.nothing;

    const s = steps[sel], a = answers(s), k = kind(s);
    $(".sp-title").textContent = s.title;
    $(".sp-time output").textContent = fmt(s.min);
    root.querySelectorAll(".sp-q").forEach(f => {
      const yes = a[f.dataset.q];
      f.querySelectorAll("[data-a]").forEach(b => b.setAttribute("aria-pressed", String((b.dataset.a === "1") === yes)));
    });
    verdict.className = `sp-verdict ${k}`;
    verdict.textContent = T.verdicts[k];
    $(".sp-reset").hidden = s.start === null && s.closing === null;
  }

  root.addEventListener("click", e => {
    const b = e.target.closest("button");
    if (!b) return;
    const s = steps[sel];
    if (b.dataset.i) sel = +b.dataset.i;
    else if (b.dataset.d) {
      const i = MINUTES.indexOf(s.min) + +b.dataset.d;
      s.min = MINUTES[Math.max(0, Math.min(MINUTES.length - 1, i))];
    } else if (b.dataset.a) s[b.closest("[data-q]").dataset.q] = b.dataset.a === "1";
    else if (b.classList.contains("sp-reset")) s.start = s.closing = null;
    else return;
    render();
    if (b.dataset.i) root.querySelector(`[data-i="${sel}"]`).focus();
  });

  render();
})();
