#!/usr/bin/env python3
"""Package and safely publish native Moebios apps for SideStore and Android."""

from __future__ import annotations

import argparse
import copy
import fcntl
import hashlib
import io
import json
import os
import plistlib
import re
import sys
import tarfile
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import BinaryIO, Any


BUNDLE_IDENTIFIER = "com.moebiosenergy.mobile"
APP_NAME = "Moebios Energy"
DEVELOPER_NAME = "Moebios Energy"
SOURCE_IDENTIFIER = "com.moebiosenergy.mobile"
SOURCE_NAME = "Arthur’s Apps"
SOURCE_DESCRIPTION = "Aplicativos de Arthur disponíveis para instalação pelo SideStore."
SOURCE_URL = "https://app.moebiosenergy.com.br/sidestore/source.json"
ICON_URL = "https://app.moebiosenergy.com.br/sidestore/icon.png"
SIDESTORE_BASE_URL = "https://app.moebiosenergy.com.br/sidestore"
DEFAULT_APP_SUBTITLE = "Acompanhe plantas, equipamentos e energia."
DEFAULT_APP_DESCRIPTION = (
    "Monitore a energia da sua planta, consulte relatórios e acompanhe "
    "inversores, baterias e o diagrama do sistema."
)
ALLOWED_ARCHIVE_FILES = {"release.ipa", "release.json", "icon.png"}
ALLOWED_ANDROID_ARCHIVE_FILES = {"android-release.apk", "android-release.json"}
MAX_IPA_BYTES = 300 * 1024 * 1024
MAX_ANDROID_APK_BYTES = 300 * 1024 * 1024
MAX_JSON_BYTES = 1024 * 1024
MAX_ICON_BYTES = 8 * 1024 * 1024
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
BUILD_PATTERN = re.compile(r"^\d+$")
BUNDLE_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$")
ANDROID_APPLICATION_ID_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$")
RECEIVE_ROOT = Path("/var/lib/moebios-sidestore")
ANDROID_DOWNLOAD_BASE_URL = f"{SIDESTORE_BASE_URL}/apps/android"


class SideStoreError(Exception):
    """Raised when an IPA or source publication fails validation."""


def _validate_bundle_identifier(bundle_identifier: Any) -> str:
    if (
        not isinstance(bundle_identifier, str)
        or len(bundle_identifier) > 255
        or not BUNDLE_IDENTIFIER_PATTERN.fullmatch(bundle_identifier)
    ):
        raise SideStoreError("IPA bundle identifier is missing or invalid.")
    return bundle_identifier


def _read_plist(archive: zipfile.ZipFile, path: str) -> dict[str, Any]:
    try:
        value = plistlib.loads(archive.read(path))
    except (KeyError, plistlib.InvalidFileException, ValueError) as error:
        raise SideStoreError(f"Invalid property list in IPA: {path}") from error
    if not isinstance(value, dict):
        raise SideStoreError(f"Property list is not a dictionary: {path}")
    return value


