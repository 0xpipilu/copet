#!/usr/bin/env python3
import os
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
PETS_DIR = WORKSPACE_ROOT / "pets"

def fix_svgs():
    print(f"Scanning pets directory: {PETS_DIR}")
    if not PETS_DIR.exists():
        print("Error: pets directory not found.")
        return

    fixed_count = 0
    skipped_count = 0

    for pet_dir in sorted(PETS_DIR.iterdir()):
        if not pet_dir.is_dir():
            continue
            
        svg_file = pet_dir / "animated.svg"
        if not svg_file.exists():
            continue
            
        try:
            content = svg_file.read_text(encoding="utf-8")
            
            # Check if it already has pixelated rendering
            if "image-rendering" in content:
                skipped_count += 1
                continue
                
            # Locate the .sprite selector and inject rendering rules
            target_str = ".sprite {"
            if target_str in content:
                replacement = ".sprite {\n        image-rendering: -moz-crisp-edges;\n        image-rendering: -webkit-crisp-edges;\n        image-rendering: pixelated;\n        image-rendering: crisp-edges;"
                content = content.replace(target_str, replacement)
                svg_file.write_text(content, encoding="utf-8")
                print(f"✨ Sharp rendering injected into: {pet_dir.name}/animated.svg")
                fixed_count += 1
            else:
                print(f"⚠️ Warning: Could not find '.sprite {{' in {pet_dir.name}/animated.svg")
                skipped_count += 1
        except Exception as e:
            print(f"❌ Error processing {pet_dir.name}/animated.svg: {e}")
            
    print(f"\nCompleted! Fixed: {fixed_count} SVGs, Skipped/Already Fixed: {skipped_count} SVGs.")

if __name__ == "__main__":
    fix_svgs()
