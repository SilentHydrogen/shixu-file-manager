const path = require('node:path');
const fs = require('node:fs');
const esbuild = require(process.env.ESBUILD_PATH || 'esbuild');
const root = __dirname;
esbuild.build({ entryPoints: [path.join(root, 'src/runtime.js')], bundle: true, format: 'esm', platform: 'browser',
  target: 'es2020', outfile: path.join(root, 'index.js'), external: ['@ohos.*', 'node:*'],
  minify: true, legalComments: 'linked', metafile: true,
  plugins: [{ name: 'pi-platform-neutral-exports', setup(build) {
    build.onResolve({ filter: /^@mariozechner\/pi-ai$/ }, () => ({ path: path.join(root, 'src/pi-core.js') }));
  }}]
}).then(result => {
  fs.writeFileSync(path.join(root, 'bundle-meta.json'), JSON.stringify(result.metafile, null, 2));
  // es2abc rejects an unquoted async method named `return`; preserve SDK behavior while quoting that property.
  const ts = require(process.env.ARKTS_TYPESCRIPT_PATH);
  const source = ts.createSourceFile('index.js', fs.readFileSync(path.join(root, 'index.js'), 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
  const transform = context => {
    const visit = node => {
      if (ts.isMethodDeclaration(node) && ts.isIdentifier(node.name) && node.name.text === 'return') {
        node = ts.factory.updateMethodDeclaration(node, node.decorators, node.modifiers, node.asteriskToken,
          ts.factory.createStringLiteral('return'), node.questionToken, node.typeParameters, node.parameters, node.type, node.body);
      }
      if (ts.isYieldExpression(node)) return ts.factory.createParenthesizedExpression(ts.visitEachChild(node, visit, context));
      return ts.visitEachChild(node, visit, context);
    };
    return node => ts.visitNode(node, visit);
  };
  const output = ts.transform(source, [transform]);
  fs.writeFileSync(path.join(root, 'index.js'), ts.createPrinter().printFile(output.transformed[0]));
  output.dispose();
  const os = require('node:os'), child = require('node:child_process');
  const stage = fs.mkdtempSync(path.join(os.tmpdir(), 'shixu-pi-har-'));
  try {
    fs.mkdirSync(path.join(stage, 'package'));
    for (const name of ['oh-package.json5', 'index.js', 'index.d.ts', 'index.js.LEGAL.txt', 'THIRD_PARTY_LICENSES.txt']) {
      if (fs.existsSync(path.join(root, name))) fs.copyFileSync(path.join(root, name), path.join(stage, 'package', name));
    }
    child.execFileSync('tar', ['--sort=name', '--mtime=@0', '--owner=0', '--group=0', '--numeric-owner',
      '-czf', path.join(root, 'pi-agent-harmony.har'), '-C', stage, 'package']);
  } finally { fs.rmSync(stage, {recursive: true, force: true}); }

});
