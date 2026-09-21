/* Progressive enhancement: all documentation remains usable without JavaScript. */
document.addEventListener("DOMContentLoaded", () => {
  if (!navigator.clipboard || !window.isSecureContext) return;
  async function copyText(button, text, status) {
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text.trim());
      button.textContent = "Copied";
      if (status) status.textContent = "Citation copied.";
    } catch {
      button.textContent = "Select & copy";
      if (status) status.textContent = "Please select the citation and copy it manually.";
    }
    window.setTimeout(() => { button.textContent = original; }, 2500);
  }
  document.querySelectorAll('div[class*="highlight-"] > .highlight > pre').forEach((pre) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "pb-code-copy";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy code to clipboard");
    button.addEventListener("click", () => copyText(button, pre.textContent));
    pre.parentElement.parentElement.appendChild(button);
  });
  document.querySelectorAll("[data-copy-target]").forEach((button) => {
    const target = document.getElementById(button.dataset.copyTarget);
    if (!target) return;
    button.hidden = false;
    button.addEventListener("click", () => copyText(button, target.textContent, button.nextElementSibling));
  });
});
