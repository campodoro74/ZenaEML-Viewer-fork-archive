#!/usr/bin/env python3
"""
Ensure App Store readiness for com.noma4i.EMLViewer via App Store Connect API:
  - Bundle ID exists
  - Apple Distribution certificate exists (reused if already in Keychain)
  - Mac Installer Distribution certificate exists (created from CSR if missing)
  - Mac App Store provisioning profile exists and is installed

Prints the provisioning profile name to stdout as the last line.

Env:
  ASC_KEY_PATH   - .p8 API key file
  ASC_KEY_ID     - key ID (10 chars)
  ASC_ISSUER_ID  - issuer UUID
  TEAM           - team ID (default 89QF7X66FR)
  BUNDLE_ID      - bundle identifier (default com.noma4i.EMLViewer)
  APP_NAME       - app name (default EMLViewer)
  PROFILE_NAME   - profile display name (default "EMLViewer Mac App Store")
  CSR_PATH       - CSR file to use when creating new certs
                   (default ~/work/_certs/CertificateSigningRequest.certSigningRequest)
"""

import base64
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"

KEY_PATH    = os.environ["ASC_KEY_PATH"]
KEY_ID      = os.environ["ASC_KEY_ID"]
ISSUER_ID   = os.environ["ASC_ISSUER_ID"]
TEAM        = os.environ.get("TEAM", "89QF7X66FR")
BUNDLE_ID   = os.environ.get("BUNDLE_ID", "com.noma4i.EMLViewer")
APP_NAME    = os.environ.get("APP_NAME", "EMLViewer")
PROFILE_NM  = os.environ.get("PROFILE_NAME", "EMLViewer Mac App Store")
CSR_PATH    = os.path.expanduser(os.environ.get(
    "CSR_PATH",
    "~/work/_certs/CertificateSigningRequest.certSigningRequest",
))

with open(os.path.expanduser(KEY_PATH), "r") as f:
    private_key = f.read()

def make_jwt():
    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": int(time.time()) + 600,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256",
                      headers={"kid": KEY_ID, "typ": "JWT"})

TOKEN = make_jwt()

def request(method, path, body=None, query=None):
    url = API + path
    if query:
        from urllib.parse import urlencode
        url += "?" + urlencode(query, doseq=True)
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    if body:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            if not raw:
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"HTTP {e.code} {method} {url}\n{body}", file=sys.stderr)
        raise

def log(*a): print(*a, file=sys.stderr)

# 1. Bundle ID
log("==> Looking up bundle ID", BUNDLE_ID)
found = request("GET", "/bundleIds", query={
    "filter[identifier]": BUNDLE_ID,
    "limit": 10,
})
bundles = [b for b in found.get("data", [])
           if b["attributes"]["identifier"] == BUNDLE_ID]
if bundles:
    bundle_uid = bundles[0]["id"]
    log("    found:", bundle_uid)
else:
    log("    not found, creating under team", TEAM)
    created = request("POST", "/bundleIds", body={
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": BUNDLE_ID,
                "name": APP_NAME,
                "platform": "MAC_OS",
            },
        },
    })
    bundle_uid = created["data"]["id"]
    log("    created:", bundle_uid)

def first_cert_of_type(cert_type):
    r = request("GET", "/certificates", query={
        "filter[certificateType]": cert_type,
        "limit": 200,
    })
    for c in r.get("data", []):
        return c
    return None

def create_cert(cert_type):
    log(f"    creating {cert_type} cert via ASC")
    with open(CSR_PATH, "r") as f:
        pem = f.read()
    body_b64 = "".join(
        line for line in pem.splitlines()
        if line and not line.startswith("-----")
    )
    r = request("POST", "/certificates", body={
        "data": {
            "type": "certificates",
            "attributes": {
                "certificateType": cert_type,
                "csrContent": body_b64,
            },
        },
    })
    return r["data"]

def cer_from_cert(cert):
    b64 = cert["attributes"]["certificateContent"]
    return base64.b64decode(b64)

