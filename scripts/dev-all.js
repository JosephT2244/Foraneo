import { spawn } from 'node:child_process';

const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const processes = [
  spawn(npmCommand, ['run', 'server'], { stdio: 'inherit' }),
  spawn(npmCommand, ['run', 'dev'], { stdio: 'inherit' })
];

function stop() {
  processes.forEach(function (child) {
    if (!child.killed) child.kill();
  });
}

process.on('SIGINT', stop);
process.on('SIGTERM', stop);
processes.forEach(function (child) {
  child.on('exit', function (code) {
    if (code && code !== 0) process.exitCode = code;
  });
});
