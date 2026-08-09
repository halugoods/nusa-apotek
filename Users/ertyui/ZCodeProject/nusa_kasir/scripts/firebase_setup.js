// Firebase Auto-Setup Script (Stealth)
// Logs into Google, registers Android app in Firebase, downloads google-services.json, enables Google Auth
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const fs = require('fs');
const path = require('path');

const GOOGLE_EMAIL = 'halugoods.indonesia@gmail.com';
const GOOGLE_PASSWORD = 'Dsseemms280303';
const FIREBASE_PROJECT_NUMBER = '116430341615';
const ANDROID_PACKAGE = 'com.nusa.kasir';
const SHA1 = '55:1B:F0:88:EF:62:0C:48:6E:7F:18:DD:DD:D7:C8:30:5B:23:48:38';

const SCRIPT_DIR = __dirname;
const OUTPUT_DIR = path.resolve(__dirname, '..', 'android', 'app');

function screenshot(page, name) {
  const fp = path.resolve(SCRIPT_DIR, name);
  return page.screenshot({ path: fp, fullPage: true });
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function typeInto(page, selector, text) {
  await page.waitForSelector(selector, { visible: true, timeout: 15000 });
  await page.click(selector);
  await sleep(300);
  // Clear existing text
  await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (el) el.value = '';
  }, selector);
  await page.type(selector, text, { delay: 50 });
}

