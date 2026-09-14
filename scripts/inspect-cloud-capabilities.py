#!/usr/bin/env python3
"""One read-only Govee capability request. No light commands or stored API key."""
import datetime
import getpass
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.error
import urllib.request

ENDPOINT = 'https://openapi.api.govee.com/router/api/v1/user/devices'

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def main():
    if not sys.stdin.isatty():
        raise SystemExit('In einem interaktiven Terminal starten; der Key wird verdeckt eingegeben.')
    key = getpass.getpass('Govee API-Key (wird nicht gespeichert): ').strip()
    if not key:
        raise SystemExit('Abgebrochen: kein API-Key.')
    request = urllib.request.Request(ENDPOINT, headers={'Govee-API-Key': key, 'Accept': 'application/json'}, method='GET')
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=20) as response:
            data = json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit(f'Govee antwortet mit HTTP {error.code}; kein Ergebnis gespeichert.')
    except (urllib.error.URLError, TimeoutError, ValueError):
        raise SystemExit('Netzwerk- oder Antwortfehler; kein Ergebnis gespeichert.')
    finally:
        key = None
        request = None
    if data.get('code') != 200 or not isinstance(data.get('data'), list):
        raise SystemExit('Govee meldet keinen erfolgreichen Geräteabruf; kein Ergebnis gespeichert.')
    devices = [
        {'sku': d.get('sku'), 'device': d.get('device'), 'capabilities': d.get('capabilities', [])}
        for d in data['data'] if d.get('sku') == 'H606A'
    ]
    report = {'retrievedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'source': ENDPOINT, 'scope': 'Cloud capability metadata only; not proof of local addressability',
              'devices': devices}
    folder = Path(__file__).resolve().parent.parent / '.local'
    folder.mkdir(exist_ok=True)
    target = folder / 'govee-capabilities.json'
    fd, temporary = tempfile.mkstemp(dir=folder, prefix='capabilities-')
    try:
        with os.fdopen(fd, 'w') as file:
            json.dump(report, file, indent=2)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f'{len(devices)} H606A gefunden. Ergebnis lokal gespeichert: {target}')
    print('Keine Lichtwerte geändert. Kein API-Key gespeichert. Kein weiterer Cloudzugriff geplant.')

if __name__ == '__main__':
    main()
