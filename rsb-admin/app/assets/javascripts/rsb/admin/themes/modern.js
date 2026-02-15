(function() {
  var STORAGE_KEY = 'rsb-admin-mode';

  function getPreferred() {
    var stored = localStorage.getItem(STORAGE_KEY);
    if (stored) return stored;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function apply(mode) {
    document.documentElement.setAttribute('data-rsb-mode', mode);
    localStorage.setItem(STORAGE_KEY, mode);
  }

  // Apply on load (rule #17)
  apply(getPreferred());

  // Toggle function exposed globally for the button
  window.rsbToggleMode = function() {
    var current = document.documentElement.getAttribute('data-rsb-mode');
    apply(current === 'dark' ? 'light' : 'dark');
  };

  // Sidebar section collapse/expand toggle
  window.rsbToggleSection = function(id) {
    var content = document.getElementById(id);
    var chevron = document.getElementById(id + '-chevron');
    if (!content) return;
    if (content.classList.contains('hidden')) {
      content.classList.remove('hidden');
      if (chevron) chevron.classList.add('rotate-90');
    } else {
      content.classList.add('hidden');
      if (chevron) chevron.classList.remove('rotate-90');
    }
  };
})();
