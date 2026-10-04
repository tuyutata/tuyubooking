import {i18n} from "@lingui/core";

export type SupportedLocales = "zh-cn" | "en";
export const availableLocales: SupportedLocales[] = ["zh-cn", "en"];
export const localeToFlagEmojiMap: Record<SupportedLocales, string> = {"zh-cn": "CN", en: "EN"};
export const localeToNameMap: Record<SupportedLocales, string> = {"zh-cn": "简体中文", en: "English"};
export const getLocaleName = (locale: SupportedLocales) => localeToNameMap[locale];

export const getSupportedLocale = (userLocale: string): SupportedLocales => {
    const normalized = userLocale.toLowerCase();
    return normalized === "en" || normalized.startsWith("en-") ? "en" : "zh-cn";
};

export const getClientLocale = (): SupportedLocales => {
    if (typeof window === "undefined") return "zh-cn";
    const stored = document.cookie.split(";")
        .find((value) => value.trim().startsWith("locale="))?.split("=")[1];
    return getSupportedLocale(stored || window.navigator.language);
};

export async function dynamicActivateLocale(locale: string) {
    const supported = getSupportedLocale(locale);
    const module = await import(`./locales/${supported}.po`);
    i18n.load(supported, module.messages);
    i18n.activate(supported);
}
