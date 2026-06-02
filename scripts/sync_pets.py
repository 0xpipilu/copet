#!/usr/bin/env python3
import os
import shutil
import subprocess
import json
from pathlib import Path

# Paths
WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
SOURCE_PETS_DIR = Path("/Users/chen/.codex/pets")
TARGET_PETS_DIR = WORKSPACE_ROOT / "pets"

def run_cmd(args, cwd=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running command {' '.join(args)}:")
        print(result.stderr)
    return result

def sync_pets():
    print(f"Scanning source directory: {SOURCE_PETS_DIR}")
    print(f"Target directory: {TARGET_PETS_DIR}")
    
    if not SOURCE_PETS_DIR.exists():
        print(f"Error: Source directory {SOURCE_PETS_DIR} does not exist.")
        return

    TARGET_PETS_DIR.mkdir(parents=True, exist_ok=True)
    
    # 1. Detect and remove deleted pets from target
    source_pet_names = set()
    if SOURCE_PETS_DIR.exists():
        for item in SOURCE_PETS_DIR.iterdir():
            if item.is_dir() and (item / "pet.json").exists():
                source_pet_names.add(item.name)

    target_pet_names = set()
    for item in TARGET_PETS_DIR.iterdir():
        if item.is_dir():
            target_pet_names.add(item.name)

    deleted_pets = sorted(list(target_pet_names - source_pet_names))
    
    # Actually delete the folders
    for pet_name in deleted_pets:
        target_pet_dir = TARGET_PETS_DIR / pet_name
        print(f"🗑️ Found deleted pet locally: {pet_name}, removing from target...")
        shutil.rmtree(target_pet_dir, ignore_errors=True)

    synced_pets = []
    updated_pets = []
    
    # 2. Iterate through all subdirectories in the source directory to add/update
    for item in sorted(SOURCE_PETS_DIR.iterdir()):
        if not item.is_dir():
            continue
            
        pet_json_source = item / "pet.json"
        if not pet_json_source.exists():
            continue
            
        pet_name = item.name
        target_pet_dir = TARGET_PETS_DIR / pet_name
        
        # Check if the pet is new or updated
        is_new = not target_pet_dir.exists()
        needs_update = False
        
        if not is_new:
            # Check modification times of key files to see if it was updated
            for f in ["pet.json", "base.png", "spritesheet.webp"]:
                src_f = item / f
                tgt_f = target_pet_dir / f
                if src_f.exists():
                    if not tgt_f.exists() or src_f.stat().st_mtime > tgt_f.stat().st_mtime:
                        needs_update = True
                        break
        
        if is_new or needs_update:
            if is_new:
                print(f"🆕 Found new pet: {pet_name}")
                shutil.copytree(item, target_pet_dir, dirs_exist_ok=True)
                synced_pets.append(pet_name)
            else:
                print(f"🔄 Found updated pet: {pet_name}")
                shutil.copytree(item, target_pet_dir, dirs_exist_ok=True)
                updated_pets.append(pet_name)

    total_changes = len(synced_pets) + len(updated_pets) + len(deleted_pets)
    
    if total_changes == 0:
        print("✅ All pets are already fully in sync!")
        return
        
    print(f"\nSuccessfully synced: {len(synced_pets)} new, {len(updated_pets)} updated, {len(deleted_pets)} deleted.")
    
    # Rebuild Index, generate optimized thumbnails, and README
    print("\n🛠️ Rebuilding index, thumbnails, and README...")
    run_cmd(["python3", "scripts/build_index.py"], cwd=WORKSPACE_ROOT)
    run_cmd(["python3", "scripts/generate_thumbnails.py"], cwd=WORKSPACE_ROOT)
    run_cmd(["python3", "scripts/build_readme.py"], cwd=WORKSPACE_ROOT)
    
    # Auto git commit & push (Optimized safe one-click deployment)
    print("\n🚀 Pushing changes to GitHub and deploying to live site...")
    
    # Safe Git Add: stage deletions (-A stages removed folders/files too)
    run_cmd(["git", "add", "-A", "pets/", "index.json", "catalog.js", "README.md"], cwd=WORKSPACE_ROOT)
    
    commit_msg = "Feat: auto-sync pets from .codex"
    details = []
    if synced_pets:
        details.append(f"added: {', '.join(synced_pets)}")
    if updated_pets:
        details.append(f"updated: {', '.join(updated_pets)}")
    if deleted_pets:
        details.append(f"deleted: {', '.join(deleted_pets)}")
        
    if details:
        commit_msg += f" ({'; '.join(details)})"
        
    run_cmd(["git", "commit", "-m", commit_msg], cwd=WORKSPACE_ROOT)
    run_cmd(["git", "push", "origin", "main"], cwd=WORKSPACE_ROOT)
    
    print("\n🎉 Synchronization complete and live website updated!")
    print(f"👉 Visit https://cod.pet to see your new pets!")

if __name__ == "__main__":
    sync_pets()
