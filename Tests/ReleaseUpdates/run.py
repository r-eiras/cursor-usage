"""Run the real Swift release client against a local Postman HTTP simulation."""
from pathlib import Path
import json
import platform
import select
import signal
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='cursor-release-tests-') as temporary:
    work = Path(temporary)
    errors = (work / 'simulation.err').open('w+')
    server = subprocess.Popen(['postman', 'simulation', 'run', 'postman/simulations/releases.sim.yaml', '--port', 'auto', '--output', 'ndjson', '--no-history'], cwd=root, stdout=subprocess.PIPE, stderr=errors, text=True)
    events = []
    try:
        deadline = time.monotonic() + 20
        address = None
        while time.monotonic() < deadline:
            if server.poll() is not None:
                errors.seek(0)
                raise RuntimeError(errors.read())
            if select.select([server.stdout], [], [], 0.2)[0]:
                line = server.stdout.readline()
                events.append(line)
                event = json.loads(line)
                if event.get('event') == 'listening':
                    address = event['url'] + '/github/repos/r-eiras/cursor-usage/releases/latest'
                    break
        if not address:
            raise RuntimeError('Local release simulation did not become ready')
        flags = ['-target', f'{platform.machine()}-apple-macos14.0', '-module-cache-path', str(work/'modules')]
        include = Path('/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap')
        if include.exists() and 'module SwiftBridging' in include.read_text():
            (work/'empty.modulemap').write_text('')
            overlay = work/'overlay.json'
            overlay.write_text(json.dumps({'version':0,'case-sensitive':False,'roots':[{'type':'file','name':str(include),'external-contents':str(work/'empty.modulemap')}]}))
            flags += ['-vfsoverlay', str(overlay)]
        executable = work/'ReleaseUpdates'
        subprocess.run(['swiftc', *flags, str(root/'Sources/ReleaseUpdates.swift'), str(root/'Tests/ReleaseUpdates/main.swift'), '-o', str(executable)], check=True)
        subprocess.run([str(executable), address], check=True)
        time.sleep(1)
    finally:
        server.send_signal(signal.SIGINT)
        try:
            remainder, _ = server.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            server.terminate()
            remainder, _ = server.communicate(timeout=5)
        events.extend(remainder.splitlines(keepends=True))
        errors.close()
    requests = [json.loads(line) for line in events if line.strip() and json.loads(line).get('event') == 'request']
    if len(requests) < 9:
        raise RuntimeError('The simulation log does not prove the client reached the HTTP dependency')
    print(f'PASS: {len(requests)} real HTTP requests observed by the release simulation')
