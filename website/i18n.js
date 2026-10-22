// Puts the page into one of the app's languages: the saved choice, then the browser's, else English. The English text stays in the page
// (search engines and browsers without scripts see it); each language is a file in i18n/ with the same keys as the data-i18n attributes.
(() => {
  const LANGS = {
    en: 'English', ar: 'العربية', bg: 'Български', bn: 'বাংলা', ca: 'Català', cs: 'Čeština', da: 'Dansk', de: 'Deutsch', el: 'Ελληνικά',
    es: 'Español', et: 'Eesti', fa: 'فارسی', fi: 'Suomi', fil: 'Filipino', fr: 'Français', he: 'עברית', hi: 'हिन्दी', hr: 'Hrvatski',
    hu: 'Magyar', id: 'Indonesia', it: 'Italiano', ja: '日本語', ko: '한국어', lt: 'Lietuvių', lv: 'Latviešu', mr: 'मराठी', ms: 'Melayu',
    'nb-NO': 'Norsk bokmål', nl: 'Nederlands', pl: 'Polski', pt: 'Português', 'pt-BR': 'Português (Brasil)', ro: 'Română', ru: 'Русский',
    sk: 'Slovenčina', sl: 'Slovenščina', sr: 'Српски', sv: 'Svenska', ta: 'தமிழ்', te: 'తెలుగు', th: 'ไทย', tr: 'Türkçe', uk: 'Українська',
    'ur-PK': 'اردو', vi: 'Tiếng Việt', 'zh-Hans': '简体中文', 'zh-Hant': '繁體中文',
  };
  const RTL = new Set(['ar', 'fa', 'he', 'ur-PK']);
  // Browser language tags the list has no entry of its own for.
  const ALIAS = { no: 'nb-NO', nb: 'nb-NO', nn: 'nb-NO', tl: 'fil', ur: 'ur-PK', zh: 'zh-Hans', 'zh-CN': 'zh-Hans', 'zh-SG': 'zh-Hans', 'zh-TW': 'zh-Hant', 'zh-HK': 'zh-Hant', 'zh-MO': 'zh-Hant' };
  const fit = (tag) => LANGS[tag] ? tag : ALIAS[tag] || (LANGS[tag.split('-')[0]] ? tag.split('-')[0] : ALIAS[tag.split('-')[0]]);

  const root = document.documentElement, select = document.getElementById('lang');
  const nodes = [...document.querySelectorAll('[data-i18n], [data-i18n-aria], [data-i18n-alt]')].map((el) => ({
    el, html: el.dataset.i18n ? el.innerHTML : null, aria: el.getAttribute('aria-label'), alt: el.getAttribute('alt'),
  }));
  const description = document.querySelector('meta[name=description]'), english = { title: document.title, desc: description.content };
  let words = {}, asked = 0;

  window.i18n = { t: (key, fallback) => words[key] ?? fallback };

  function show(lang, dict) {
    words = dict || {};
    for (const { el, html, aria, alt } of nodes) {
      if (el.dataset.i18n) el.innerHTML = words[el.dataset.i18n] ?? html;
      if (el.dataset.i18nAria) el.setAttribute('aria-label', words[el.dataset.i18nAria] ?? aria);
      if (el.dataset.i18nAlt) el.setAttribute('alt', words[el.dataset.i18nAlt] ?? alt);
    }
    document.title = words.title ?? english.title;
    description.content = words.desc ?? english.desc;
    root.lang = lang;
    root.dir = RTL.has(lang) ? 'rtl' : 'ltr';
    select.value = lang;
    document.dispatchEvent(new Event('i18n'));
  }

  async function use(lang) {
    const mine = ++asked;
    let dict = null;
    if (lang !== 'en') {
      try { dict = await (await fetch(`i18n/${lang}.json`)).json(); } catch (e) { lang = 'en'; /* stays English */ }
    }
    if (mine === asked) show(lang, dict);
  }

  for (const [code, name] of Object.entries(LANGS)) select.add(new Option(name, code));
  select.addEventListener('change', () => {
    try { localStorage.setItem('lang', select.value); } catch (e) { /* private mode */ }
    use(select.value);
  });
  let saved; try { saved = localStorage.getItem('lang'); } catch (e) { /* private mode */ }
  const lang = LANGS[saved] ? saved : [...navigator.languages].map(fit).find(Boolean) || 'en';
  select.value = lang;
  if (lang !== 'en') use(lang);
})();
