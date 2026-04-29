---
name: code-stats
tier: extended
description: Count lines of code by language using cloc.
argument-hint: [path]
allowed-tools: Bash(cloc:*)
model: haiku
---

# Code Statistics

Count files and lines of code in the current codebase.

## Arguments

- **No argument**: Analyze the current working directory
- **Path**: Analyze that specific directory (e.g., `/code-stats src/`)

## Instructions

1. **Determine target path** from arguments or use current working directory

2. **Run cloc** on the target:

   ```bash
   cloc <target_path> --exclude-dir=node_modules,.git,dist,build,coverage,__pycache__,.venv,venv
   ```

3. **Present results** - cloc output includes:
   - Files by language
   - Lines of code (blank, comment, code)
   - Summary totals

4. **If cloc is not installed**, inform the user:
   - macOS: `brew install cloc`
   - Ubuntu/Debian: `apt install cloc`
   - Or visit: <https://github.com/AlDanial/cloc>

## Example Output

```text
$ /code-stats

-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
TypeScript                      42            892            234           4521
JavaScript                       8            123             45            567
JSON                            12              0              0            890
Markdown                         5            234              0            456
CSS                              3             89             12            234
-------------------------------------------------------------------------------
SUM:                            70           1338            291           6668
-------------------------------------------------------------------------------
```

## Notes

- Common build/dependency directories are excluded by default
- For monorepos, specify a path to analyze a specific package
- Results include blank lines and comments separately from actual code