def inspect_ipa(ipa: str | Path | bytes | BinaryIO) -> dict[str, Any]:
    """Extract identity and declared permissions from the IPA's actual plist files."""
    source: Any = io.BytesIO(ipa) if isinstance(ipa, bytes) else ipa
    try:
        archive = zipfile.ZipFile(source)
    except (OSError, zipfile.BadZipFile) as error:
        raise SideStoreError("The uploaded file is not a valid IPA ZIP archive.") from error

    with archive:
        names = archive.namelist()
        main_plists = [
            name
            for name in names
            if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)
        ]
        if len(main_plists) != 1:
            raise SideStoreError("IPA must contain exactly one top-level Payload/*.app/Info.plist.")

        main_info = _read_plist(archive, main_plists[0])
        bundle_identifier = main_info.get("CFBundleIdentifier")
        version = main_info.get("CFBundleShortVersionString")
        build_version = main_info.get("CFBundleVersion")
        _validate_bundle_identifier(bundle_identifier)
        if not isinstance(version, str) or not VERSION_PATTERN.fullmatch(version):
            raise SideStoreError("CFBundleShortVersionString must be a numeric X.Y.Z version.")
        if not isinstance(build_version, (str, int)) or not BUILD_PATTERN.fullmatch(str(build_version)):
            raise SideStoreError("CFBundleVersion must be a numeric build number.")

        privacy: dict[str, str] = {}
        info_paths = [
            name
            for name in names
            if name.startswith("Payload/")
            and name.endswith("/Info.plist")
            and (".app/" in name or ".appex/" in name)
        ]
        for info_path in info_paths:
            info = main_info if info_path == main_plists[0] else _read_plist(archive, info_path)
            for key, value in info.items():
                if key.endswith("UsageDescription") and isinstance(value, str):
                    existing_value = privacy.get(key)
                    if existing_value is not None and existing_value != value:
                        raise SideStoreError(f"Conflicting privacy descriptions found for {key}.")
                    privacy[key] = value

        entitlements: set[str] = set()
        entitlement_paths = [
            name
            for name in names
            if name.endswith(".entitlements") or name.endswith("/_CodeSignature/Entitlements.plist")
        ]
        omitted_entitlements = {"com.apple.developer.team-identifier", "application-identifier"}
        for entitlement_path in entitlement_paths:
            entitlement_data = _read_plist(archive, entitlement_path)
            entitlements.update(key for key in entitlement_data if key not in omitted_entitlements)

        minimum_os = main_info.get("MinimumOSVersion")
        if minimum_os is not None and not isinstance(minimum_os, str):
            minimum_os = str(minimum_os)

        return {
            "bundleIdentifier": bundle_identifier,
            "version": version,
            "buildVersion": str(build_version),
            "minOSVersion": minimum_os,
            "displayName": main_info.get("CFBundleDisplayName", main_info.get("CFBundleName", "")),
            "appPermissions": {
                "entitlements": sorted(entitlements),
                "privacy": dict(sorted(privacy.items())),
            },
        }


def _validate_icon(icon_bytes: bytes) -> None:
    if len(icon_bytes) < 24 or not icon_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SideStoreError("The app icon must be a valid PNG image.")
    width = int.from_bytes(icon_bytes[16:20], "big")
    height = int.from_bytes(icon_bytes[20:24], "big")
    if width < 1 or height < 1:
        raise SideStoreError("The app icon has invalid dimensions.")


def _release_date() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def package_release(
    ipa_path: str | Path,
    icon_path: str | Path,
    output_path: str | Path,
    expected_version: str,
    release_notes: str,
    app_name: str | None = None,
    developer_name: str | None = None,
    app_subtitle: str | None = None,
    app_description: str | None = None,
    app_category: str | None = None,
) -> dict[str, Any]:
    """Validate a finished IPA and package it for the restricted VPS receiver."""
    ipa_file = Path(ipa_path)
    icon_file = Path(icon_path)
    output_file = Path(output_path)
    if not ipa_file.is_file() or ipa_file.stat().st_size > MAX_IPA_BYTES:
        raise SideStoreError("IPA is missing or exceeds the configured size limit.")
    if expected_version and not VERSION_PATTERN.fullmatch(expected_version):
        raise SideStoreError("Release version must use the numeric X.Y.Z format.")
    notes = release_notes.strip()
    if not notes:
        raise SideStoreError("Release notes cannot be empty.")

    ipa_bytes = ipa_file.read_bytes()
    ipa_metadata = inspect_ipa(ipa_bytes)
    if expected_version and ipa_metadata["version"] != expected_version:
        raise SideStoreError(
            "IPA version does not match the requested release version: "
            f"{ipa_metadata['version']} != {expected_version}."
        )
    icon_bytes = icon_file.read_bytes()
    _validate_icon(icon_bytes)
    is_primary_app = ipa_metadata["bundleIdentifier"] == BUNDLE_IDENTIFIER
    app_metadata = {
        "name": (app_name or ipa_metadata["displayName"] or (APP_NAME if is_primary_app else "")).strip(),
        "developerName": (developer_name or (DEVELOPER_NAME if is_primary_app else "")).strip(),
        "localizedDescription": (
            app_description or (DEFAULT_APP_DESCRIPTION if is_primary_app else "")
        ).strip(),
        "iconURL": (
            f"{SIDESTORE_BASE_URL}/icons/{ipa_metadata['bundleIdentifier']}/"
            f"{ipa_metadata['version']}/{ipa_metadata['buildVersion']}.png"
        ),
    }
    subtitle = app_subtitle or (DEFAULT_APP_SUBTITLE if is_primary_app else None)
    category = app_category or ("utilities" if is_primary_app else None)
    if subtitle:
        app_metadata["subtitle"] = subtitle.strip()
    if category:
        app_metadata["category"] = category.strip()
    for required_field in ("name", "developerName", "localizedDescription"):
        if not app_metadata[required_field]:
            raise SideStoreError(
                f"The IPA {ipa_metadata['bundleIdentifier']} needs explicit app metadata: {required_field}."
            )

    version_entry: dict[str, Any] = {
        "version": ipa_metadata["version"],
        "buildVersion": ipa_metadata["buildVersion"],
        "date": _release_date(),
        "localizedDescription": notes,
        "downloadURL": (
            f"{SIDESTORE_BASE_URL}/apps/{ipa_metadata['bundleIdentifier']}/"
            f"{ipa_metadata['version']}/{ipa_metadata['buildVersion']}.ipa"
        ),
        "size": len(ipa_bytes),
        "sha256": hashlib.sha256(ipa_bytes).hexdigest(),
    }
    if ipa_metadata["minOSVersion"] is not None:
        version_entry["minOSVersion"] = ipa_metadata["minOSVersion"]

    release_metadata = {
        "bundleIdentifier": ipa_metadata["bundleIdentifier"],
        "appMetadata": app_metadata,
        "versionEntry": version_entry,
        "iconSha256": hashlib.sha256(icon_bytes).hexdigest(),
        "appPermissions": ipa_metadata["appPermissions"],
    }

    output_file.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output_file, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for name, data in (
            ("release.ipa", ipa_bytes),
            ("release.json", json.dumps(release_metadata, ensure_ascii=False).encode("utf-8")),
            ("icon.png", icon_bytes),
        ):
            member = tarfile.TarInfo(name)
            member.size = len(data)
            member.mode = 0o644
            member.mtime = int(datetime.now(timezone.utc).timestamp())
            tar.addfile(member, io.BytesIO(data))
    return release_metadata


