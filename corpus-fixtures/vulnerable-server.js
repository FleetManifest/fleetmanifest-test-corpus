// Corpus fixture. Deliberately vulnerable — do not copy.
import http from 'node:http';
import { execSync } from 'node:child_process';

http
  .createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const name = url.searchParams.get('name') ?? '';

    // js/code-injection — user input reaching eval.
    eval('const greeting = "hello ' + name + '"');

    // js/shell-command-injection — user input reaching a shell.
    execSync('echo ' + name);

    res.end('ok');
  })
  .listen(3000);
