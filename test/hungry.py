# live follow-up after botrows.py: rested+fed crew joins with no gift, then a hungry follower goes to bed, then declines "hungry"
import time, pathlib
R = pathlib.Path("C:/re/abioticfactor")
def fc(c, w): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
fc("botgift 0", 2); fc("needs 100 100", 2)
for _ in range(4): fc("botcrew", 5)
fc("status", 2); fc("needs 80 10", 12); fc("status", 2)
for _ in range(3): fc("botcrew", 5)
fc("status", 2)
print("\n".join((R / "faircrew_log.txt").read_text(errors="replace").splitlines()[-25:]))
