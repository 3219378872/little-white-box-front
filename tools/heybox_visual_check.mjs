import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const { chromium, devices } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.BROWSER_BASE_URL || 'http://127.0.0.1:43007';
const output = process.env.BROWSER_OUTPUT_DIR || '/tmp/xbh-heybox-browser';
mkdirSync(output, { recursive: true, mode: 0o700 });
const browser = await chromium.launch({ headless: true });
const report = { browser: browser.version(), mode: 'isolated-mock-release', pages: [] };
const routes = [
  ['feed', '/feed'], ['post', '/post/1'], ['search', '/search'],
  ['messages', '/messages'], ['assistant', '/messages/assistant'],
  ['memory', '/messages/assistant/memory'], ['watch', '/messages/assistant/watch'],
  ['thread', '/messages/1?targetUserId=2&targetUserName=测试用户'],
  ['editor', '/post/new'], ['edit-profile', '/profile/edit'], ['profile', '/profile'],
];

async function type(page, text, index = 0) {
  const field = page.getByRole('textbox').nth(index);
  const box = await field.boundingBox();
  assert(box && box.width > 0);
  await page.mouse.click(box.x + Math.min(40, box.width / 2), box.y + 15);
  await page.waitForFunction(element => document.activeElement === element && element.style.font !== '', await field.elementHandle());
  await page.keyboard.insertText(text);
  await page.waitForFunction(({ element, value }) => element.value === value, { element: await field.elementHandle(), value: text });
}

async function capture(page, variant, name, errors, failures) {
  await page.waitForTimeout(600);
  const file = `${variant.name}-${name}.png`;
  await page.screenshot({ path: `${output}/${file}` });
  const deviation = Number(execFileSync('identify', ['-format', '%[standard-deviation]', `${output}/${file}`], { encoding: 'utf8' }));
  assert(deviation > 500, `${file}: blank frame`);
  const snapshot = await page.locator('body').ariaSnapshot();
  assert(snapshot.length > 20, `${file}: empty semantics`);
  const size = await page.evaluate(() => ({ width: document.body.scrollWidth, viewport: innerWidth }));
  assert(size.width <= size.viewport, `${file}: horizontal overflow`);
  report.pages.push({ viewport: variant, page: name, file, deviation, size, errors: [...errors], failures: [...failures], snapshot });
  writeFileSync(`${output}/report.json`, `${JSON.stringify(report, null, 2)}\n`, { mode: 0o600 });
  assert.deepEqual(errors, [], `${file}: browser errors`);
  console.log(JSON.stringify({ file, errors: errors.length, failedRequests: failures.length, deviation }));
}

try {
  for (const variant of [
    { name: 'mobile-light', width: 390, height: 844, colorScheme: 'light' },
    { name: 'mobile-dark', width: 390, height: 844, colorScheme: 'dark' },
    { name: 'desktop-light', width: 1440, height: 1000, colorScheme: 'light' },
    { name: 'desktop-dark', width: 1440, height: 1000, colorScheme: 'dark' },
    { name: 'narrow-light', width: 320, height: 740, colorScheme: 'light' },
  ]) {
    const context = await browser.newContext({
      ...(variant.width < 600 ? devices['Pixel 7'] : {}),
      viewport: { width: variant.width, height: variant.height },
      colorScheme: variant.colorScheme, reducedMotion: 'reduce',
      isMobile: variant.width < 600, deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    const errors = [], failures = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('requestfailed', request => failures.push({ url: request.url(), error: request.failure()?.errorText }));
    for (const [name, route] of routes) {
      errors.length = failures.length = 0;
      await page.goto('about:blank');
      await page.goto(`${base}/#${route}`);
      const accessibility = page.locator('flt-semantics-placeholder');
      await accessibility.waitFor({ state: 'attached', timeout: 30000 });
      if (variant.width < 600) {
        // Android's TalkBack activation is a center tap on the full-view placeholder.
        await accessibility.click({ force: true });
      } else {
        await accessibility.evaluate(element => element.click());
      }
      await page.locator('flt-semantics').first().waitFor({ state: 'attached' });
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(name === 'feed' ? 2500 : 1000);
      await capture(page, variant, name, errors, failures);
      if (name === 'feed') {
        await page.getByRole('button', { name: /探店｜藏在巷子里的宝藏面馆/ }).first().click();
        await page.getByRole('button', { name: '正文', exact: true }).waitFor();
        if (variant.width < 600) {
          assert.equal(await page.getByRole('button', { name: /第 1 个标签，共 5 个/ }).count(), 0);
        }
        await capture(page, variant, 'feed-push-post', errors, failures);
        await page.getByRole('button', { name: '返回', exact: true }).click();
        await page.getByRole('tab', { name: '推荐', exact: true }).waitFor();
        if (variant.width < 600) {
          await page.getByRole('button', { name: /第 1 个标签，共 5 个/ }).waitFor();
        }
        await capture(page, variant, 'feed-return', errors, failures);
      }
      if (name === 'post') {
        await page.getByRole('button', { name: /^查看评论/ }).click();
        await capture(page, variant, 'comments', errors, failures);
        await page.getByRole('button', { name: '正文', exact: true }).click();
        await type(page, '这是一条尚未发送的评论');
        await page.getByRole('button', { name: '发送评论', exact: true }).waitFor();
        assert.equal(await page.getByRole('button', { name: /^查看评论/ }).count(), 0);
        await capture(page, variant, 'comment-compose', errors, failures);
      }
      if (name === 'search') {
        await type(page, '手机');
        const fieldBox = await page.getByRole('textbox').boundingBox();
        let searched = false;
        for (const button of await page.getByRole('button', { name: '搜索', exact: true }).all()) {
          const box = await button.boundingBox();
          if (box && Math.abs(box.y + box.height / 2 - fieldBox.y - fieldBox.height / 2) < 12) {
            await button.click();
            searched = true;
            break;
          }
        }
        assert(searched, 'search command must align with its field');
        await page.getByRole('button', { name: /2026年最值得入手/ }).first().waitFor();
        await capture(page, variant, 'search-results', errors, failures);
      }
      if (name === 'editor') {
        await type(page, '标题'.repeat(60));
        await type(page, '正文内容与多行输入\n保留当前业务的标题、正文和图片限制。', 1);
        await capture(page, variant, 'editor-draft', errors, failures);
      }
      if (name === 'memory' || name === 'watch') {
        const action = name === 'memory' ? '新增记忆' : '创建追踪';
        await page.getByRole('button', { name: action, exact: true }).click();
        await capture(page, variant, `${name}-dialog`, errors, failures);
        await page.getByRole('button', { name: '取消', exact: true }).click();
      }
      if (name === 'assistant') {
        await page.getByRole('button', { name: '更多操作', exact: true }).click();
        await capture(page, variant, 'assistant-menu', errors, failures);
        await page.getByRole('button', { name: '更多操作', exact: true }).click();
      }
      if (name === 'thread') {
        await type(page, '这是一条尚未发送的私信');
        await capture(page, variant, 'thread-compose', errors, failures);
      }
    }
    await page.getByRole('button', { name: '退出登录', exact: true }).click();
    await page.getByRole('tab', { name: '密码登录', exact: true }).waitFor();
    await capture(page, variant, 'login', errors, failures);
    await page.getByRole('tab', { name: '验证码登录', exact: true }).click();
    await capture(page, variant, 'code-login', errors, failures);
    await page.getByRole('button', { name: '没有账号？去注册', exact: true }).click();
    await capture(page, variant, 'register', errors, failures);
    await context.close();
  }
} finally {
  await browser.close();
}
