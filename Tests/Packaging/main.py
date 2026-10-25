"""Verify the download cannot accidentally include developer or account files."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("packaging", root / "package_release.py")
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)

class DistributionContentsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.app = Path(self.temporary.name) / "Cursor Usage.app"
        for name in ["Contents/Info.plist", "Contents/MacOS/CursorUsage", "Contents/Resources/Cursor.png", "Contents/_CodeSignature/CodeResources"]:
            file = self.app / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b"fixture")

    def test_minimal_bundle_is_allowed(self):
        packaging.validate_app_bundle(self.app)

    def test_development_and_account_files_are_rejected(self):
        for name in ["Contents/Resources/Tests/main.swift", "Contents/Resources/history.json", "Contents/Resources/build.py"]:
            with self.subTest(name=name):
                file = self.app / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(b"fictional")
                with self.assertRaises(ValueError):
                    packaging.validate_app_bundle(self.app)
                file.unlink()

    def test_missing_executable_is_rejected(self):
        (self.app / "Contents/MacOS/CursorUsage").unlink()
        with self.assertRaises(ValueError):
            packaging.validate_app_bundle(self.app)

    def test_external_links_are_rejected(self):
        (self.app / "Contents/Resources/external").symlink_to(self.app.parent)
        with self.assertRaises(ValueError):
            packaging.validate_app_bundle(self.app)

if __name__ == "__main__":
    unittest.main()
