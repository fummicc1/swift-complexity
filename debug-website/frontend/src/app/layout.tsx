import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Swift Complexity Analyzer",
  description: "Interactive web-based Swift code complexity analyzer",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.Node;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