def package_android_release(
    apk_path: str | Path,
    output_path: str | Path,
    application_id: str,
    version: str,
    build_version: str,
) -> dict[str, Any]:
    """Validate and package a built APK for the restricted VPS receiver."""
    apk_file = Path(apk_path)
    output_file = Path(output_path)
    if not isinstance(application_id, str) or not ANDROID_APPLICATION_ID_PATTERN.fullmatch(application_id):
        raise SideStoreError("Android application ID is missing or invalid.")
    if not VERSION_PATTERN.fullmatch(version) or not BUILD_PATTERN.fullmatch(build_version):
        raise SideStoreError("Android version and build number must be numeric.")
    if not apk_file.is_file() or apk_file.stat().st_size < 1 or apk_file.stat().st_size > MAX_ANDROID_APK_BYTES:
        raise SideStoreError("APK is missing or exceeds the configured size limit.")

    apk_bytes = apk_file.read_bytes()
    try:
        with zipfile.ZipFile(io.BytesIO(apk_bytes)) as archive:
            if "AndroidManifest.xml" not in archive.namelist():
                raise SideStoreError("The APK does not contain an Android manifest.")
    except (OSError, zipfile.BadZipFile) as error:
        raise SideStoreError("The uploaded file is not a valid APK archive.") from error

    download_url = (
        f"{ANDROID_DOWNLOAD_BASE_URL}/{application_id}/{version}/{build_version}.apk"
    )
    release_metadata: dict[str, Any] = {
        "applicationId": application_id,
        "version": version,
        "buildVersion": build_version,
        "date": _release_date(),
        "size": len(apk_bytes),
        "sha256": hashlib.sha256(apk_bytes).hexdigest(),
        "downloadURL": download_url,
        "latestURL": f"{ANDROID_DOWNLOAD_BASE_URL}/{application_id}/latest.apk",
    }

    output_file.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output_file, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for name, data in (
            ("android-release.apk", apk_bytes),
            ("android-release.json", json.dumps(release_metadata, ensure_ascii=False).encode("utf-8")),
        ):
            member = tarfile.TarInfo(name)
            member.size = len(data)
            member.mode = 0o644
            member.mtime = int(datetime.now(timezone.utc).timestamp())
            tar.addfile(member, io.BytesIO(data))
    return release_metadata


def _version_key(version: str, build_version: str) -> tuple[tuple[int, int, int], int]:
    if not VERSION_PATTERN.fullmatch(version) or not BUILD_PATTERN.fullmatch(build_version):
        raise SideStoreError("Source contains a version or build number in an unsupported format.")
    return tuple(int(part) for part in version.split(".")), int(build_version)


