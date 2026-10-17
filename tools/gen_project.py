#!/usr/bin/env python3
"""Generate Zenith.xcodeproj/project.pbxproj (Xcode 16+ synchronized folder, no XcodeGen needed).
Re-run after changing build settings; source files in ./Zenith are picked up automatically."""
import hashlib, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUNDLE = "com.vashchenko.zenithsky"
TEAM = "8ZQ6AC3JS9"
IOS = "26.0"


def oid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


objects = {}


def add(key, isa, **attrs):
    i = oid(key)
    objects[i] = (isa, attrs)
    return i


def fmt(v, ind):
    pad = "\t" * ind
    if isinstance(v, dict):
        return "{\n" + "".join(f"{pad}\t{k} = {fmt(val, ind+1)};\n" for k, val in v.items()) + pad + "}"
    if isinstance(v, list):
        return "(\n" + "".join(f"{pad}\t{fmt(x, ind+1)},\n" for x in v) + pad + ")"
    if isinstance(v, bool):
        return "YES" if v else "NO"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v)
    if s and all(c.isalnum() or c in "_./" for c in s) and not s.startswith("."):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "SWIFT_VERSION": "5.0", "SWIFT_EMIT_LOC_STRINGS": "YES", "SWIFT_STRICT_CONCURRENCY": "minimal",
    "CODE_SIGN_STYLE": "Automatic", "CODE_SIGN_IDENTITY": "Apple Development", "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GENERATE_INFOPLIST_FILE": "YES",
    "MARKETING_VERSION": "1.0", "CURRENT_PROJECT_VERSION": "2",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
}
DEBUG = {"DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_OPTIMIZATION_LEVEL": 0,
         "ONLY_ACTIVE_ARCH": "YES", "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
         "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"}
RELEASE = {"DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "SWIFT_OPTIMIZATION_LEVEL": "-O",
           "SWIFT_COMPILATION_MODE": "wholemodule"}

APP = {
    "IPHONEOS_DEPLOYMENT_TARGET": IOS, "TARGETED_DEVICE_FAMILY": "1",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "INFOPLIST_KEY_CFBundleDisplayName": "Zenith Sky",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "INFOPLIST_KEY_UIUserInterfaceStyle": "Dark",
    "INFOPLIST_KEY_UIAppFonts": "",
    "INFOPLIST_FILE": "Config/Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "ENABLE_PREVIEWS": "YES", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE, "PRODUCT_NAME": "$(TARGET_NAME)",
}
APP.pop("INFOPLIST_KEY_UIAppFonts")

prod = add("product.Zenith", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex=0,
           path="Zenith.app", sourceTree="BUILT_PRODUCTS_DIR")
sync = add("sync.Zenith", "PBXFileSystemSynchronizedRootGroup", path="Zenith", sourceTree="<group>")
srcs = add("phase.src", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
frms = add("phase.frm", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
ress = add("phase.res", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)

s = {**COMMON, **APP}
d = add("cfg.debug.app", "XCBuildConfiguration", buildSettings={**s, **DEBUG}, name="Debug")
r = add("cfg.release.app", "XCBuildConfiguration", buildSettings={**s, **RELEASE}, name="Release")
cl = add("cfglist.app", "XCConfigurationList", buildConfigurations=[d, r], defaultConfigurationIsVisible=0,
         defaultConfigurationName="Release")
target = oid("target.Zenith")
objects[target] = ("PBXNativeTarget", dict(
    buildConfigurationList=cl, buildPhases=[srcs, frms, ress], buildRules=[], dependencies=[],
    fileSystemSynchronizedGroups=[sync], name="Zenith", packageProductDependencies=[],
    productName="Zenith", productReference=prod, productType="com.apple.product-type.application"))

products = add("group.products", "PBXGroup", children=[prod], name="Products", sourceTree="<group>")
config = add("group.config", "PBXGroup", children=[
    add("file.Info.plist", "PBXFileReference", lastKnownFileType="text.plist.xml", path="Info.plist", sourceTree="<group>")],
    path="Config", sourceTree="<group>")
main = add("group.main", "PBXGroup", children=[sync, config, products], sourceTree="<group>")

pd = add("cfg.debug.project", "XCBuildConfiguration",
         buildSettings={**COMMON, **DEBUG, "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": IOS}, name="Debug")
pr = add("cfg.release.project", "XCBuildConfiguration",
         buildSettings={**COMMON, **RELEASE, "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": IOS,
                        "VALIDATE_PRODUCT": "YES"}, name="Release")
pcl = add("cfglist.project", "XCConfigurationList", buildConfigurations=[pd, pr], defaultConfigurationIsVisible=0,
          defaultConfigurationName="Release")
objects[oid("project")] = ("PBXProject", dict(
    attributes={"BuildIndependentTargetsInParallel": 1, "LastSwiftUpdateCheck": 2600, "LastUpgradeCheck": 2600,
                "TargetAttributes": {target: {"CreatedOnToolsVersion": "26.0"}}},
    buildConfigurationList=pcl, compatibilityVersion="Xcode 16.0", developmentRegion="en", hasScannedForEncodings=0,
    knownRegions=["en", "Base"], mainGroup=main, productRefGroup=products, projectDirPath="", projectRoot="",
    targets=[target]))

out = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n\tobjects = {\n"
for i, (isa, attrs) in sorted(objects.items(), key=lambda kv: (kv[1][0], kv[0])):
    out += f"\t\t{i} = {fmt({'isa': isa, **attrs}, 2)};\n"
out += "\t};\n\trootObject = " + oid("project") + ";\n}\n"
proj = ROOT / "Zenith.xcodeproj"
proj.mkdir(exist_ok=True)
(proj / "project.pbxproj").write_text(out)

scheme_dir = proj / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "Zenith.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Zenith.app" BlueprintName="Zenith" ReferencedContainer="container:Zenith.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Zenith.app" BlueprintName="Zenith" ReferencedContainer="container:Zenith.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("wrote", proj / "project.pbxproj", f"({len(objects)} objects)")
