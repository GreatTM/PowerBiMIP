function enhanceNavigation() {
  document.querySelector(".sidebar-tree .current.reference")?.setAttribute("aria-current", "page");
  const tools = document.querySelector(".content-icon-container");
  if (tools) {
    tools.setAttribute("role", "region");
    tools.setAttribute("aria-label", "Page controls");
  }

  const navigationQuery = document.querySelector(".pb-home-page") ? "(width < 60rem)" : "(max-width: 63em)";
  let active;
  for (const [id, selector, name, query] of [
    ["__navigation", ".sidebar-drawer", "Documentation", navigationQuery],
    ["__toc", ".toc-drawer:not(.no-toc)", "On this page", "(max-width: 82em)"],
  ]) {
    const panel = document.querySelector(selector);
    const input = document.getElementById(id);
    if (!panel || !input) continue;

    panel.id = "pb" + id;
    panel.tabIndex = -1;
    panel.setAttribute("aria-label", name);
    let opener;
    const buttons = [];
    const drawer = { panel, buttons, close };
    const labels = document.querySelectorAll('label[for="' + id + '"]:not(.overlay, .no-toc)');

    function sync() {
      for (const button of buttons) button.setAttribute("aria-expanded", String(input.checked));
      if (input.checked) {
        active = drawer;
      } else if (active === drawer) {
        active = undefined;
        if (panel.contains(document.activeElement)) opener?.focus();
      }
    }

    function close(restoreFocus) {
      input.checked = false;
      sync();
      if (restoreFocus) opener?.focus();
    }

    for (const label of labels) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = label.className + " pb-drawer-toggle";
      button.setAttribute("aria-label", name);
      button.setAttribute("aria-controls", panel.id);
      button.append(...label.childNodes);
      button.querySelector("svg")?.setAttribute("aria-hidden", "true");
      label.replaceWith(button);
      buttons.push(button);
      button.addEventListener("click", () => {
        if (input.checked) {
          close(true);
          return;
        }
        active?.close(false);
        opener = button;
        input.checked = true;
        sync();
        panel.focus({ preventScroll: true });
      });
    }

    if (!buttons.length) continue;
    input.dataset.enhanced = "";
    input.addEventListener("change", sync);
    sync();
    panel.addEventListener("click", event => {
      if (input.checked && event.target.closest('a[href^="#"]')) close(false);
    });
    matchMedia(query).addEventListener("change", event => {
      if (!event.matches) close(false);
    });
  }

  document.addEventListener("keydown", event => {
    if (active && event.key === "Escape") {
      event.preventDefault();
      active.close(true);
    }
  });
  document.addEventListener("focusin", event => {
    if (active && !active.panel.contains(event.target) && !active.buttons.includes(event.target)) active.close(false);
  });
}

function syncBrand() {
  const sources = document.querySelectorAll(".pb-brand-picture source");
  if (!sources.length) return;

  function update() {
    const theme = document.body.dataset.theme;
    const media = theme === "dark" ? "all" : theme === "light" ? "not all" : "(prefers-color-scheme: dark)";
    for (const source of sources) source.media = media;
  }

  update();
  new MutationObserver(update).observe(document.body, { attributeFilter: ["data-theme"] });
}

