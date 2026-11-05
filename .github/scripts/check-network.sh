#!/usr/bin/env bash
# PHO-23: the app may reach api.anthropic.com only.
# Checks the merged release manifest uses the network security config and allows no cleartext,
# and that the config trusts no certificates except for exactly one domain, api.anthropic.com.
# Usage: check-network.sh <merged AndroidManifest.xml> <network_security_config.xml>
set -euo pipefail
manifest="${1:?manifest}"; nsc="${2:?network security config}"
fail() { echo "FAIL: $*"; exit 1; }
grep -q 'android:networkSecurityConfig="@xml/network_security_config"' "$manifest" || fail "manifest doesn't use the network security config"
grep -q 'android:usesCleartextTraffic="true"' "$manifest" && fail "manifest allows cleartext traffic"
python3 - "$nsc" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
def fail(m): print("FAIL: " + m); sys.exit(1)
base = root.findall("base-config")
if len(base) != 1: fail("need exactly one base-config")
b = base[0]
if b.get("cleartextTrafficPermitted") != "false": fail("base-config must forbid cleartext")
ta = b.findall("trust-anchors")
if len(ta) != 1 or list(ta[0]): fail("base-config must have one empty trust-anchors (trust nothing)")
if root.findall("debug-overrides"): fail("no debug-overrides allowed")
doms = root.findall("domain-config")
names = [(d.text or "").strip() for dc in doms for d in dc.findall("domain")]
if names != ["api.anthropic.com"]: fail("the only domain must be api.anthropic.com, found %s" % names)
for dc in doms:
    if dc.get("cleartextTrafficPermitted") != "false": fail("domain-config must forbid cleartext")
    if dc.findall("domain-config"): fail("no nested domain-config")
    for d in dc.findall("domain"):
        if d.get("includeSubdomains") not in (None, "false"): fail("subdomains must not be included")
print("PASS: HTTPS only, and only api.anthropic.com is trusted")
PY
