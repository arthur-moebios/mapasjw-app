import hashlib
import importlib.util
import json
import plistlib
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / ".github/scripts/sidestore.py"
ICON_PATH = ROOT / "mobile/flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
SPEC = importlib.util.spec_from_file_location("mapasjw_sidestore", SCRIPT_PATH)
SIDESTORE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(SIDESTORE)


def create_test_ipa(path: Path) -> None:
    info = {
        "CFBundleIdentifier": "br.com.mapasjw.cartas",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1000000",
        "CFBundleDisplayName": "Mapas JW",
        "MinimumOSVersion": "14.0",
    }
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("Payload/Mapas JW.app/Info.plist", plistlib.dumps(info))
        archive.writestr("Payload/Mapas JW.app/Mapas JW", b"test-binary")


class SideStoreReleasePackagingTest(unittest.TestCase):
    def test_android_archive_contains_real_size_checksum_and_stable_urls(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            apk_path = directory / "release.apk"
            archive_path = directory / "android.tar"
            with zipfile.ZipFile(apk_path, "w") as apk:
                apk.writestr("AndroidManifest.xml", b"binary-android-manifest")

            metadata = SIDESTORE.package_android_release(
                apk_path,
                archive_path,
                "br.com.mapasjw.cartas",
                "1.0.0",
                "1000000",
            )

            self.assertEqual(metadata["size"], apk_path.stat().st_size)
            self.assertEqual(metadata["sha256"], hashlib.sha256(apk_path.read_bytes()).hexdigest())
            self.assertEqual(
                metadata["downloadURL"],
                "https://app.moebiosenergy.com.br/sidestore/apps/android/br.com.mapasjw.cartas/1.0.0/1000000.apk",
            )
            self.assertEqual(
                metadata["latestURL"],
                "https://app.moebiosenergy.com.br/sidestore/apps/android/br.com.mapasjw.cartas/latest.apk",
            )
            with tarfile.open(archive_path, "r") as archive:
                payload = json.load(archive.extractfile("android-release.json"))
                self.assertEqual(payload, metadata)
                self.assertEqual(archive.extractfile("android-release.apk").read(), apk_path.read_bytes())

    def test_ipa_metadata_is_read_from_archive_and_keeps_shared_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            ipa_path = directory / "mapas-jw.ipa"
            archive_path = directory / "ios.tar"
            create_test_ipa(ipa_path)

            metadata = SIDESTORE.package_release(
                ipa_path,
                ICON_PATH,
                archive_path,
                "1.0.0",
                "Versão inicial do Mapas JW.",
                app_name="Mapas JW",
                developer_name="Moebios Energy",
                app_subtitle="Mapas e territórios da congregação.",
                app_description="Acesse os territórios do Mapas JW.",
                app_category="utilities",
            )

            self.assertEqual(metadata["bundleIdentifier"], "br.com.mapasjw.cartas")
            self.assertEqual(metadata["appMetadata"]["name"], "Mapas JW")
            self.assertEqual(
                metadata["versionEntry"]["downloadURL"],
                "https://app.moebiosenergy.com.br/sidestore/apps/br.com.mapasjw.cartas/1.0.0/1000000.ipa",
            )
            self.assertEqual(metadata["versionEntry"]["size"], ipa_path.stat().st_size)
            with tarfile.open(archive_path, "r") as archive:
                release = json.load(archive.extractfile("release.json"))
                self.assertEqual(release, metadata)
                self.assertEqual(archive.extractfile("release.ipa").read(), ipa_path.read_bytes())

    def test_invalid_android_application_id_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            apk_path = directory / "release.apk"
            with zipfile.ZipFile(apk_path, "w") as apk:
                apk.writestr("AndroidManifest.xml", b"manifest")

            with self.assertRaises(SIDESTORE.SideStoreError):
                SIDESTORE.package_android_release(
                    apk_path,
                    directory / "release.tar",
                    "not-an-application-id",
                    "1.0.0",
                    "1000000",
                )

    def test_ipa_publication_preserves_other_apps_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            ipa_path = directory / "mapas-jw.ipa"
            archive_path = directory / "ios.tar"
            publication_root = directory / "published"
            create_test_ipa(ipa_path)
            SIDESTORE.package_release(
                ipa_path,
                ICON_PATH,
                archive_path,
                "1.0.0",
                "Versão inicial do Mapas JW.",
                app_name="Mapas JW",
                developer_name="Moebios Energy",
                app_subtitle="Mapas e territórios da congregação.",
                app_description="Acesse os territórios do Mapas JW.",
                app_category="utilities",
            )
            existing_source = SIDESTORE._base_source()
            existing_source["name"] = "Moebios Energy"
            existing_source["description"] = "Apps oficiais da Moebios Energy."
            existing_source["apps"].append(
                {
                    "bundleIdentifier": "com.moebiosenergy.mobile",
                    "versions": [{"version": "1.0.0", "buildVersion": "3"}],
                }
            )
            publication_root.mkdir()
            (publication_root / "source.json").write_text(
                json.dumps(existing_source),
                encoding="utf-8",
            )

            with archive_path.open("rb") as archive:
                published_message = SIDESTORE.receive_archive(archive, publication_root)
            with archive_path.open("rb") as archive:
                repeated_message = SIDESTORE.receive_archive(archive, publication_root)

            source = json.loads((publication_root / "source.json").read_text(encoding="utf-8"))
            identifiers = {app["bundleIdentifier"] for app in source["apps"]}
            self.assertEqual(identifiers, {"com.moebiosenergy.mobile", "br.com.mapasjw.cartas"})
            self.assertEqual(source["name"], "Arthur’s Apps")
            self.assertEqual(
                source["description"],
                "Aplicativos de Arthur disponíveis para instalação pelo SideStore.",
            )
            self.assertIn("Published 1.0.0 (1000000)", published_message)
            self.assertIn("Already published", repeated_message)
            self.assertEqual(len(source["apps"]), 2)


if __name__ == "__main__":
    unittest.main()
