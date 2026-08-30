/* Radial quick-links launcher, anchored to the left edge.
   Links live in an actual circular queue: `start` is a rotating offset
   into `items`, so "rotating" the queue is just `start = (start + delta)
   mod size` — no data moves, only which item reads as "selected" (the
   one sitting at angle 0) changes. Icon DOM nodes are persistent and
   only ever rebuilt when the underlying link list changes (add/remove);
   rotating just re-reads each node's angle and lets the CSS transition
   on `transform` animate it — that's what makes it look like a wheel
   revolving instead of icons jumping between slots. */
(function () {
  const STORAGE_KEY = "launcher-links";
  const RADIUS = 150;
  const OPEN_TOGGLE_KEY = "k"; // Alt+K opens/closes the panel
  const WHEEL_THROTTLE_MS = 90; // one step per "tick" even on fast trackpad scroll

  // 10 evenly spaced around the full circle: with the launcher anchored to
  // the left screen edge, that puts ~5 on the visible (right-facing) half
  // in front at any time, and the rest sit on the off-screen half until
  // rotated into view (wheel or arrow keys) — no separate windowing logic
  // needed, it falls out of the geometry.
  // Links with an `icon` get the real logo image (icons/); everything
  // else falls back to the generated domain-initial letter badge in
  // rebuildIcons() below.
  const DEFAULT_LINKS = [
    { label: "GitHub", url: "https://github.com", icon: "icons/github.jpg" },
    { label: "YouTube", url: "https://youtube.com" },
    { label: "Wikipedia", url: "https://wikipedia.org" },
    { label: "Reddit", url: "https://reddit.com" },
    { label: "Gmail", url: "https://mail.google.com", icon: "icons/gmail.webp" },
    { label: "Twitter", url: "https://twitter.com" },
    { label: "Notion", url: "https://notion.so" },
    { label: "Google Classroom", url: "https://classroom.google.com", icon: "icons/classroom.png" },
    { label: "LeetCode", url: "https://leetcode.com", icon: "icons/leetcode.png" },
    { label: "LinkedIn", url: "https://linkedin.com" },
  ];

  class CircularQueue {
    constructor(items) {
      this.items = items.slice();
      this.start = 0;
    }

    get size() {
      return this.items.length;
    }

    rotate(delta) {
      if (!this.size) return;
      this.start = ((this.start + delta) % this.size + this.size) % this.size;
    }

    // Angle (degrees) of the item at `index` in `items`, relative to the
    // current rotation — 0 is always the selected slot, pointing right.
    angleFor(index) {
      if (!this.size) return 0;
      const offset = (index - this.start + this.size) % this.size;
      return offset * (360 / this.size);
    }

    selectedIndex() {
      return this.start;
    }

    enqueue(item) {
      this.items.push(item);
    }

    removeAt(index) {
      this.items.splice(index, 1);
      if (this.size === 0) {
        this.start = 0;
      } else {
        this.start %= this.size;
      }
    }
  }

  function loadLinks() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
      if (Array.isArray(saved) && saved.length) {
        // Backfill icons by URL onto anything saved before that icon
        // existed in DEFAULT_LINKS — otherwise a stale localStorage save
        // keeps loading the old letter-badge version forever and a new
        // default icon never appears, no matter what DEFAULT_LINKS says.
        const byUrl = new Map(DEFAULT_LINKS.map((link) => [link.url, link]));
        return saved.map((link) => {
          const match = byUrl.get(link.url);
          return match && match.icon && !link.icon
            ? { ...link, icon: match.icon }
            : link;
        });
      }
    } catch {
      /* fall through to defaults */
    }
    return DEFAULT_LINKS.slice();
  }

  function saveLinks() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue.items));
  }

  function domainInitial(url) {
    try {
      const host = new URL(url).hostname.replace(/^www\./, "");
      return (host[0] || "?").toUpperCase();
    } catch {
      return "?";
    }
  }

  function hueFromString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) hash = (hash * 31 + str.charCodeAt(i)) >>> 0;
    return hash % 360;
  }

  function normalizeUrl(input) {
    const trimmed = input.trim();
    return /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  }

  const queue = new CircularQueue(loadLinks());
  saveLinks(); // persist defaults on first run so they survive a reload

  const root = document.getElementById("radial-launcher");
  const hub = document.getElementById("radial-hub");
  const ring = document.getElementById("radial-ring");
  const addBtn = document.getElementById("radial-add");
  const hitzone = document.getElementById("radial-hitzone");
  const iconInput = document.getElementById("radial-icon-input");

  let isOpen = false;
  let lastWheelRotate = 0;

  function positionIcon(btn, index) {
    const angle = queue.angleFor(index);
    const rad = (angle * Math.PI) / 180;
    const x = Math.cos(rad) * RADIUS;
    const y = Math.sin(rad) * RADIUS;
    // Position via custom properties rather than `transform` directly: an
    // inline `style.transform` always wins over stylesheet rules no
    // matter their specificity, which would make a CSS `:hover { transform:
    // scale(...) }` rule silently do nothing. Reading --x/--y from CSS
    // instead lets the stylesheet compose translate + hover-scale together.
    btn.style.setProperty("--x", `${x}px`);
    btn.style.setProperty("--y", `${y}px`);
    btn.classList.toggle("selected", index === queue.selectedIndex());
  }

  function updatePositions() {
    Array.from(ring.children).forEach((btn, index) => positionIcon(btn, index));
  }

  function rebuildIcons() {
    ring.innerHTML = "";
    queue.items.forEach((link, index) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "radial-icon";
      btn.title = link.label || link.url;
      btn.setAttribute("role", "menuitem");

      if (link.icon) {
        const img = document.createElement("img");
        img.src = link.icon;
        img.alt = "";
        btn.appendChild(img);
      } else {
        btn.style.background = `hsl(${hueFromString(link.url)} 65% 45%)`;
        btn.textContent = domainInitial(link.url);
      }

      btn.addEventListener("click", () => openLink(link));
      ring.appendChild(btn);
      positionIcon(btn, index);
    });
  }

  function openLink(link) {
    location.href = link.url;
  }

  function openSelected() {
    const link = queue.items[queue.selectedIndex()];
    if (link) openLink(link);
  }

  function removeSelected() {
    if (!queue.size) return;
    queue.removeAt(queue.selectedIndex());
    saveLinks();
    rebuildIcons();
  }

  // Opens the native file picker and resolves to a data URL (so it's
  // plain JSON-serializable and survives in localStorage same as
  // everything else) — or null if the user cancels without picking one.
  function pickIconImage() {
    return new Promise((resolve) => {
      iconInput.value = ""; // reset so picking the same file twice still fires "change"
      iconInput.onchange = () => {
        const file = iconInput.files[0];
        if (!file) {
          resolve(null);
          return;
        }
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => resolve(null);
        reader.readAsDataURL(file);
      };
      iconInput.click();
    });
  }

  async function addLink() {
    const raw = prompt("Link to add (e.g. example.com):");
    if (!raw || !raw.trim()) return;
    const url = normalizeUrl(raw);
    const label = prompt("Label (optional):") || "";

    const link = { url, label };
    if (confirm("Add an icon image for this link?")) {
      const icon = await pickIconImage();
      if (icon) link.icon = icon;
    }

    queue.enqueue(link);
    saveLinks();
    rebuildIcons();
  }

  function openPanel() {
    isOpen = true;
    root.classList.add("open");
    ring.hidden = false;
    addBtn.hidden = false;
    hitzone.hidden = false;
    hub.setAttribute("aria-expanded", "true");
    rebuildIcons();
  }

  function closePanel() {
    isOpen = false;
    root.classList.remove("open");
    ring.hidden = true;
    addBtn.hidden = true;
    hitzone.hidden = true;
    hub.setAttribute("aria-expanded", "false");
  }

  function togglePanel() {
    if (isOpen) closePanel();
    else openPanel();
  }

  hub.addEventListener("click", togglePanel);
  addBtn.addEventListener("click", addLink);

  document.addEventListener("click", (event) => {
    if (isOpen && !root.contains(event.target)) closePanel();
  });

  // Scrolling over the hub or any ring icon spins the wheel, same as the
  // arrow keys below — throttled so one fast trackpad swipe doesn't blow
  // past several links in a single frame.
  root.addEventListener(
    "wheel",
    (event) => {
      if (!isOpen) return;
      event.preventDefault();
      const now = Date.now();
      if (now - lastWheelRotate < WHEEL_THROTTLE_MS) return;
      lastWheelRotate = now;
      queue.rotate(event.deltaY > 0 ? 1 : -1);
      updatePositions();
    },
    { passive: false }
  );

  document.addEventListener("keydown", (event) => {
    if (event.altKey && event.key.toLowerCase() === OPEN_TOGGLE_KEY) {
      event.preventDefault();
      togglePanel();
      return;
    }
    if (!isOpen) return;

    switch (event.key) {
      case "ArrowUp":
      case "ArrowLeft":
        event.preventDefault();
        queue.rotate(-1);
        updatePositions();
        break;
      case "ArrowDown":
      case "ArrowRight":
        event.preventDefault();
        queue.rotate(1);
        updatePositions();
        break;
      case "Enter":
        event.preventDefault();
        openSelected();
        break;
      case "Delete":
      case "Backspace":
        event.preventDefault();
        removeSelected();
        break;
      case "Escape":
        event.preventDefault();
        closePanel();
        break;
      default:
        break;
    }
  });
})();