def _read_archive(stream: BinaryIO) -> dict[str, bytes]:
    payload: dict[str, bytes] = {}
    supported_archive_files = ALLOWED_ARCHIVE_FILES | ALLOWED_ANDROID_ARCHIVE_FILES
    limits = {
        "release.ipa": MAX_IPA_BYTES,
        "release.json": MAX_JSON_BYTES,
        "icon.png": MAX_ICON_BYTES,
        "android-release.apk": MAX_ANDROID_APK_BYTES,
        "android-release.json": MAX_JSON_BYTES,
    }
    try:
        with tarfile.open(fileobj=stream, mode="r|*") as archive:
            for member in archive:
                if member.name not in supported_archive_files:
                    raise SideStoreError("The deployment archive contains an unexpected path.")
                if member.name in payload or not member.isfile() or member.size > limits[member.name]:
                    raise SideStoreError("The deployment archive contains a duplicate or invalid file.")
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise SideStoreError("The deployment archive contains an unreadable file.")
                data = extracted.read(limits[member.name] + 1)
                if len(data) != member.size or len(data) > limits[member.name]:
                    raise SideStoreError("The deployment archive contains a truncated or oversized file.")
                payload[member.name] = data
    except (tarfile.TarError, OSError) as error:
        raise SideStoreError("Could not read the deployment archive.") from error
    if set(payload) not in (ALLOWED_ARCHIVE_FILES, ALLOWED_ANDROID_ARCHIVE_FILES):
        raise SideStoreError("Deployment archive does not match a supported native app package.")
    return payload


