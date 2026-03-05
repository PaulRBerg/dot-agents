const { chromium } = require('playwright');

const TARGET_URL = process.env.TARGET_URL || 'http://localhost:4000';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 3,
  });
  const page = await context.newPage();

  async function measure(route, selectors) {
    await page.goto(new URL(route, TARGET_URL).toString(), { waitUntil: 'networkidle' });
    await page.waitForTimeout(500);

    const result = await page.evaluate((selectorList) => {
      function findByText(tagName, text, predicate) {
        const candidates = Array.from(document.querySelectorAll(tagName));
        return (
          candidates.find((el) => {
            const match = (el.textContent || '').trim().includes(text);
            return match && (!predicate || predicate(el));
          }) || null
        );
      }

      return selectorList.map(({ name, selector, text, tagName, navItem }) => {
        let el = null;

        if (selector) {
          el = document.querySelector(selector);
        } else if (navItem) {
          el = findByText('nav a', navItem, (node) => node.className.includes('group'));
        } else {
          el = findByText(tagName || '*', text || '');
        }

        if (!el) {
          return { name, found: false };
        }

        const rect = el.getBoundingClientRect();
        return {
          name,
          found: true,
          width: Math.round(rect.width),
          height: Math.round(rect.height),
        };
      });
    }, selectors);

    console.log(`\n=== ${route} touch targets ===`);
    console.log(JSON.stringify(result, null, 2));
  }

  try {
    await measure('/', [
      { name: 'Portfolio nav item', navItem: 'Portfolio' },
      { name: 'Wallets nav item', navItem: 'Wallets' },
      { name: 'Refresh button', tagName: 'button', text: 'Refresh Data' },
      { name: 'Asset tab select trigger', selector: 'button[aria-label="Asset categories"]' },
    ]);

    await measure('/wallets', [
      { name: 'Portfolio nav item', navItem: 'Portfolio' },
      { name: 'Wallets nav item', navItem: 'Wallets' },
      { name: 'Refresh button', tagName: 'button', text: 'Refresh Data' },
      {
        name: 'Wallet tab select trigger',
        selector: 'button[aria-label="Blockchain wallet categories"]',
      },
    ]);
  } finally {
    await browser.close();
  }
})();
