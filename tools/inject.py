# inject.py <pid> <dll>: LoadLibraryW into a running process (UE4SS on the dedicated server, which never loads dwmapi.dll)
import ctypes, sys
from ctypes import wintypes as w
k = ctypes.WinDLL("kernel32", use_last_error=True)
k.OpenProcess.restype = w.HANDLE
k.VirtualAllocEx.restype = ctypes.c_void_p
k.VirtualAllocEx.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.c_size_t, w.DWORD, w.DWORD]
k.WriteProcessMemory.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
k.GetModuleHandleW.restype = w.HMODULE
k.GetProcAddress.restype = ctypes.c_void_p
k.GetProcAddress.argtypes = [w.HMODULE, ctypes.c_char_p]
k.CreateRemoteThread.restype = w.HANDLE
k.CreateRemoteThread.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_void_p, w.DWORD, ctypes.c_void_p]
pid, dll = int(sys.argv[1]), sys.argv[2]
h = k.OpenProcess(0x1F0FFF, False, pid)
buf = (dll + "\0").encode("utf-16-le")
mem = k.VirtualAllocEx(h, None, len(buf), 0x3000, 0x04)
k.WriteProcessMemory(h, mem, buf, len(buf), None)
lla = k.GetProcAddress(k.GetModuleHandleW("kernel32.dll"), b"LoadLibraryW")
t = k.CreateRemoteThread(h, None, 0, lla, mem, 0, None)
k.WaitForSingleObject(t, 20000)
code = w.DWORD(); k.GetExitCodeThread(t, ctypes.byref(code))
print("remote LoadLibraryW ->", hex(code.value), "err", ctypes.get_last_error())
