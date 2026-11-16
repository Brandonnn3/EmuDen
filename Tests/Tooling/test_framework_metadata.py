import importlib.util
from pathlib import Path
import plistlib
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('framework_metadata',ROOT/'Scripts/check-framework-metadata.py')
metadata=importlib.util.module_from_spec(spec);spec.loader.exec_module(metadata)


class FrameworkMetadataTests(unittest.TestCase):
    def info(self):
        return plistlib.loads((ROOT/'Scripts/GameCubeFramework-Info.plist.in').read_text().replace('@EMUDEN_GC_PLATFORM@','iPhoneOS').replace('@CMAKE_OSX_DEPLOYMENT_TARGET@','18.0').encode())

    def test_correct_info_and_deployment_agreement(self):
        metadata.check_info(self.info(),'IOS','18.0','18.0')

    def test_missing_blank_mismatched_and_wrong_platform_are_rejected(self):
        for key in ['MinimumOSVersion','CFBundleVersion','CFBundleShortVersionString','CFBundleName']:
            for value in [None,'']:
                info=self.info()
                if value is None:del info[key]
                else:info[key]=value
                with self.subTest(key=key,value=value),self.assertRaises(AssertionError):metadata.check_info(info,'IOS','18.0')
        for platform,minimum,app in [('IOSSIMULATOR','18.0','18.0'),('IOS','17.0','18.0'),('IOS','18.0','17.0')]:
            with self.subTest(platform=platform,minimum=minimum,app=app),self.assertRaises(AssertionError):metadata.check_info(self.info(),platform,minimum,app)
