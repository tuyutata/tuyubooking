import type {LinguiConfig} from "@lingui/conf";

const config: LinguiConfig = {
    locales: ["zh-cn", "en"],
    catalogs: [
        {
            path: "<rootDir>/src/locales/{locale}",
            include: ["src"],
        },
    ],
    sourceLocale: "en",
    format: "po",
    fallbackLocales: {
       default: "zh-cn",
    }
};

export default config;
