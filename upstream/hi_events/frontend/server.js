import express from "express";
import {createServer} from "node:https";
import {installGlobals} from "@remix-run/node";
import process from "process";
import compression from "compression";
import fs from "node:fs/promises";
import sirv from "sirv";
import cookieParser from "cookie-parser";
import path from "node:path";
import {fileURLToPath} from "node:url";
import * as nodePath from "node:path";
import * as nodeUrl from "node:url";
import "dotenv/config";
import {sitemapIndexHandler, sitemapEventsHandler, sitemapOrganizersHandler} from "./src/sitemap/proxy.js";
import {htmlSafeJsonStringify} from "./src/utilites/safeScriptJson.js";

installGlobals();

async function main() {
    const base = process.env.BASE || "/";
    const port = process.argv.includes("--port")
        ? process.argv[process.argv.indexOf("--port") + 1]
        : process.env.NODE_PORT || 5678;
    const isProduction = process.env.NODE_ENV === "production";

    const __dirname = path.dirname(fileURLToPath(import.meta.url));

    const templateHtml = isProduction
        ? await fs.readFile("./dist/client/index.html", "utf-8")
        : "";

    const ssrManifest = isProduction
        ? await fs.readFile("./dist/client/.vite/ssr-manifest.json", "utf-8")
        : undefined;

    const app = express();
    app.use(cookieParser());

    app.get('/tuyu_admin', (_req, res) => {
        res.setHeader('Cache-Control', 'no-store');
        res.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'");
        res.setHeader('Referrer-Policy', 'no-referrer');
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.type('html').send(`<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>途遇旅行票务管理</title><body><p id="status">正在验证途遇管理员身份...</p><script>
const status = document.getElementById('status');
const token = new URLSearchParams(location.hash.slice(1)).get('assertion');
history.replaceState(null, '', location.pathname);
if (!token) { status.textContent = '管理员断言缺失'; } else {
  fetch('/api/tuyu-admin/consume', {method:'POST', headers:{'content-type':'application/json'}, body:JSON.stringify({assertion_token:token}), credentials:'same-origin'})
    .then(async response => { if (!response.ok) throw new Error('rejected'); return response.json(); })
    .then(result => { localStorage.setItem('token', result.token); location.replace(result.redirect || '/manage/events'); })
    .catch(() => { status.textContent = '管理员断言无效或已过期'; });
}
</script></body></html>`);
    });

    app.use('/.well-known', express.static(path.join(__dirname, 'public/.well-known')));

    let vite;

    if (!isProduction) {
        const {createServer: viteServer} = await import("vite");
        vite = await viteServer({
            server: { middlewareMode: true },
            appType: "custom",
            base,
        });

        app.use(vite.middlewares);
    } else {
        app.use(compression());
        app.use(base, sirv(path.join(__dirname, "./dist/client"), { extensions: [] }));
    }

    const getViteEnvironmentVariables = () => {
        const envVars = {};
        for (const key in process.env) {
            if (key.startsWith('VITE_')) {
                envVars[key] = process.env[key];
            }
        }
        return htmlSafeJsonStringify(envVars);
    };

    app.get('/robots.txt', (req, res) => {
        const frontendUrl = process.env.VITE_FRONTEND_URL || `${req.protocol}://${req.get('host')}`;
        const robotsTxt = `User-agent: *
Allow: /

Sitemap: ${frontendUrl}/sitemap.xml
`;
        res.setHeader('Content-Type', 'text/plain');
        res.setHeader('Cache-Control', 'public, max-age=86400');
        res.status(200).send(robotsTxt);
    });

    app.get('/sitemap.xml', sitemapIndexHandler);
    app.get('/sitemap-events-:page.xml', sitemapEventsHandler);
    app.get('/sitemap-organizers-:page.xml', sitemapOrganizersHandler);

    app.use("*", async (req, res) => {
        const url = req.originalUrl.replace(base, "");

        try {
            let template;
            let render;

            if (!isProduction) {
                template = await fs.readFile(path.join(__dirname, "./index.html"), "utf-8");
                template = await vite.transformIndexHtml(url, template);
                render = (await vite.ssrLoadModule("/src/entry.server.tsx")).render;
            } else {
                template = templateHtml;
                render = (await dynamicImport(path.join(__dirname, "./dist/server/entry.server.js"))).render;
            }

            const { appHtml, dehydratedState, helmetContext } = await render(
                { req, res },
                ssrManifest
            );
            const stringifiedState = htmlSafeJsonStringify(dehydratedState);

            const helmetHtml = Object.values(helmetContext.helmet || {})
                .map((value) => value.toString() || "")
                .join(" ");

            const envVariablesHtml = `<script>window.hievents = ${getViteEnvironmentVariables()};</script>`;

            const headSnippets = [];
            if (process.env.VITE_FATHOM_SITE_ID) {
                headSnippets.push(`
                <script src="https://cdn.usefathom.com/script.js" data-spa="auto" data-site="${process.env.VITE_FATHOM_SITE_ID}" defer></script>
            `);
            }

            const html = template
                .replace("<!--head-snippets-->", () => headSnippets.join("\n"))
                .replace("<!--app-html-->", () => appHtml)
                .replace("<!--dehydrated-state-->", () => `<script>window.__REHYDRATED_STATE__ = ${stringifiedState}</script>`)
                .replace("<!--environment-variables-->", () => envVariablesHtml)
                .replace(/<!--render-helmet-->.*?<!--\/render-helmet-->/s, () => helmetHtml);

            res.setHeader("Content-Type", "text/html");
            return res.status(200).end(html);
        } catch (error) {
            if (error instanceof Response) {
                if (error.status >= 300 && error.status < 400) {
                    return res.redirect(error.status, error.headers.get("Location") || "/");
                } else {
                    return res.status(error.status).send(await error.text());
                }
            }

            console.error(error);
            res.status(500).send("Internal Server Error");
        }
    });

    // 商家SSR仅监听本机HTTPS；缺少证书或私钥时启动失败，禁止明文回退。
    if (!process.env.TUYU_TLS_CERT_FILE || !process.env.TUYU_TLS_KEY_FILE) {
        throw new Error("Hi.Events requires explicit TLS certificate and private-key paths");
    }
    const tls = {
        cert: await fs.readFile(process.env.TUYU_TLS_CERT_FILE),
        key: await fs.readFile(process.env.TUYU_TLS_KEY_FILE),
        minVersion: "TLSv1.2",
    };
    createServer(tls, app).listen(port, "127.0.0.1", () => {
        console.info(`SSR Serving at https://127.0.0.1:${port}`);
    });

    const dynamicImport = async (path) => {
        return import(
            nodePath.isAbsolute(path) ? nodeUrl.pathToFileURL(path).toString() : path
        );
        
    }
}
main();