(async () => {
  console.log('Launching browser (stealth mode)...');
  const browser = await puppeteer.launch({
    headless: false,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-blink-features=AutomationControlled',
    ],
    defaultViewport: { width: 1366, height: 768 },
  });

  const page = await browser.newPage();

  // Mask navigator.webdriver
  await page.evaluateOnNewDocument(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
  });

  try {
    // ── Step 1: Login Google ──
    console.log('Step 1: Logging into Google...');
    await page.goto('https://accounts.google.com/signin/v2/identifier?flowName=GlifWebSignIn&continue=https://console.firebase.google.com', {
      waitUntil: 'networkidle2',
      timeout: 30000,
    });
    await sleep(3000);
    await screenshot(page, 'step1_google_login.png');
    console.log('Page URL:', page.url());

    // Try multiple selectors for email input
    const emailSelectors = [
      'input[type="email"]',
      'input[name="identifier"]',
      'input#identifierId',
    ];
    for (const sel of emailSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await typeInto(page, sel, GOOGLE_EMAIL);
          console.log('Entered email via:', sel);
          break;
        }
      } catch (e) {
        // next
      }
    }

    await sleep(1000);
    await page.keyboard.press('Enter');
    await sleep(4000);
    await screenshot(page, 'step1b_password.png');
    console.log('After email submit, URL:', page.url());

    // Password step
    const passSelectors = [
      'input[type="password"]',
      'input[name="Passwd"]',
      'input[name="password"]',
    ];
    for (const sel of passSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await typeInto(page, sel, GOOGLE_PASSWORD);
          console.log('Entered password via:', sel);
          break;
        }
      } catch (e) {
        // next
      }
    }

    await sleep(1000);
    await page.keyboard.press('Enter');
    await sleep(6000);
    await screenshot(page, 'step1c_logged_in.png');
    console.log('After password submit, URL:', page.url());

    // Sometimes Google shows a recovery phone / "Confirm it's you" screen
    // Check if we see "Not now" or skip link
    const notNowSelectors = [
      'button:has-text("Not now")',
      'button:has-text("Skip")',
      'a:has-text("Not now")',
      'div[role="button"]:has-text("Confirm")',
    ];
    for (const sel of notNowSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          console.log('Found:', sel, '— clicking');
          await el.click();
          await sleep(2000);
        }
      } catch (e) {}
    }

    // Wait until we're at the Firebase Console
    await sleep(3000);
    console.log('Current URL:', page.url());
    await screenshot(page, 'step1d_final_login_state.png');

    // ── Step 2: Navigate to Firebase Project Settings ──
    console.log('Step 2: Opening project settings...');
    const projectUrl = `https://console.firebase.google.com/project/${FIREBASE_PROJECT_NUMBER}/settings/general`;
    await page.goto(projectUrl, {
      waitUntil: 'networkidle2',
      timeout: 30000,
    });
    await sleep(4000);
    await screenshot(page, 'step2_project_settings.png');
    console.log('Project settings URL:', page.url());

    // ── Step 3: Add Android App ──
    console.log('Step 3: Looking for "Add app" button...');

    // Scroll down to apps section
    await page.evaluate(() => window.scrollBy(0, 600));
    await sleep(1000);

    const addAppSelectors = [
      'button:has-text("Add app")',
      'a:has-text("Add app")',
      'span:has-text("Add app")',
      'material-button:has-text("Add app")',
      'button[aria-label="Add app"]',
    ];

    let clicked = false;
    for (const sel of addAppSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Clicked:', sel);
          clicked = true;
          break;
        }
      } catch (e) {}
    }

    await sleep(2000);
    await screenshot(page, 'step3_add_app_dialog.png');
    console.log('Current URL after add app click:', page.url());

    // Select Android platform
    const androidSelectors = [
      'div:has-text("Android")',
      'span:has-text("Android")',
      'button:has-text("Android")',
      'material-icon mat-icon[data-mat-icon-name="android"]',
      '.platform-option:has-text("Android")',
      'a:has-text("Android")',
    ];
    for (const sel of androidSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Selected Android via:', sel);
          break;
        }
      } catch (e) {}
    }

    await sleep(3000);
    await screenshot(page, 'step3b_after_android_select.png');
    console.log('URL after selecting Android:', page.url());

    // ── Step 4: Fill registration form ──
    console.log('Step 4: Filling registration form...');

    // Try all possible input fields
    const allInputs = await page.$$('input:not([type="hidden"]):not([disabled])');
    console.log(`Found ${allInputs.length} visible inputs`);

    // Strategy: find inputs by label text
    const inputPairs = await page.evaluate(() => {
      const pairs = [];
      const labels = document.querySelectorAll('label');
      labels.forEach(label => {
        const text = label.textContent?.toLowerCase() || '';
        const input = label.parentElement?.querySelector('input') || 
                     label.nextElementSibling?.querySelector('input') ||
                     label.nextElementSibling?.matches('input') ? label.nextElementSibling : null;
        if (input) {
          pairs.push({ label: text.trim(), id: input.id, name: input.name });
        }
      });
      return pairs;
    });
    console.log('Found label-input pairs:', JSON.stringify(inputPairs, null, 2));

    // Fill Android package name
    for (const pair of inputPairs) {
      if (pair.label.includes('package') || pair.label.includes('nama paket')) {
        const sel = pair.id ? `#${pair.id}` : `input[name="${pair.name}"]`;
        await typeInto(page, sel, ANDROID_PACKAGE);
        console.log('Filled package name field:', pair.label);
        break;
      }
    }

    await sleep(500);

    // Fill SHA-1 if there's a field for it
    for (const pair of inputPairs) {
      if (pair.label.includes('sha') || pair.label.includes('sidik') || pair.label.includes('certificate')) {
        const sel = pair.id ? `#${pair.id}` : `input[name="${pair.name}"]`;
        await typeInto(page, sel, SHA1);
        console.log('Filled SHA-1 field:', pair.label);
        break;
      }
    }

    await screenshot(page, 'step4_form_filled.png');

    // ── Step 5: Click Register ──
    console.log('Step 5: Clicking Register...');
    const registerSelectors = [
      'button:has-text("Register app")',
      'button:has-text("Register")',
      'input[type="submit"]',
      'button[type="submit"]',
      'material-button:has-text("Register")',
    ];

    for (const sel of registerSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Clicked Register via:', sel);
          clicked = true;
          break;
        }
      } catch (e) {}
    }

    await sleep(5000);
    await screenshot(page, 'step5_after_register.png');
    console.log('After register, URL:', page.url());

    // ── Step 6: Download google-services.json ──
    console.log('Step 6: Downloading google-services.json...');
    
    // Set up download - Puppeteer
    const client = await page.target().createCDPSession();
    await client.send('Page.setDownloadBehavior', {
      behavior: 'allow',
      downloadPath: OUTPUT_DIR,
    });

    const downloadSelectors = [
      'button:has-text("Download google-services.json")',
      'a:has-text("google-services.json")',
      'button:has-text("google-services")',
      'a[download]',
      'button:has-text("Download")',
    ];

    for (const sel of downloadSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Clicked download via:', sel);
          break;
        }
      } catch (e) {}
    }

    await sleep(3000);
    await screenshot(page, 'step6_after_download.png');
    console.log(`google-services.json → ${OUTPUT_DIR}`);

    // ── Step 7: Enable Google Sign-In ──
    console.log('Step 7: Enabling Google Sign-In...');
    const authUrl = `https://console.firebase.google.com/project/${FIREBASE_PROJECT_NUMBER}/authentication/providers`;
    await page.goto(authUrl, {
      waitUntil: 'networkidle2',
      timeout: 30000,
    });
    await sleep(4000);
    await screenshot(page, 'step7_auth_providers.png');
    console.log('Auth providers URL:', page.url());

    // Click "Add new provider" or look for Google row with "Enable" button
    const enableGoogleSelectors = [
      'tr:has-text("Google") button:has-text("Enable")',
      'div:has-text("Google") button',
      'button[aria-label*="Google"]',
      'span:has-text("Google") ~ button',
      'button:has-text("Add new provider")',
    ];

    for (const sel of enableGoogleSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Clicked:', sel);
          await sleep(3000);
          break;
        }
      } catch (e) {}
    }

    await screenshot(page, 'step7b_google_provider.png');

    // Look for enable toggle/switch
    const enableToggleSelectors = [
      'input[type="checkbox"][aria-label*="Enable"]',
      'mat-slide-toggle:has-text("Enable")',
      'label:has-text("Enable") input',
      'button:has-text("Enable")',
      'button:has-text("Aktifkan")',
    ];

    for (const sel of enableToggleSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Enabled via:', sel);
          await sleep(1000);
        }
      } catch (e) {}
    }

    // Click Save
    const saveSelectors = [
      'button:has-text("Save")',
      'button:has-text("Simpan")',
      'input[type="submit"][value*="Save"]',
      'material-button:has-text("Save")',
    ];

    for (const sel of saveSelectors) {
      try {
        const el = await page.$(sel);
        if (el) {
          await el.click();
          console.log('Saved via:', sel);
          break;
        }
      } catch (e) {}
    }

    await sleep(3000);
    await screenshot(page, 'step7c_auth_enabled.png');
    
    console.log('\n✅ SETUP COMPLETE!');
    console.log('Screenshots saved in scripts/ folder for verification.');
    
    // Keep browser open
    await sleep(10000);

  } catch (err) {
    console.error('FATAL ERROR:', err.message);
    console.error(err.stack);
    await screenshot(page, 'FATAL_ERROR.png');
  } finally {
    await browser.close();
    console.log('Browser closed.');
  }
})();
