#!/bin/bash
# Re-fetches the JS/CSS libraries into Web/vendor.
# Only needed to upgrade them; the copies are kept in the repo so build.sh works offline.
set -euo pipefail
cd "$(dirname "$0")/vendor-src"
[ -f package.json ] || echo '{"private":true}' > package.json
npm install --silent markdown-it markdown-it-texmath markdown-it-footnote markdown-it-task-lists katex mermaid @highlightjs/cdn-assets
N=node_modules
V=../../Web/vendor
rm -rf "$V" && mkdir -p "$V/katex"
cp $N/markdown-it/dist/browser/markdown-it.umd.min.js           "$V/markdown-it.min.js"
cp $N/markdown-it-texmath/texmath.js                             "$V/texmath.js"
cp $N/markdown-it-footnote/dist/markdown-it-footnote.min.js      "$V/markdown-it-footnote.min.js"
cp $N/markdown-it-task-lists/dist/markdown-it-task-lists.min.js  "$V/markdown-it-task-lists.min.js"
cp $N/katex/dist/katex.min.js $N/katex/dist/katex.min.css        "$V/katex/"
cp -R $N/katex/dist/fonts                                        "$V/katex/fonts"
cp $N/mermaid/dist/mermaid.min.js                                "$V/mermaid.min.js"
cp $N/@highlightjs/cdn-assets/highlight.min.js                   "$V/highlight.min.js"
cp $N/@highlightjs/cdn-assets/styles/github-dark.min.css         "$V/hljs-github-dark.min.css"
echo "vendored into $V"
