import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  env: {
    NEXT_PUBLIC_API_URL:
      process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080",
  },
  webpack: (config, { isServer }) => {
    // Cloudflare Workers特有のスキームを外部モジュールとして扱う
    if (isServer) {
      config.externals = config.externals || [];
      config.externals.push({
        "cloudflare:workers": "commonjs cloudflare:workers",
      });
    }
    return config;
  },
};

export default nextConfig;