function enhanceArticle(article) {
  const canCopy = window.isSecureContext && navigator.clipboard?.writeText;
  const workbench = article.querySelector(".pb-workbench");
  const regions = [];
  const labels = new Map();
  const copies = new Map();
  const languages = {
    matlab: "MATLAB",
    bash: "Shell",
    sh: "Shell",
    shell: "Shell",
    python: "Python",
    bibtex: "BibTeX",
    text: "Output",
  };
  let lastAnnouncement = "";
  let refreshPanelFocus;

  function wrap(element, className) {
    const wrapper = document.createElement("div");
    wrapper.className = className;
    element.before(wrapper);
    wrapper.append(element);
    return wrapper;
  }

  function addRegion(element, kind, markEdge = false) {
    const caption = element.querySelector("caption")?.textContent.trim();
    const heading = element.closest("section")?.querySelector(":scope > :is(h1,h2,h3,h4,h5,h6)");
    const panel = element.closest('[role="tabpanel"]');
    const tab = panel && document.getElementById(panel.getAttribute("aria-labelledby"));
    const section = (tab || heading)?.textContent.replace(/¶\s*$/, "").trim();
    const base = caption || (section ? kind + " in " + section : kind);
    const count = (labels.get(base) || 0) + 1;
    labels.set(base, count);
    const name = count === 1 ? base : base + " (" + count + ")";
    const frame = markEdge ? wrap(element, "pb-scroll-frame") : null;
    regions.push({ element, name, frame });
    if (frame) element.addEventListener("scroll", () => updateEdge(element, frame), { passive: true });
    return name;
  }

  function updateEdge(element, frame) {
    frame?.toggleAttribute("data-more", element.scrollWidth - Math.abs(element.scrollLeft) > element.clientWidth + 1);
  }

  function measure() {
    for (const { element, name, frame } of regions) {
      if (element.closest("[hidden]")) continue;
      if (element.scrollWidth > element.clientWidth + 1) {
        element.tabIndex = 0;
        element.setAttribute("role", "region");
        element.setAttribute("aria-label", name);
      } else {
        for (const attr of ["tabindex", "role", "aria-label"]) element.removeAttribute(attr);
      }
      updateEdge(element, frame);
    }
    refreshPanelFocus?.();
  }

  function registerCopy(button, readText) {
    let status = button.nextElementSibling;
    if (!status?.matches('[role="status"]')) {
      status = document.createElement("span");
      status.className = "pb-copy-status";
      status.setAttribute("role", "status");
      button.after(status);
    }
    button.hidden = false;
    const entry = { readText, status };
    copies.set(button, entry);
    return entry;
  }

  function enhanceWorkbench() {
    const list = workbench.querySelector(".pb-tab-list");
    const tabs = Array.from(list.querySelectorAll('[role="tab"]'));
    const panels = tabs.map(tab => workbench.querySelector('[aria-labelledby="' + tab.id + '"]'));
    const copy = workbench.querySelector(".pb-workbench-copy");
    const nativeFocusGroup = Object.hasOwn(HTMLElement.prototype, "focusGroup");
    let active;

    function activePanel() {
      return panels[tabs.indexOf(active)];
    }

    const entry = canCopy && registerCopy(copy, () => {
      const panel = activePanel();
      const code = panel.querySelector("pre");
      if (code) return code.textContent;
      const formula = panel.querySelector("div.math");
      const source = window.MathJax?.startup?.document?.getMathItemsWithin?.(formula)[0]?.math;
      return source ? "\\[\n" + source.trim() + "\n\\]" : formula.textContent.trim();
    });

    refreshPanelFocus = () => {
      const panel = activePanel();
      const focusable = panel.querySelector('a[href], button:not([hidden]), [tabindex="0"]');
      if (focusable) panel.removeAttribute("tabindex");
      else panel.tabIndex = 0;
    };

    function select(tab) {
      if (tab === active) return;
      active = tab;
      tabs.forEach((item, index) => {
        const selected = item === tab;
        item.setAttribute("aria-selected", String(selected));
        item.toggleAttribute("focusgroupstart", selected);
        if (!nativeFocusGroup) item.tabIndex = selected ? 0 : -1;
        const panel = panels[index];
        if (selected) panel.removeAttribute("hidden");
        else {
          panel.setAttribute("hidden", "until-found");
          panel.removeAttribute("tabindex");
        }
      });
      const panel = activePanel();
      const formula = panel.querySelector("div.math");
      if (entry) {
        clearTimeout(entry.timer);
        entry.call = undefined;
        entry.status.textContent = "";
        copy.textContent = formula ? "Copy LaTeX" : "Copy";
        copy.setAttribute("aria-label", formula ? "Copy LaTeX" : "Copy " + tab.textContent.trim());
      }
      if (list.scrollWidth > list.clientWidth) {
        const tabBox = tab.getBoundingClientRect();
        const listBox = list.getBoundingClientRect();
        if (tabBox.right > listBox.right) list.scrollLeft += tabBox.right - listBox.right;
        else if (tabBox.left < listBox.left) list.scrollLeft += tabBox.left - listBox.left;
      }
      measure();
      const mathjax = window.MathJax;
      if (formula && !panel.querySelector("mjx-container")) {
        mathjax?.typesetPromise?.([panel]).then(measure).catch(() => {});
      }
    }

    for (const type of ["focusin", "click"]) {
      list.addEventListener(type, event => {
        const tab = event.target.closest('[role="tab"]');
        if (tab) select(tab);
      });
    }
    panels.forEach((panel, index) => panel.addEventListener("beforematch", () => select(tabs[index])));
    if (!nativeFocusGroup) {
      list.addEventListener("keydown", event => {
        const index = tabs.indexOf(event.target);
        if (index === -1) return;
        let next;
        if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
        else if (event.key === "ArrowLeft") next = (index + tabs.length - 1) % tabs.length;
        else if (event.key === "Home") next = 0;
        else if (event.key === "End") next = tabs.length - 1;
        else return;
        event.preventDefault();
        tabs[next].focus();
      });
    }
    select(tabs.find(tab => tab.getAttribute("aria-selected") === "true") || tabs[0]);
  }

  for (const pre of article.querySelectorAll(".highlight > pre")) {
    const block = pre.parentElement.parentElement;
    const lexer = [...block.classList].find(name => name.startsWith("highlight-"))?.slice(10);
    const language = languages[lexer];
    const isOutput = lexer === "text";
    const kind = language && !isOutput ? language + " code" : language || "Code";
    const inWorkbench = workbench?.contains(block);
    const name = addRegion(pre, kind, Boolean(inWorkbench));
    if (inWorkbench) continue;
    if (!canCopy && !isOutput) continue;
    const toolbar = document.createElement("div");
    toolbar.className = "pb-code-tools";
    if (language) {
      const text = document.createElement("span");
      text.textContent = language;
      toolbar.append(text);
    }
    block.prepend(toolbar);
    if (isOutput) continue;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "pb-copy-button";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy " + name);
    toolbar.append(button);
    registerCopy(button, () => pre.textContent);
  }

  for (const table of article.querySelectorAll("table:not(.table-wrapper table, .highlight table)")) {
    wrap(table, "table-wrapper container");
  }
  for (const table of article.querySelectorAll(".table-wrapper.container:not(.highlight .table-wrapper)")) {
    addRegion(table, "Table", true);
  }
  for (const math of article.querySelectorAll("div.math")) addRegion(math, "Formula", true);
  if (workbench) enhanceWorkbench();
  measure();
  if ("ResizeObserver" in window) new ResizeObserver(measure).observe(article);
  else window.addEventListener("resize", measure);
  document.fonts?.ready.then(measure);
  window.addEventListener("load", () => {
    measure();
    window.MathJax?.startup?.promise?.then(measure);
  }, { once: true });

  if (!canCopy) return;
  for (const button of article.querySelectorAll("button[data-copy-target]")) {
    const target = document.getElementById(button.dataset.copyTarget);
    if (target) registerCopy(button, () => target.textContent.trim());
  }
  article.addEventListener("click", async event => {
    const entry = copies.get(event.target.closest("button"));
    if (!entry) return;
    const { readText, status } = entry;
    const call = entry.call = Symbol();
    clearTimeout(entry.timer);
    status.textContent = "";
    let message = "Copied.";
    try {
      await navigator.clipboard.writeText(readText());
    } catch {
      message = "Copy failed. Select the text to copy it.";
    }
    if (entry.call !== call) return;
    lastAnnouncement = message === lastAnnouncement ? message + "\u00a0" : message;
    status.textContent = lastAnnouncement;
    entry.timer = setTimeout(() => { status.textContent = ""; }, 3200);
  });
}

enhanceNavigation();
syncBrand();
const article = document.querySelector('article[role="main"]');
if (article) enhanceArticle(article);
