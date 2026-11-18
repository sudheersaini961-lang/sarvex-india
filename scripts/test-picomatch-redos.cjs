'use strict';
const { spawnSync } = require('node:child_process');
const patterns = ['+(*)', '+(*a)', '+(a*)', '*(a*|b)', '+(ab|abab)'];
const source = String.raw`
  const picomatch = require('./vendor/picomatch');
  const patterns = JSON.parse(process.argv[1]);
  for (const pattern of patterns) {
    const matcher = picomatch(pattern);
    matcher(pattern);
    matcher('a'.repeat(20000) + '!');
    const regex = picomatch.makeRe(pattern);
    if (regex && regex.source.length > 10000) throw new Error('unexpected regex expansion: ' + pattern);
  }
`;
const result = spawnSync(process.execPath, ['-e', source, JSON.stringify(patterns)], {
  cwd: process.cwd(), encoding: 'utf8', timeout: 2500, maxBuffer: 1024 * 1024
});
if (result.error) throw result.error;
if (result.status !== 0) {
  process.stderr.write(result.stderr || result.stdout || 'picomatch regression subprocess failed\n');
  process.exit(result.status || 1);
}
console.log('PASS: repeated-extglob ReDoS regression patterns completed within 2.5 seconds.');
