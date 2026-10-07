/** window.open / <a>.click çağrılarını kaydeder ve gerçek gezintiyi engeller. */
export async function installLinkHook(s) {
  await s.ctx.addInitScript(() => {
    window.__links = [];
    const rec = (kind, url, target) => window.__links.push({ kind, url: String(url), target });
    const wo = window.open;
    window.open = function (url, target, feat) { rec('open', url, target); return null; };
    const ac = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () { rec('a.click', this.href, this.target); };
    const dis = EventTarget.prototype.dispatchEvent;
    EventTarget.prototype.dispatchEvent = function (e) {
      if (this instanceof HTMLAnchorElement && e && e.type === 'click') { rec('a.dispatch', this.href, this.target); return true; }
      return dis.call(this, e);
    };
  });
}
export const links = (s) => s.page.evaluate(() => window.__links || []);
