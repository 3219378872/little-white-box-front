import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.BROWSER_BASE_URL || 'http://127.0.0.1:43004';
const output = process.env.BROWSER_OUTPUT_DIR || '/tmp/xbh-research-browser';
mkdirSync(output, { recursive: true, mode: 0o700 });
const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
const reports = [];

async function click(page, locator) {
  await locator.waitFor();
  const box = await locator.boundingBox();
  assert(box && box.width > 0 && box.height > 0, 'control must have a visible hit target');
  await locator.click();
}

try {
  for (const variant of [
    { name: 'desktop-light', width: 1440, height: 1000, colorScheme: 'light' },
    { name: 'mobile-light', width: 390, height: 844, colorScheme: 'light' },
    { name: 'mobile-dark', width: 390, height: 844, colorScheme: 'dark' },
  ]) {
    const context = await browser.newContext({
      viewport: { width: variant.width, height: variant.height },
      colorScheme: variant.colorScheme,
      reducedMotion: 'reduce',
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`${base}/#/messages/assistant`);
    const accessibility = page.locator('flt-semantics-placeholder');
    await accessibility.waitFor({ state: 'attached' });
    await accessibility.evaluate(element => element.click());
    const send = page.getByRole('button', { name: '发送', exact: true });
    // History loading disables commands while leaving the editing surface visible.
    await send.click({ trial: true });
    const composer = page.getByRole('textbox', { name: /^消息/ });
    await composer.waitFor();
    const bounds = await composer.boundingBox();
    assert(bounds);
    // Focus the actual Flutter editing surface before entering text.
    await page.mouse.click(bounds.x + Math.min(80, bounds.width / 2), bounds.y + Math.min(15, bounds.height / 2));
    // Flutter attaches the editing client after focusing its semantics textarea.
    await page.waitForFunction(element => document.activeElement === element && element.style.font !== '', await composer.elementHandle());
    await page.keyboard.insertText('比较社区中的方案');
    await page.waitForFunction(element => element.value === '比较社区中的方案', await composer.elementHandle());
    assert.equal(await composer.inputValue(), '比较社区中的方案');
    await click(page, send);
    const choice = page.getByRole('checkbox', { name: '使用成本', exact: true });
    await choice.waitFor({ timeout: 20000 });
    await page.screenshot({ path: `${output}/${variant.name}-questions.png` });
    await click(page, choice);
    await click(page, page.getByRole('button', { name: '提交回答', exact: true }));
    const original = page.getByRole('button', { name: '查看原文', exact: true });
    await original.first().waitFor({ timeout: 20000 });
    await page.getByRole('button', { name: '停止生成', exact: true }).waitFor({ state: 'hidden' });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);
    assert.equal(await original.count(), 2, 'one card per retrieved source');
    const visibleLabels = await page.locator('[aria-label]').evaluateAll(elements => elements.map(element => element.getAttribute('aria-label')).join('\n'));
    assert(!visibleLabels.includes('连接意外中断'), 'waiting must not produce a transport failure');
    await page.screenshot({ path: `${output}/${variant.name}-answer.png` });
    const citation = page.getByRole('button', { name: '[1]', exact: true });
    await click(page, citation);
    await page.waitForTimeout(250);
    await page.screenshot({ path: `${output}/${variant.name}-citation.png` });
    await click(page, original.first());
    const back = page.getByRole('button', { name: /^(Back|返回)$/ }).first();
    await back.waitFor();
    await page.screenshot({ path: `${output}/${variant.name}-post.png` });
    await click(page, back);
    await page.getByRole('button', { name: '查看原文', exact: true }).first().waitFor();
    assert.equal(await page.getByRole('button', { name: '查看原文', exact: true }).count(), 2, 'returning to history must not duplicate cards');
    assert.deepEqual(errors, []);
    reports.push({ viewport: variant.name, sourceCards: 2, question: 'answered', sourceNavigation: 'passed', historyReturn: 'passed', pageErrors: errors });
    await context.close();
  }
} finally {
  await browser.close();
}
writeFileSync(`${output}/report.json`, `${JSON.stringify(reports, null, 2)}\n`, { mode: 0o600 });
console.log(JSON.stringify(reports));
