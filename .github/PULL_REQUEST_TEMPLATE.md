# Summary

<!-- Describe the formula/cask or documentation change and link the upstream release or issue. -->

## Required verification

- [ ] `brew style Formula/ Casks/ cmd/` reports 0 offenses
- [ ] `brew audit --strict --tap=heretek-ai/tap` and `brew audit --cask --strict --tap=heretek-ai/tap` pass
- [ ] `python3 scripts/generate_readme.py --check` passes
- [ ] `./scripts/test_local_tap.sh` passes
- [ ] `python3 -m unittest discover -s tests/ -v` passes
- [ ] `pytest tests/ -q` passes
- [ ] Workflow YAML is valid and `actionlint` passes (when workflows or actions change)
- [ ] `shellcheck .github/scripts/*.sh scripts/*.sh` passes (when shell scripts change)
- [ ] `git ls-files --stage | awk '$1 == "160000"'` prints nothing (no gitlinks or scratch clones)
- [ ] `.github/workflows/ocr.yml` is unchanged

## Notes for reviewers

<!-- Call out service-port registry changes, new options, bottle impact, or manual verification. -->
