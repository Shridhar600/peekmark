#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PLIST="$ROOT_DIR/App/Info.plist"
EXT_PLIST="$ROOT_DIR/Extension/Info.plist"
PROJECT_YML="$ROOT_DIR/project.yml"
APP_ENTITLEMENTS="$ROOT_DIR/App/PeekMark.entitlements"
EXT_ENTITLEMENTS="$ROOT_DIR/Extension/PeekMarkQuickLookExtension.entitlements"

python3 - <<'PY' "$APP_PLIST" "$EXT_PLIST" "$PROJECT_YML" "$APP_ENTITLEMENTS" "$EXT_ENTITLEMENTS"
import plistlib
import sys
from pathlib import Path

app_plist_path, ext_plist_path, project_yml_path, app_entitlements_path, ext_entitlements_path = sys.argv[1:6]

with open(app_plist_path, "rb") as fh:
    app = plistlib.load(fh)
with open(ext_plist_path, "rb") as fh:
    ext = plistlib.load(fh)

project_yml = Path(project_yml_path).read_text()

expected_host_types = {
    "public.markdown",
    "net.daringfireball.markdown",
    "com.unknown.md",
    "net.ia.markdown",
}

expected_extension_types = {
    "public.markdown",
    "net.daringfireball.markdown",
    "com.unknown.md",
    "net.daringfireball",
    "net.multimarkdown.text",
    "net.ia.markdown",
    "com.foldingtext.FoldingText.document",
    "com.nutstore.down",
    "org.vim.markdown-file",
    "pro.writer.markdown",
    "io.typora.markdown",
    "com.rstudio.rmarkdown",
    "org.quarto.qmarkdown",
    "org.apiblueprint.file",
    "dyn.ah62d4rv4ge8043a",
}

doc_types = app.get("CFBundleDocumentTypes", [])
host_seen = set()
host_alternate_seen = set()
for item in doc_types:
    for uti in item.get("LSItemContentTypes", []):
        host_seen.add(uti)
        if item.get("LSHandlerRank") == "Alternate":
            host_alternate_seen.add(uti)

ext_seen = set(
    ext.get("NSExtension", {})
       .get("NSExtensionAttributes", {})
       .get("QLSupportedContentTypes", [])
)

missing_host = sorted(expected_host_types - host_seen)
missing_host_alternate = sorted(expected_host_types - host_alternate_seen)
missing_ext = sorted(expected_extension_types - ext_seen)

missing_project_settings = []
for needle in (
    "name: PeekMark",
    "PRODUCT_BUNDLE_IDENTIFIER: app.peekmark.mac",
    "PRODUCT_BUNDLE_IDENTIFIER: app.peekmark.mac.quicklook",
    "CODE_SIGN_ENTITLEMENTS: App/PeekMark.entitlements",
    "CODE_SIGN_ENTITLEMENTS: Extension/PeekMarkQuickLookExtension.entitlements",
):
    if needle not in project_yml:
        missing_project_settings.append(needle)

missing_entitlement_files = [
    path for path in (app_entitlements_path, ext_entitlements_path)
    if not Path(path).exists()
]

app_entitlements = {}
ext_entitlements = {}
if not missing_entitlement_files:
    with open(app_entitlements_path, "rb") as fh:
        app_entitlements = plistlib.load(fh)
    with open(ext_entitlements_path, "rb") as fh:
        ext_entitlements = plistlib.load(fh)

missing_app_entitlements = []
forbidden_app_entitlements = []
for key in (
    "com.apple.security.app-sandbox",
    "com.apple.security.files.user-selected.read-only",
    "com.apple.security.network.client",
):
    if app_entitlements.get(key) is not True:
        missing_app_entitlements.append(key)

missing_ext_entitlements = []
forbidden_ext_entitlements = []
for key in (
    "com.apple.security.app-sandbox",
    "com.apple.security.files.user-selected.read-only",
):
    if ext_entitlements.get(key) is not True:
        missing_ext_entitlements.append(key)

for key in (
    "com.apple.security.temporary-exception.files.absolute-path.read-only",
):
    if key in app_entitlements:
        forbidden_app_entitlements.append(key)

for key in (
    "com.apple.security.network.client",
    "com.apple.security.temporary-exception.files.absolute-path.read-only",
):
    if key in ext_entitlements:
        forbidden_ext_entitlements.append(key)

if (
    missing_host
    or missing_host_alternate
    or missing_ext
    or missing_project_settings
    or missing_entitlement_files
    or missing_app_entitlements
    or missing_ext_entitlements
    or forbidden_app_entitlements
    or forbidden_ext_entitlements
):
    if missing_host:
        print("Missing host CFBundleDocumentTypes UTIs:", ", ".join(missing_host))
    if missing_host_alternate:
        print("Host markdown UTIs not claimed with LSHandlerRank=Alternate:", ", ".join(missing_host_alternate))
    if missing_ext:
        print("Missing extension QLSupportedContentTypes UTIs:", ", ".join(missing_ext))
    if missing_project_settings:
        print("Missing project entitlement settings:", ", ".join(missing_project_settings))
    if missing_entitlement_files:
        print("Missing entitlement files:", ", ".join(missing_entitlement_files))
    if missing_app_entitlements:
        print("Missing app entitlement keys:", ", ".join(missing_app_entitlements))
    if missing_ext_entitlements:
        print("Missing extension entitlement keys:", ", ".join(missing_ext_entitlements))
    if forbidden_app_entitlements:
        print("Forbidden app entitlement keys:", ", ".join(forbidden_app_entitlements))
    if forbidden_ext_entitlements:
        print("Forbidden extension entitlement keys:", ", ".join(forbidden_ext_entitlements))
    sys.exit(1)

print("quicklook metadata check passed")
PY