def _atomic_write(path: Path, data: bytes, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
    os.chmod(path.parent, 0o755)
    if path.is_symlink():
        raise SideStoreError("Refusing to replace a symbolic link in the publication directory.")
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as temporary_file:
            temporary_file.write(data)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
            os.fchmod(temporary_file.fileno(), mode)
        os.replace(temporary_path, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def _base_source() -> dict[str, Any]:
    return {
        "name": SOURCE_NAME,
        "identifier": SOURCE_IDENTIFIER,
        "subtitle": "Monitoramento de energia em tempo real",
        "description": SOURCE_DESCRIPTION,
        "iconURL": ICON_URL,
        "website": "https://app.moebiosenergy.com.br",
        "tintColor": "#3F6B35",
        "apps": [],
    }


def _load_source(path: Path) -> dict[str, Any]:
    if not path.exists():
        return _base_source()
    if path.is_symlink() or not path.is_file():
        raise SideStoreError("Existing source.json is not a regular file.")
    try:
        source = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SideStoreError("Existing source.json is invalid; refusing to overwrite it.") from error
    if not isinstance(source, dict) or source.get("identifier") != SOURCE_IDENTIFIER:
        raise SideStoreError("Existing source.json does not match this app source.")
    apps = source.get("apps")
    if not isinstance(apps, list):
        raise SideStoreError("Existing source.json has an invalid app list.")
    bundle_identifiers: set[str] = set()
    for app in apps:
        if not isinstance(app, dict):
            raise SideStoreError("Existing source.json contains an invalid app entry.")
        bundle_identifier = _validate_bundle_identifier(app.get("bundleIdentifier"))
        if bundle_identifier in bundle_identifiers:
            raise SideStoreError("Existing source.json contains duplicate bundle identifiers.")
        bundle_identifiers.add(bundle_identifier)
        if not isinstance(app.get("versions"), list):
            raise SideStoreError("Existing source.json has an invalid versions list.")
        for version in app["versions"]:
            if not isinstance(version, dict):
                raise SideStoreError("Existing source.json contains an invalid version entry.")
            _version_key(str(version.get("version", "")), str(version.get("buildVersion", "")))
    source["name"] = SOURCE_NAME
    source["description"] = SOURCE_DESCRIPTION
    return source


def _validate_release_metadata(
    release_metadata: Any,
    ipa_bytes: bytes,
    icon_bytes: bytes,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    if not isinstance(release_metadata, dict):
        raise SideStoreError("Release metadata must be a JSON object.")
    actual = inspect_ipa(ipa_bytes)
    if release_metadata.get("bundleIdentifier") != actual["bundleIdentifier"]:
        raise SideStoreError("Release metadata bundle identifier does not match the IPA.")
    app_metadata = release_metadata.get("appMetadata")
    if not isinstance(app_metadata, dict):
        raise SideStoreError("Release metadata has no app details.")
    permitted_app_fields = {
        "name",
        "developerName",
        "localizedDescription",
        "iconURL",
        "subtitle",
        "category",
    }
    if not set(app_metadata).issubset(permitted_app_fields):
        raise SideStoreError("Release metadata contains unsupported app details.")
    for field in ("name", "developerName", "localizedDescription"):
        field_value = app_metadata.get(field)
        if not isinstance(field_value, str) or not field_value.strip():
            raise SideStoreError(f"App metadata is missing {field}.")
        maximum_length = 200 if field in ("name", "developerName") else 4000
        if len(field_value) > maximum_length:
            raise SideStoreError(f"App metadata {field} is too long.")
    version_entry = release_metadata.get("versionEntry")
    if not isinstance(version_entry, dict):
        raise SideStoreError("Release metadata has no version entry.")
    if version_entry.get("version") != actual["version"]:
        raise SideStoreError("Version in release metadata does not match the IPA Info.plist.")
    if version_entry.get("buildVersion") != actual["buildVersion"]:
        raise SideStoreError("Build number in release metadata does not match the IPA Info.plist.")
    if version_entry.get("size") != len(ipa_bytes):
        raise SideStoreError("Release metadata size does not match the IPA.")
    digest = hashlib.sha256(ipa_bytes).hexdigest()
    if version_entry.get("sha256") != digest:
        raise SideStoreError("Release metadata checksum does not match the IPA.")
    expected_url = (
        f"{SIDESTORE_BASE_URL}/apps/{actual['bundleIdentifier']}/"
        f"{actual['version']}/{actual['buildVersion']}.ipa"
    )
    if version_entry.get("downloadURL") != expected_url:
        raise SideStoreError("Release metadata download URL is not the stable versioned IPA URL.")
    if not isinstance(version_entry.get("localizedDescription"), str) or not version_entry["localizedDescription"].strip():
        raise SideStoreError("Release notes are missing.")
    release_date = version_entry.get("date")
    if not isinstance(release_date, str):
        raise SideStoreError("Release date is missing.")
    try:
        parsed_date = datetime.fromisoformat(release_date.replace("Z", "+00:00"))
    except ValueError as error:
        raise SideStoreError("Release date is not ISO 8601.") from error
    if parsed_date.tzinfo is None:
        raise SideStoreError("Release date must include a timezone.")
    if actual["minOSVersion"] is not None and version_entry.get("minOSVersion") != actual["minOSVersion"]:
        raise SideStoreError("Minimum OS version does not match the IPA Info.plist.")
    expected_icon_url = (
        f"{SIDESTORE_BASE_URL}/icons/{actual['bundleIdentifier']}/"
        f"{actual['version']}/{actual['buildVersion']}.png"
    )
    if app_metadata.get("iconURL") != expected_icon_url:
        raise SideStoreError("App icon URL is not the stable versioned icon URL.")
    icon_digest = hashlib.sha256(icon_bytes).hexdigest()
    if release_metadata.get("iconSha256") != icon_digest:
        raise SideStoreError("Release metadata checksum does not match the app icon.")
    for optional_field in ("subtitle", "category"):
        optional_value = app_metadata.get(optional_field)
        if optional_value is not None and (
            not isinstance(optional_value, str) or not optional_value.strip() or len(optional_value) > 200
        ):
            raise SideStoreError(f"App metadata {optional_field} is invalid.")
    if release_metadata.get("appPermissions") != actual["appPermissions"]:
        raise SideStoreError("App permissions do not match the permissions in the IPA.")
    _validate_icon(icon_bytes)
    return actual, version_entry, app_metadata


def _validate_android_release_metadata(release_metadata: Any, apk_bytes: bytes) -> dict[str, Any]:
    if not isinstance(release_metadata, dict):
        raise SideStoreError("Android release metadata must be a JSON object.")
    expected_fields = {
        "applicationId",
        "version",
        "buildVersion",
        "date",
        "size",
        "sha256",
        "downloadURL",
        "latestURL",
    }
    if set(release_metadata) != expected_fields:
        raise SideStoreError("Android release metadata is incomplete or contains unsupported fields.")

    application_id = release_metadata["applicationId"]
    version = release_metadata["version"]
    build_version = release_metadata["buildVersion"]
    if not isinstance(application_id, str) or not ANDROID_APPLICATION_ID_PATTERN.fullmatch(application_id):
        raise SideStoreError("Android release metadata contains an invalid application ID.")
    if not isinstance(version, str) or not isinstance(build_version, str):
        raise SideStoreError("Android release metadata has an invalid version or build number.")
    _version_key(version, build_version)
    if release_metadata["size"] != len(apk_bytes) or not apk_bytes:
        raise SideStoreError("Android release metadata size does not match the APK.")
    digest = hashlib.sha256(apk_bytes).hexdigest()
    if release_metadata["sha256"] != digest:
        raise SideStoreError("Android release metadata checksum does not match the APK.")

    expected_download_url = (
        f"{ANDROID_DOWNLOAD_BASE_URL}/{application_id}/{version}/{build_version}.apk"
    )
    expected_latest_url = f"{ANDROID_DOWNLOAD_BASE_URL}/{application_id}/latest.apk"
    if release_metadata["downloadURL"] != expected_download_url:
        raise SideStoreError("Android release metadata contains an invalid versioned download URL.")
    if release_metadata["latestURL"] != expected_latest_url:
        raise SideStoreError("Android release metadata contains an invalid latest download URL.")

    release_date = release_metadata["date"]
    if not isinstance(release_date, str):
        raise SideStoreError("Android release date is missing.")
    try:
        parsed_date = datetime.fromisoformat(release_date.replace("Z", "+00:00"))
    except ValueError as error:
        raise SideStoreError("Android release date is not ISO 8601.") from error
    if parsed_date.tzinfo is None:
        raise SideStoreError("Android release date must include a timezone.")

    try:
        with zipfile.ZipFile(io.BytesIO(apk_bytes)) as archive:
            if "AndroidManifest.xml" not in archive.namelist():
                raise SideStoreError("The APK does not contain an Android manifest.")
    except (OSError, zipfile.BadZipFile) as error:
        raise SideStoreError("The uploaded file is not a valid APK archive.") from error
    return release_metadata


def _receive_android_release(payload: dict[str, bytes], root_path: Path) -> str:
    try:
        release_metadata = json.loads(payload["android-release.json"].decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SideStoreError("Android release metadata is not valid UTF-8 JSON.") from error
    release_metadata = _validate_android_release_metadata(
        release_metadata,
        payload["android-release.apk"],
    )

    application_id = release_metadata["applicationId"]
    version = release_metadata["version"]
    build_version = release_metadata["buildVersion"]
    new_key = _version_key(version, build_version)
    app_root = root_path / "apps" / "android" / application_id
    versioned_apk_path = app_root / version / f"{build_version}.apk"
    latest_apk_path = app_root / "latest.apk"
    latest_metadata_path = app_root / "latest.json"

    lock_path = root_path / ".publish.lock"
    lock_descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(lock_descriptor, fcntl.LOCK_EX)
        current_release: dict[str, Any] | None = None
        if latest_metadata_path.exists() or latest_metadata_path.is_symlink():
            if latest_metadata_path.is_symlink() or not latest_metadata_path.is_file():
                raise SideStoreError("The existing Android release metadata is not a regular file.")
            try:
                current_release = json.loads(latest_metadata_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as error:
                raise SideStoreError("Existing Android release metadata is invalid.") from error
            if (
                not isinstance(current_release, dict)
                or current_release.get("applicationId") != application_id
                or not isinstance(current_release.get("version"), str)
                or not isinstance(current_release.get("buildVersion"), str)
            ):
                raise SideStoreError("Existing Android release metadata does not match this application.")
            current_key = _version_key(current_release["version"], current_release["buildVersion"])
            if new_key < current_key:
                raise SideStoreError("A newer Android release is already published; refusing an out-of-order deployment.")
            if new_key == current_key and current_release.get("sha256") != release_metadata["sha256"]:
                raise SideStoreError("This Android version/build is already published with different APK bytes.")
            if new_key > current_key and int(build_version) <= int(current_release["buildVersion"]):
                raise SideStoreError("Android build number must increase across published releases.")

        if versioned_apk_path.exists() or versioned_apk_path.is_symlink():
            if versioned_apk_path.is_symlink() or not versioned_apk_path.is_file():
                raise SideStoreError("The versioned Android APK path is not a regular file.")
            if hashlib.sha256(versioned_apk_path.read_bytes()).hexdigest() != release_metadata["sha256"]:
                raise SideStoreError("The versioned Android APK path already contains different bytes.")
        else:
            _atomic_write(versioned_apk_path, payload["android-release.apk"])

        if current_release is None or new_key > _version_key(
            current_release["version"], current_release["buildVersion"]
        ):
            _atomic_write(latest_apk_path, payload["android-release.apk"])
            metadata_bytes = (json.dumps(release_metadata, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            _atomic_write(latest_metadata_path, metadata_bytes)
            return f"Published Android {version} ({build_version}): {release_metadata['downloadURL']}"

        if latest_apk_path.is_symlink() or not latest_apk_path.is_file():
            _atomic_write(latest_apk_path, payload["android-release.apk"])
        elif hashlib.sha256(latest_apk_path.read_bytes()).hexdigest() != release_metadata["sha256"]:
            _atomic_write(latest_apk_path, payload["android-release.apk"])
        return f"Android release already published: {release_metadata['downloadURL']}"
    finally:
        os.close(lock_descriptor)


def receive_archive(stream: BinaryIO, root: str | Path) -> str:
    """Validate and atomically publish a supported native app package."""
    root_path = Path(root)
    root_path.mkdir(parents=True, exist_ok=True, mode=0o755)
    if root_path.is_symlink():
        raise SideStoreError("Publication root must not be a symbolic link.")
    os.chmod(root_path, 0o755)

    payload = _read_archive(stream)
    if set(payload) == ALLOWED_ANDROID_ARCHIVE_FILES:
        return _receive_android_release(payload, root_path)

    try:
        release_metadata = json.loads(payload["release.json"].decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SideStoreError("Release metadata is not valid UTF-8 JSON.") from error
    actual, version_entry, app_metadata = _validate_release_metadata(
        release_metadata,
        payload["release.ipa"],
        payload["icon.png"],
    )

    lock_path = root_path / ".publish.lock"
    lock_descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(lock_descriptor, fcntl.LOCK_EX)
        source_path = root_path / "source.json"
        source = _load_source(source_path)
        app = next(
            (
                source_app
                for source_app in source["apps"]
                if source_app.get("bundleIdentifier") == actual["bundleIdentifier"]
            ),
            None,
        )
        if app is None:
            app = {
                "bundleIdentifier": actual["bundleIdentifier"],
                "versions": [],
            }
            source["apps"].append(app)
        versions: list[dict[str, Any]] = app["versions"]
        if any(
            not isinstance(version, dict)
            or not isinstance(version.get("version"), str)
            or not isinstance(version.get("buildVersion"), (str, int))
            for version in versions
        ):
            raise SideStoreError("Existing source.json contains a malformed version entry.")
        new_key = _version_key(actual["version"], actual["buildVersion"])

        same_release = next(
            (
                version
                for version in versions
                if version.get("version") == actual["version"]
                and str(version.get("buildVersion", "")) == actual["buildVersion"]
            ),
            None,
        )
        if same_release is not None:
            if same_release.get("sha256") != version_entry["sha256"]:
                raise SideStoreError("This version/build is already published with different IPA bytes.")
            ipa_path = (
                root_path
                / "apps"
                / actual["bundleIdentifier"]
                / actual["version"]
                / f"{actual['buildVersion']}.ipa"
            )
            if ipa_path.is_symlink():
                raise SideStoreError("The versioned IPA path is not a regular file.")
            if ipa_path.exists():
                if not ipa_path.is_file() or hashlib.sha256(ipa_path.read_bytes()).hexdigest() != version_entry["sha256"]:
                    raise SideStoreError("The already-published IPA does not match the source checksum.")
            else:
                _atomic_write(ipa_path, payload["release.ipa"])
            icon_path = (
                root_path
                / "icons"
                / actual["bundleIdentifier"]
                / actual["version"]
                / f"{actual['buildVersion']}.png"
            )
            if icon_path.is_symlink():
                raise SideStoreError("The versioned app icon path is not a regular file.")
            if icon_path.exists():
                if (
                    not icon_path.is_file()
                    or hashlib.sha256(icon_path.read_bytes()).hexdigest()
                    != release_metadata["iconSha256"]
                ):
                    raise SideStoreError("The already-published app icon does not match the release.")
            else:
                _atomic_write(icon_path, payload["icon.png"])
            return f"Already published: {version_entry['downloadURL']}"

        version_keys = [
            _version_key(version.get("version", ""), str(version.get("buildVersion", "")))
            for version in versions
        ]
        if version_keys and new_key <= max(version_keys):
            raise SideStoreError("A newer release is already published; refusing an out-of-order deployment.")
        if versions:
            highest_build = max(int(version["buildVersion"]) for version in versions)
            if int(actual["buildVersion"]) <= highest_build:
                raise SideStoreError("Build number must increase across all published versions.")

        ipa_path = (
            root_path
            / "apps"
            / actual["bundleIdentifier"]
            / actual["version"]
            / f"{actual['buildVersion']}.ipa"
        )
        if ipa_path.exists():
            if ipa_path.is_symlink() or not ipa_path.is_file():
                raise SideStoreError("The versioned IPA path is not a regular file.")
            existing_hash = hashlib.sha256(ipa_path.read_bytes()).hexdigest()
            if existing_hash != version_entry["sha256"]:
                raise SideStoreError("The versioned IPA path already exists with different bytes.")
        else:
            _atomic_write(ipa_path, payload["release.ipa"])

        icon_path = (
            root_path
            / "icons"
            / actual["bundleIdentifier"]
            / actual["version"]
            / f"{actual['buildVersion']}.png"
        )
        if icon_path.exists():
            if icon_path.is_symlink() or not icon_path.is_file():
                raise SideStoreError("The versioned app icon path is not a regular file.")
            if hashlib.sha256(icon_path.read_bytes()).hexdigest() != release_metadata["iconSha256"]:
                raise SideStoreError("The versioned app icon path already contains different bytes.")
        else:
            _atomic_write(icon_path, payload["icon.png"])
        app["bundleIdentifier"] = actual["bundleIdentifier"]
        app.update(app_metadata)
        app["appPermissions"] = actual["appPermissions"]
        versions.append(copy.deepcopy(version_entry))
        versions.sort(
            key=lambda version: _version_key(
                str(version.get("version", "")),
                str(version.get("buildVersion", "")),
            ),
            reverse=True,
        )
        source_bytes = (json.dumps(source, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        _atomic_write(source_path, source_bytes)
        return f"Published {actual['version']} ({actual['buildVersion']}): {version_entry['downloadURL']}"
    finally:
        os.close(lock_descriptor)


def _package_command(arguments: argparse.Namespace) -> None:
    metadata = package_release(
        arguments.ipa,
        arguments.icon,
        arguments.output,
        arguments.expected_version,
        arguments.release_notes,
        app_name=arguments.app_name,
        developer_name=arguments.developer_name,
        app_subtitle=arguments.app_subtitle,
        app_description=arguments.app_description,
        app_category=arguments.app_category,
    )
    version = metadata["versionEntry"]
    print(f"Prepared SideStore deployment for {version['version']} ({version['buildVersion']}).")


def _package_android_command(arguments: argparse.Namespace) -> None:
    metadata = package_android_release(
        arguments.apk,
        arguments.output,
        arguments.application_id,
        arguments.version,
        arguments.build_version,
    )
    print(
        "Prepared Android deployment for "
        f"{metadata['applicationId']} {metadata['version']} ({metadata['buildVersion']})."
    )


def _receive_command() -> None:
    if os.environ.get("SSH_ORIGINAL_COMMAND", ""):
        raise SideStoreError("Remote commands are not accepted.")
    if len(sys.argv) != 2:
        raise SideStoreError("Arguments are not accepted.")
    print(receive_archive(sys.stdin.buffer, RECEIVE_ROOT))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    package_parser = subparsers.add_parser("package", help="validate and package a built IPA")
    package_parser.add_argument("--ipa", required=True)
    package_parser.add_argument("--icon", required=True)
    package_parser.add_argument("--output", required=True)
    package_parser.add_argument("--expected-version", required=True)
    package_parser.add_argument("--release-notes", required=True)
    package_parser.add_argument("--app-name")
    package_parser.add_argument("--developer-name")
    package_parser.add_argument("--app-subtitle")
    package_parser.add_argument("--app-description")
    package_parser.add_argument("--app-category")
    package_parser.set_defaults(handler=_package_command)
    android_package_parser = subparsers.add_parser(
        "package-android",
        help="validate and package a built Android APK",
    )
    android_package_parser.add_argument("--apk", required=True)
    android_package_parser.add_argument("--output", required=True)
    android_package_parser.add_argument("--application-id", required=True)
    android_package_parser.add_argument("--version", required=True)
    android_package_parser.add_argument("--build-version", required=True)
    android_package_parser.set_defaults(handler=_package_android_command)
    receive_parser = subparsers.add_parser("receive", help=argparse.SUPPRESS)
    receive_parser.set_defaults(handler=lambda _: _receive_command())
    arguments = parser.parse_args()
    try:
        arguments.handler(arguments)
    except (SideStoreError, OSError) as error:
        print(f"SideStore publication failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
