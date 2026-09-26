// Captures the fixed scene set used for UI redesign before/after comparison.
// Usage:
//   PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs \
//   BROWSER_BASE_URL=http://127.0.0.1:43011 \
//   BROWSER_OUTPUT_DIR=/tmp/xbh-redesign/before node tools/redesign_compare_capture.mjs
// The same script must be run against both builds so every scene uses the same
// route, viewport, theme, input and wait strategy.
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.BROWSER_BASE_URL || 'http://127.0.0.1:43011';
const output = process.env.BROWSER_OUTPUT_DIR || '/tmp/xbh-redesign';
mkdirSync(output, { recursive: true, mode: 0o700 });

const desktop = { width: 1440, height: 1000, mobile: false };
const mobile = { width: 390, height: 844, mobile: true };
const scenes = [
  { name: 'desktop-light-feed', viewport: desktop, scheme: 'light', route: '/feed', settle: 3000 },
  { name: 'desktop-dark-feed', viewport: desktop, scheme: 'dark', route: '/feed', settle: 3000 },
  { name: 'mobile-light-feed', viewport: mobile, scheme: 'light', route: '/feed', settle: 3000 },
  { name: 'mobile-light-post', viewport: mobile, scheme: 'light', route: '/post/7', settle: 2000 },
  { name: 'desktop-light-post', viewport: desktop, scheme: 'light', route: '/post/1', settle: 2500 },
  { name: 'mobile-dark-search', viewport: mobile, scheme: 'dark', route: '/search', search: '手机' },
  { name: 'mobile-light-agent-questions', viewport: mobile, scheme: 'light', route: '/messages/assistant', agent: '比较社区中的方案' },
];

async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 30000 });
  await placeholder.evaluate(element => element.click());
  await page.locator('flt-semantics').first().waitFor({ state: 'attached' });
}

async function type(page, text, index = 0) {
  const field = page.getByRole('textbox').nth(index);
  await field.waitFor();
  const box = await field.boundingBox();
  assert(box && box.width > 0);
  await page.mouse.click(box.x + Math.min(60, box.width / 2), box.y + Math.min(15, box.height / 2));
  await page.waitForFunction(element => document.activeElement === element && element.style.font !== '', await field.elementHandle());
  await page.keyboard.insertText(text);
  await page.waitForFunction(({ element, value }) => element.value === value, { element: await field.elementHandle(), value: text });
}

const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
const report = { browser: browser.version(), base, scenes: [] };
try {
  for (const scene of scenes) {
    const context = await browser.newContext({
      viewport: { width: scene.viewport.width, height: scene.viewport.height },
      colorScheme: scene.scheme,
      reducedMotion: 'reduce',
      isMobile: scene.viewport.mobile,
      hasTouch: scene.viewport.mobile,
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`${base}/#${scene.route}`);
    await enableSemantics(page);
    await page.waitForLoadState('networkidle');
    if (scene.search) {
      await type(page, scene.search);
      await page.keyboard.press('Enter');
      await page.getByRole('button', { name: /2026年最值得入手/ }).first().waitFor({ timeout: 20000 });
      // Blur the field so neither build shows a caret or selection highlight.
      await page.mouse.click(scene.viewport.width / 2, scene.viewport.height - 120);
    }
    if (scene.agent) {
      await page.waitForTimeout(1500);
      await type(page, scene.agent);
      await page.getByRole('button', { name: '发送', exact: true }).click();
      await page.getByRole('checkbox', { name: '使用成本', exact: true }).waitFor({ timeout: 20000 });
    }
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(scene.settle ?? 1200);
    const file = `${scene.name}.png`;
    await page.screenshot({ path: `${output}/${file}` });
    const overflow = await page.evaluate(() => document.body.scrollWidth > innerWidth);
    report.scenes.push({ ...scene, file, errors, overflow });
    assert.deepEqual(errors, [], `${file}: page errors`);
    assert.equal(overflow, false, `${file}: horizontal overflow`);
    console.log(JSON.stringify({ file, errors: errors.length }));
    await context.close();
  }
} finally {
  await browser.close();
  writeFileSync(`${output}/report.json`, `${JSON.stringify(report, null, 2)}\n`, { mode: 0o600 });
}
