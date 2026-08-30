const DURATIONS = { work: 25 * 60, short: 5 * 60, long: 15 * 60 };
const LONG_BREAK_EVERY = 4;
const CIRCUMFERENCE = 2 * Math.PI * 44;
const STORAGE_KEY = "pomodoro-state";

const timeEl = document.getElementById("pomodoro-time");
const modeEl = document.getElementById("pomodoro-mode");
const sessionsEl = document.getElementById("pomodoro-sessions");
const toggleBtn = document.getElementById("pomodoro-toggle");
const resetBtn = document.getElementById("pomodoro-reset");
const ring = document.getElementById("ring-progress");
const widget = document.getElementById("pomodoro");

ring.style.strokeDasharray = String(CIRCUMFERENCE);

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved && typeof saved.remaining === "number") return saved;
  } catch {
    /* fall through to a fresh state */
  }
  return { mode: "work", sessionsCompleted: 0, running: false, remaining: DURATIONS.work, endTime: null };
}

let state = loadState();

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function getRemaining() {
  if (state.running && state.endTime) {
    return Math.max(0, Math.round((state.endTime - Date.now()) / 1000));
  }
  return state.remaining;
}

function modeLabel(mode) {
  if (mode === "work") return "Focus";
  return mode === "short" ? "Short Break" : "Long Break";
}

function render() {
  const total = DURATIONS[state.mode];
  const remaining = getRemaining();
  const m = Math.floor(remaining / 60).toString().padStart(2, "0");
  const s = Math.floor(remaining % 60).toString().padStart(2, "0");

  timeEl.textContent = `${m}:${s}`;
  modeEl.textContent = modeLabel(state.mode);
  sessionsEl.textContent = `Session ${(state.sessionsCompleted % LONG_BREAK_EVERY) + 1} of ${LONG_BREAK_EVERY}`;
  ring.style.strokeDashoffset = String(CIRCUMFERENCE * (1 - remaining / total));
  widget.classList.toggle("mode-break", state.mode !== "work");
  toggleBtn.textContent = state.running ? "Pause" : "Start";
}

function notify(title, message) {
  if (typeof browser !== "undefined" && browser.notifications) {
    browser.notifications.create({ type: "basic", title, message });
  }
}

function completeSession() {
  if (state.mode === "work") {
    state.sessionsCompleted += 1;
    state.mode = state.sessionsCompleted % LONG_BREAK_EVERY === 0 ? "long" : "short";
    notify("Focus session done", "Time for a break.");
  } else {
    state.mode = "work";
    notify("Break's over", "Back to a focus session.");
  }
  state.remaining = DURATIONS[state.mode];
  state.running = false;
  state.endTime = null;
  saveState();
  render();
}

function tick() {
  if (state.running && getRemaining() <= 0) {
    completeSession();
    return;
  }
  render();
}

toggleBtn.addEventListener("click", () => {
  if (state.running) {
    state.remaining = getRemaining();
    state.running = false;
    state.endTime = null;
  } else {
    state.running = true;
    state.endTime = Date.now() + state.remaining * 1000;
  }
  saveState();
  render();
});

resetBtn.addEventListener("click", () => {
  state.running = false;
  state.endTime = null;
  state.remaining = DURATIONS[state.mode];
  saveState();
  render();
});

setInterval(tick, 1000);
render();

// ---- Search: uses the real default search engine via the WebExtension
// search API, falling back to a direct Google query URL if that API isn't
// available for some reason. ----
const searchForm = document.getElementById("search-form");
const searchInput = document.getElementById("search-input");

searchForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const query = searchInput.value.trim();
  if (!query) return;

  if (typeof browser !== "undefined" && browser.search && browser.tabs) {
    try {
      const tab = await browser.tabs.getCurrent();
      await browser.search.search({ query, tabId: tab.id });
      return;
    } catch {
      /* fall through to the plain URL fallback below */
    }
  }
  location.href = "https://www.google.com/search?q=" + encodeURIComponent(query);
});
