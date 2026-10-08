// Patch cryptpad-server 1.0.1 so failed commands keep their real error code.
//
// 1) core.js maps every second-stage command error to a generic "Execution
//    error", so the client never sees the actual code (e.g. E_RESTRICTED from
//    a restricted-registration instance). Pass the real error through instead,
//    exactly like the first-stage handler already does.
// 2) front.js / front.worker.js answer /api/auth failures with { error: err };
//    also expose errorCode, which is what the client and the checkup read.
//
// The script throws if the expected upstream code is not found, so a future
// cryptpad-server bump fails the build loudly instead of silently losing the
// fix.
const fs = require('fs');
const path = require('path');

const base = path.join(process.cwd(), 'node_modules', 'cryptpad-server', 'build');

function edit(file, fn) {
    const p = path.join(base, file);
    const src = fs.readFileSync(p, 'utf8');
    const out = fn(src);
    if (out === src) { throw new Error('patch-cpsrv: no change made to ' + file); }
    fs.writeFileSync(p, out);
    console.log('patch-cpsrv: patched ' + file);
}

edit('core.js', (s) => {
    const old = 'cb("Execution error")';
    if (s.split(old).length - 1 !== 1) {
        throw new Error('patch-cpsrv: expected exactly one "Execution error" in core.js');
    }
    return s.replace(old, 'cb(err?.message || err || "error")');
});

['front.js', 'front.worker.js'].forEach((file) => {
    edit(file, (s) => {
        const re = /(return res\.status\(500\)\.json\(\{\n)(\s*)error: err(\n\s*\}\);)/;
        if (!re.test(s)) {
            throw new Error('patch-cpsrv: /api/auth error block not found in ' + file);
        }
        return s.replace(re, (all, a, ind, c) =>
            a + ind + 'error: err,\n' + ind + 'errorCode: err' + c);
    });
});
