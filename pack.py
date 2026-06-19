import os
import zipfile

# === CONFIG ===

SHADERS_DIR = "shaders"
README_FILE = "README.md"
OUTPUT_ZIP = "AuroraShades.zip"

def zip_shader_pack():
    with zipfile.ZipFile(OUTPUT_ZIP, 'w', zipfile.ZIP_DEFLATED) as zipf:

        # Add shaders directory
        for root, dirs, files in os.walk(SHADERS_DIR):
            for file in files:
                full_path = os.path.join(root, file)
                
                # Preserve folder structure inside zip
                arcname = os.path.relpath(full_path, ".")
                zipf.write(full_path, arcname)

        # Add README.md at root of zip
        if os.path.isfile(README_FILE):
            zipf.write(README_FILE, README_FILE)
        else:
            print("WARNING: README.md not found!")

print(f"Created {OUTPUT_ZIP}")


if __name__ == "__main__":
    zip_shader_pack()
