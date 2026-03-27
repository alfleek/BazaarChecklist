const bindSegments = () => {
  document.querySelectorAll("[data-segmented]").forEach((group) => {
    const buttons = group.querySelectorAll("[data-segment]");
    buttons.forEach((button) => {
      button.addEventListener("click", () => {
        buttons.forEach((entry) => entry.classList.remove("active"));
        button.classList.add("active");
      });
    });
  });
};

const bindChips = () => {
  document.querySelectorAll("[data-chip]").forEach((chip) => {
    chip.addEventListener("click", () => {
      chip.classList.toggle("active");
    });
  });
};

const bindPerfectToggle = () => {
  const winsInput = document.querySelector("[data-wins-input]");
  const perfectToggle = document.querySelector("[data-perfect-toggle]");
  if (!winsInput || !perfectToggle) return;

  const syncState = () => {
    const wins = Number(winsInput.value || 0);
    const isEnabled = wins === 10;
    perfectToggle.disabled = !isEnabled;
    perfectToggle.classList.toggle("opacity-40", !isEnabled);
    perfectToggle.classList.toggle("cursor-not-allowed", !isEnabled);
    if (!isEnabled) perfectToggle.checked = false;
  };

  winsInput.addEventListener("input", syncState);
  syncState();
};

const bindValidationDemo = () => {
  const submit = document.querySelector("[data-submit-run]");
  const error = document.querySelector("[data-run-error]");
  if (!submit || !error) return;

  submit.addEventListener("click", () => {
    const hero = document.querySelector("[data-hero-value]");
    const boardCount = document.querySelector("[data-board-count]");
    if (!hero || !boardCount) return;
    const valid = hero.value && Number(boardCount.value) > 0;
    error.classList.toggle("hidden", valid);
  });
};

const bindThreshold = () => {
  const select = document.querySelector("[data-threshold]");
  const target = document.querySelector("[data-threshold-copy]");
  if (!select || !target) return;
  select.addEventListener("change", () => {
    target.textContent = select.options[select.selectedIndex].text;
  });
};

const applyThemeFromQuery = () => {
  const params = new URLSearchParams(window.location.search);
  const theme = params.get("theme");
  if (!theme) return;
  document.body.classList.add(`theme-${theme}`);
};

document.addEventListener("DOMContentLoaded", () => {
  applyThemeFromQuery();
  bindSegments();
  bindChips();
  bindPerfectToggle();
  bindValidationDemo();
  bindThreshold();
});
