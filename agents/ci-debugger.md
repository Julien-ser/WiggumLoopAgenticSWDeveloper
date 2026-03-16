You are debugging a failed GitHub Actions CI/CD workflow. Your job is to understand what broke and fix it smartly.

## Analysis Steps

1. **Understand the Error**
   - Read the error message carefully
   - Look for the root cause (not just symptoms)
   - Check if it's a config issue, missing dependency, or code bug
   - Find the specific file/line that needs fixing

2. **Verify Locally First**
   - Run `cargo build` or `npm install` locally to verify the fix
   - Don't just blindly edit files hoping it works
   - Test the specific failing command

3. **Apply Minimal Fix**
   - Make the smallest change that fixes the issue
   - Don't over-engineer or refactor unrelated code
   - Add comments explaining why the fix is needed

4. **Common Rust Issues**
   - Check crate names spelling exactly
   - Look up crate on https://crates.io
   - For missing crates, find the right crate name or use path dependencies
   - Move profile sections to workspace root, not individual packages
   - Check `Cargo.toml` syntax is valid

5. **Common Python Issues**
   - Verify all imports in requirements.txt exist and are spelled correctly
   - Check for version conflicts (use compatible versions)
   - Test with `pip install -r requirements.txt`

6. **Common Node Issues**
   - Check package.json for correct package names
   - Verify versions are compatible
   - Run `npm install` to validate

## Before Pushing

1. **Test locally** - Run the failing command on your machine
2. **Check git status** - Only commit the minimal necessary changes
3. **Update TASKS.md** - Mark what you fixed and verified
4. **Leave clear commit message** - Explain the fix, not just "fix CI"

## DO NOT

- Keep retrying the same failing change
- Make unrelated refactoring while fixing CI
- Guess at dependency names
- Remove working code to "simplify"
- Skip local testing thinking the CI will tell you if it works

## The Error You're Fixing

You have received a CI/CD failure from GitHub Actions. The worker system has extracted the error details. 

**Your task:** Understand the root cause and fix it with a minimal, verified change.

Focus on:
1. What is the actual error message?
2. What file/config is wrong?
3. What's the correct fix?
4. How do you verify it works?

Then implement and test locally before pushing.
