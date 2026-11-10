import os, shutil, zipfile

MOD_DIR = os.path.dirname(os.path.abspath(__file__))
SCRATCH = r"C:\Users\Yakuzo\.gemini\antigravity\brain\da85a305-de7a-4549-b7dc-e0dc0b53d57f\scratch"
ZIP_NAME = "LH8n_HyperOS_Stability_Gaming_v1.0.4.zip"

# 1. Copy patched services.jar if scratch artifact is present; otherwise package checked-in jar
fw_dst = os.path.join(MOD_DIR, "system", "framework", "services.jar")
os.makedirs(os.path.dirname(fw_dst), exist_ok=True)
src_jar = os.path.join(SCRATCH, "services_patched_vhal.jar")
if os.path.isfile(src_jar):
    shutil.copy2(src_jar, fw_dst)

# 2. Enforce LF line endings on all shell/text/xml/prop files
LF_EXTS = (".sh", ".prop", ".xml", ".txt")
for r, dirs, files in os.walk(MOD_DIR):
    dirs[:] = [d for d in dirs if not d.startswith(".")]
    for f in files:
        p = os.path.join(r, f)
        if f.endswith(LF_EXTS) or f in ("update-binary", "updater-script"):
            raw = open(p, "rb").read()
            fixed = raw.replace(b"\r\n", b"\n")
            if raw != fixed:
                open(p, "wb").write(fixed)

# 3. Build flashable KernelSU zip
os.chdir(MOD_DIR)
exclude = {".git", ".gitignore", ".gitattributes", "README.md", "build.py", "src", ZIP_NAME}
with zipfile.ZipFile(ZIP_NAME, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for r, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in exclude and not d.startswith(".")]
        for f in files:
            if f in exclude or f.startswith(".") or f.endswith((".zip", ".log", ".java", ".class")):
                continue
            full_path = os.path.join(r, f)
            rel_path = os.path.relpath(full_path, ".").replace("\\", "/")
            zi = zipfile.ZipInfo(rel_path)
            # Compress everything except services.jar? No, zip module installer unzips all entries cleanly
            zi.compress_type = zipfile.ZIP_DEFLATED
            # Preserve executable permission attributes in Unix zip metadata cleanly
            if rel_path.endswith(".sh") or rel_path == "META-INF/com/google/android/update-binary":
                zi.external_attr = 0o100755 << 16
            else:
                zi.external_attr = 0o100644 << 16
            z.writestr(zi, open(full_path, "rb").read())
            print("Added:", rel_path)

print(f"\nBuilt {os.path.join(MOD_DIR, ZIP_NAME)} ({os.path.getsize(ZIP_NAME)} bytes)!")
