"""
Connect Four – FastAPI backend
Uses SWI-Prolog (swipl) as a subprocess to keep ALL game logic in Prolog.
Every request spins up a fresh Prolog goal; no in-process state.
"""

import subprocess, re, sys
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

app = FastAPI(title="Connect Four")

PROLOG_FILE = Path(__file__).parent / "connect_four.pl"

# ── Find swipl on Windows or Unix ────────────────────────────────────────────

def _find_swipl() -> str:
    """Return the swipl executable path, checking common Windows locations."""
    import shutil, os

    # 1. Already on PATH?
    found = shutil.which("swipl")
    if found:
        return found

    # 2. Common Windows install paths
    if sys.platform == "win32":
        candidates = []
        for base in [
            r"C:\Program Files\swipl",
            r"C:\Program Files (x86)\swipl",
        ]:
            candidates.append(str(Path(base) / "bin" / "swipl.exe"))

        # Also search Program Files for any swipl-* folder
        for pf in [r"C:\Program Files", r"C:\Program Files (x86)"]:
            pf_path = Path(pf)
            if pf_path.exists():
                for d in pf_path.iterdir():
                    if d.is_dir() and "swipl" in d.name.lower():
                        candidates.append(str(d / "bin" / "swipl.exe"))

        for c in candidates:
            if Path(c).exists():
                return c

        raise FileNotFoundError(
            "SWI-Prolog (swipl.exe) not found.\n"
            "Download from https://www.swi-prolog.org/Download.html\n"
            "and make sure 'swipl' is on your PATH, or install to the default location."
        )

    raise FileNotFoundError("swipl not found on PATH.")

SWIPL = _find_swipl()


# ── Prolog helpers ────────────────────────────────────────────────────────────

def board_to_prolog(board: list[list[str]]) -> str:
    """Convert a Python 6×7 list-of-lists into a Prolog term string."""
    def cell(c):
        return c if c in ("x", "o") else "empty"
    rows = []
    for row in board:
        cells = ",".join(cell(c) for c in row)
        rows.append(f"[{cells}]")
    return f"[{','.join(rows)}]"


def run_prolog(goal: str) -> str:
    """Run swipl with the given goal and return stdout."""
    cmd = [SWIPL, "-q", "-f", str(PROLOG_FILE), "-g", goal, "-t", "halt"]
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=60,
        creationflags=0x08000000 if sys.platform == "win32" else 0  # no console window
    )
    output = result.stdout.strip()
    # swipl may exit 1 after a normal halt/0; only treat as error if no output and stderr
    if not output and result.returncode not in (0, 1):
        err = result.stderr.strip()
        raise RuntimeError(err or f"swipl exited {result.returncode}")
    return output


# ── Board parser ──────────────────────────────────────────────────────────────

def _parse_board_and_status(raw: str, include_col: bool = False) -> dict:
    """
    Parse output of:
      write_term(result(TAG, BOARD, STATUS), [quoted(true)])
    where TAG is 'ok'/'invalid' or an integer (AI column).

    Strategy: tokenise the flat character stream rather than regex-matching
    nested brackets, which is fragile.
    """
    raw = raw.strip()

    # ── status (last meaningful token before closing paren) ──
    status_str = "continue"
    winner = None
    m = re.search(r",\s*(continue|draw|win\(([xo])\))\s*\)\s*$", raw)
    if m:
        status_str = m.group(1)
        if status_str == "draw":
            status = "draw"
        elif status_str.startswith("win"):
            status = "win"
            winner = m.group(2)
        else:
            status = "continue"
    else:
        status = "continue"

    # ── board ─ find the outer list [[...],[...],...] ──
    board = _extract_board(raw)

    result: dict = {"board": board, "status": status, "winner": winner}

    if include_col:
        col_m = re.match(r"result\((\d+),", raw)
        result["ai_col"] = int(col_m.group(1)) if col_m else None

    return result


def _extract_board(raw: str) -> list[list[str]]:
    """Extract the 6×7 board from a result(_, BOARD, _) Prolog term string."""
    # Find the board: starts after 'result(TAG,' — look for first '[['
    start = raw.find("[[")
    if start == -1:
        return [["empty"] * 7 for _ in range(6)]

    # Walk forward to find the matching closing ']]'
    depth = 0
    end = start
    for i in range(start, len(raw)):
        if raw[i] == "[":
            depth += 1
        elif raw[i] == "]":
            depth -= 1
            if depth == 0:
                end = i
                break

    board_str = raw[start:end + 1]  # e.g. "[[empty,x,...],[...],...]"

    board: list[list[str]] = []
    # Each row is a bracketed list inside the outer brackets
    for row_m in re.finditer(r"\[([^\[\]]+)\]", board_str):
        cells = [c.strip() for c in row_m.group(1).split(",")]
        board.append(cells)

    if not board:
        return [["empty"] * 7 for _ in range(6)]
    return board


# ── API models ────────────────────────────────────────────────────────────────

class MoveRequest(BaseModel):
    board: list[list[str]]
    col: int

class AIMoveRequest(BaseModel):
    board: list[list[str]]
    depth: int = 5


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def root():
    html_path = Path(__file__).parent / "index.html"
    return HTMLResponse(content=html_path.read_text(encoding="utf-8"))


@app.post("/api/player_move")
def player_move(req: MoveRequest):
    board_term = board_to_prolog(req.board)
    goal = (
        f"Board={board_term},Col={req.col},"
        f"(valid_move(Board,Col)"
        f"->make_move(Board,Col,x,NB),terminal_state(NB,S),"
        f"write_term(result(ok,NB,S),[quoted(true)]),nl"
        f";write_term(result(invalid,Board,continue),[quoted(true)]),nl)"
    )
    raw = run_prolog(goal)
    if not raw:
        raise HTTPException(500, detail="No output from Prolog. Check swipl installation.")
    return _parse_board_and_status(raw)


@app.post("/api/ai_move")
def ai_move(req: AIMoveRequest):
    board_term = board_to_prolog(req.board)
    depth = max(1, min(req.depth, 7))
    goal = (
        f"Board={board_term},"
        f"retractall(search_depth(_)),assert(search_depth({depth})),"
        f"minimax(Board,{depth},-1000000,1000000,o,Col,_Score),"
        f"make_move(Board,Col,o,NB),terminal_state(NB,S),"
        f"write_term(result(Col,NB,S),[quoted(true)]),nl"
    )
    raw = run_prolog(goal)
    if not raw:
        raise HTTPException(500, detail="No output from Prolog. Check swipl installation.")
    return _parse_board_and_status(raw, include_col=True)


# ── Startup check ─────────────────────────────────────────────────────────────

@app.on_event("startup")
def startup_check():
    print(f"[connect-four] Using swipl at: {SWIPL}")
    if not PROLOG_FILE.exists():
        print(f"[connect-four] WARNING: Prolog file not found at {PROLOG_FILE}")