def install_cer(der_bytes, label):
    tmp = pathlib.Path("/tmp") / f"{label}.cer"
    tmp.write_bytes(der_bytes)
    subprocess.run(
        ["security", "import", str(tmp),
         "-k", os.path.expanduser("~/Library/Keychains/login.keychain-db")],
        check=False,
    )
    log(f"    imported {tmp} into login keychain")

def have_identity(name_part):
    try:
        out = subprocess.check_output(
            ["security", "find-identity", "-v", "-p", "codesigning"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return False
    return name_part in out

# 2. Apple Distribution certificate
log("==> Looking up Apple Distribution certificate")
dist_cert = first_cert_of_type("DISTRIBUTION") or first_cert_of_type("MAC_APP_DISTRIBUTION")
if not dist_cert:
    dist_cert = create_cert("DISTRIBUTION")
    install_cer(cer_from_cert(dist_cert), "apple_distribution")
cert_id = dist_cert["id"]
log("    cert id:", cert_id, "type:", dist_cert["attributes"].get("certificateType"))

# 2b. Mac Installer Distribution certificate (needed for .pkg signing)
log("==> Ensuring Mac Installer Distribution cert in Keychain and ASC")
installer_keychain_label = "3rd Party Mac Developer Installer"
inst_cert = first_cert_of_type("MAC_INSTALLER_DISTRIBUTION")
if inst_cert:
    log("    ASC has installer cert:", inst_cert["id"])
else:
    inst_cert = create_cert("MAC_INSTALLER_DISTRIBUTION")
    log("    ASC created installer cert:", inst_cert["id"])
if have_identity(installer_keychain_label):
    log("    already in Keychain")
else:
    install_cer(cer_from_cert(inst_cert), "mac_installer_distribution")
installer_cert_id = inst_cert["id"]

# 3. Existing profile?
log("==> Looking up existing profile", PROFILE_NM)
profiles = request("GET", "/profiles", query={
    "filter[name]": PROFILE_NM,
    "limit": 50,
    "include": "certificates",
})
existing = None
for p in profiles.get("data", []):
    if p["attributes"]["name"] == PROFILE_NM and \
       p["attributes"]["profileType"] == "MAC_APP_STORE":
        existing = p
        break

required_cert_ids = {cert_id, installer_cert_id}
existing_cert_ids = set()
if existing:
    existing_cert_ids = {
        c["id"] for c in existing.get("relationships", {})
                            .get("certificates", {})
                            .get("data", [])
    }

needs_recreate = (
    not existing
    or existing["attributes"].get("profileState") != "ACTIVE"
    or not required_cert_ids.issubset(existing_cert_ids)
)

if not needs_recreate:
    profile_uid = existing["id"]
    log("    profile exists and covers both certs:", profile_uid)
else:
    if existing:
        log("    profile stale or missing installer cert, deleting:", existing["id"])
        request("DELETE", f"/profiles/{existing['id']}")
    log("    creating new profile with both certs")
    created = request("POST", "/profiles", body={
        "data": {
            "type": "profiles",
            "attributes": {
                "name": PROFILE_NM,
                "profileType": "MAC_APP_STORE",
            },
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_uid}},
                "certificates": {"data": [
                    {"type": "certificates", "id": cert_id},
                    {"type": "certificates", "id": installer_cert_id},
                ]},
            },
        },
    })
    profile_uid = created["data"]["id"]
    log("    created profile:", profile_uid)

# 4. Fetch profile content
log("==> Downloading profile content")
full = request("GET", f"/profiles/{profile_uid}")
content_b64 = full["data"]["attributes"]["profileContent"]
profile_bytes = base64.b64decode(content_b64)

# 5. Install
target_dir = pathlib.Path.home() / "Library" / "MobileDevice" / "Provisioning Profiles"
target_dir.mkdir(parents=True, exist_ok=True)
filename = f"{profile_uid}.provisionprofile"
target = target_dir / filename
target.write_bytes(profile_bytes)
log("    installed:", target)

# stdout: profile name for shell to pick up
print(PROFILE_NM)
