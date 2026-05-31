# Codex Pets Library

This repository collects my Codex pets in a simple, publishable structure.

## Layout

- `pets/<pet-folder>/pet.json`
- `pets/<pet-folder>/spritesheet.webp`
- `index.json` for the full pet list

## Notes

- Each pet folder is a standalone package.
- The current library contains 84 pets.
- Some folder names are kept from the original build output, so a folder name may differ from the `id` inside `pet.json`.

## Publish To GitHub

1. Create an empty GitHub repository.
2. In this folder, initialize Git.
3. Add `pets`, `README.md`, `.gitignore`, and `index.json`.
4. Commit once.
5. Add your GitHub remote and push.

Example:

```bash
git init
git add pets README.md .gitignore index.json
git commit -m "Initial pet library"
git branch -M main
git remote add origin git@github.com:YOUR_NAME/codex-pets.git
git push -u origin main
```

## Optional Next Step

If you want, you can later add a `LICENSE` file and a small preview site for browsing the pets visually.
