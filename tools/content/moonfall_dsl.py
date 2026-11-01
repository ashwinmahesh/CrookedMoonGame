#!/usr/bin/env python3
"""R26 Moonfall: a small authoring DSL for the .dialogue files. The LOGIC (nodes, options, flags, checks) is written here by hand; every spoken
and Narrator line is a numbered placeholder with a BRIEF, which Gemini drafts (moonfall_gemini.py) and moonfall_dialogue.py fills in.
A line with no draft yet is written as its brief, so the data always validates."""
import re

MOODS = {"neutral", "smile", "angry", "afraid", "sad", "sly", "weary"}


class Line:
    def __init__(self, who, mood, brief):
        self.who, self.mood, self.brief = who, mood, brief
        self.id = None


def S(who, mood, brief):
    assert mood in MOODS, mood
    return Line(who, mood, brief)


def N(brief):
    return Line("Narrator", None, brief)


def L(text):
    return text


class Opt:
    def __init__(self, text, to, fail=None, skill=None, dc=None, cond=None, ends=None):
        self.text, self.to, self.fail, self.skill, self.dc, self.cond, self.ends = text, to, fail, skill, dc, cond, ends

    def render(self):
        tags = ""
        if self.cond:
            tags += f"[if {self.cond}] "
        if self.ends:
            tags += f"[ends:{self.ends}] "
        if self.skill:
            tags += f"[{self.skill} DC {self.dc}] "
        tgt = self.to if not self.fail else f"{self.to} | {self.fail}"
        return f"* {tags}{self.text} -> {tgt}"


def O(text, to, **kw):
    return Opt(text, to, **kw)


def SK(skill, dc, text, ok, fail, cond=None):
    return Opt(text, ok, fail=fail, skill=skill, dc=dc, cond=cond)


def cut2(cid, a, b):
    """A two-picture cutscene: the first picture under the first line, the second under the next, then taken away."""
    return [L(f"cutscene {cid}"), a, L(f"cutscene {cid}_2"), b, L("cutscene end")]


class File:
    def __init__(self, name, header):
        self.name, self.header = name, header
        self.nodes = []   # (name, [items])
        self.lines = []

    def node(self, name, *items):
        flat = []
        for it in items:
            if isinstance(it, list):
                flat.extend(it)
            else:
                flat.append(it)
        for it in flat:
            if isinstance(it, Line):
                it.id = f"{self.name}.{len(self.lines) + 1}"
                self.lines.append(it)
        self.nodes.append((name, flat))
        return self

    def briefs(self):
        out = []
        for ln in self.lines:
            out.append({"id": ln.id, "who": ln.who, "mood": ln.mood or "", "brief": ln.brief})
        return out

    def render(self, texts):
        out = [f"# {self.header}", ""]
        for name, items in self.nodes:
            out.append(f"~ {name}")
            for it in items:
                if isinstance(it, Line):
                    t = texts.get(it.id) or it.brief
                    t = clean(t)
                    out.append(f"{it.who}: {t}" if it.who == "Narrator" else f"{it.who} [{it.mood}]: {t}")
                elif isinstance(it, Opt):
                    out.append(it.render())
                else:
                    out.append(it)
            out.append("")
        return "\n".join(out).rstrip() + "\n"


def clean(t):
    t = t.strip().replace("—", ",").replace("–", "-").replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    t = re.sub(r"\s+", " ", t)
    t = t.strip('"') if t.count('"') == 2 and t.startswith('"') and t.endswith('"') else t
    return t
