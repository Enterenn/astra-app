import glob
import os
import re

root = os.path.join(os.path.dirname(__file__), "..", "test")
pat = re.compile(r"^\s*(?:test|testWidgets)\(", re.M)

def count_tag(tag):
    n = 0
    for path in glob.glob(os.path.join(root, "**", "*.dart"), recursive=True):
        base = os.path.basename(path)
        if not (base.endswith("_test.dart") or base == "widget_test.dart"):
            continue
        text = open(path, encoding="utf-8").read()
        if f"@Tags(['{tag}'])" in text:
            n += len(pat.findall(text))
    return n

total = sum(
    len(pat.findall(open(p, encoding="utf-8").read()))
    for p in glob.glob(os.path.join(root, "**", "*.dart"), recursive=True)
    if os.path.basename(p).endswith("_test.dart") or os.path.basename(p) == "widget_test.dart"
)
crit = count_tag("critical")
slow = count_tag("slow")
print(f"total={total}")
print(f"critical={crit}")
print(f"slow={slow}")
print(f"untagged={total - crit - slow}")
