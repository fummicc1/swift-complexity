"use client";

import Editor from "@monaco-editor/react";

type CodeEditorProps = {
  value: string;
  onChange: (value: string | undefined) => void;
  height?: string;
};

export default function CodeEditor({
  value,
  onChange,
  height = "500px",
}: CodeEditorProps) {
  return (
    <Editor
      height={height}
      defaultLanguage="swift"
      value={value}
      onChange={onChange}
      theme="vs-dark"
      options={{
        minimap: { enabled: false },
        fontSize: 14,
        lineNumbers: "on",
        roundedSelection: false,
        scrollBeyondLastLine: false,
        automaticLayout: true,
      }}
    />
  );
}
