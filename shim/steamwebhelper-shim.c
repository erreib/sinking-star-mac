// steamwebhelper shim: Steam launches this in place of its CEF webhelper; it re-launches
// the real binary (renamed steamwebhelper_real.exe) with extra Chromium flags.
//
// Under Wine on macOS, CEF's out-of-process compositor can't paint into the browser
// window, so Steam's UI comes up as a black rectangle. Keeping everything in one
// process with software rendering fixes it (same approach as Arime9/steam-on-m1-wine).
//
// Build (from the repo root): x86_64-w64-mingw32-gcc -O2 -Wall -municode -mwindows -static -o bundle/steamwebhelper-shim.exe shim/steamwebhelper-shim.c
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <wchar.h>
#include <stdlib.h>

#define EXTRA_FLAGS L"--disable-gpu --single-process"
#define REAL_BINARY L"steamwebhelper_real.exe"

// Returns the part of the command line after argv[0], honoring quotes.
static const wchar_t *skip_argv0(const wchar_t *cmd)
{
    if (*cmd == L'"') {
        cmd++;
        while (*cmd && *cmd != L'"') cmd++;
        if (*cmd) cmd++;
    } else {
        while (*cmd && *cmd != L' ' && *cmd != L'\t') cmd++;
    }
    while (*cmd == L' ' || *cmd == L'\t') cmd++;
    return cmd;
}

int wmain(void)
{
    wchar_t self[MAX_PATH];
    DWORD len = GetModuleFileNameW(NULL, self, MAX_PATH);
    if (!len || len >= MAX_PATH) return 1;
    wchar_t *slash = wcsrchr(self, L'\\');
    if (!slash) return 1;
    slash[1] = 0;

    wchar_t real[MAX_PATH];
    if (wcslen(self) + wcslen(REAL_BINARY) >= MAX_PATH) return 1;
    wcscpy(real, self);
    wcscat(real, REAL_BINARY);

    const wchar_t *args = skip_argv0(GetCommandLineW());
    size_t n = wcslen(real) + wcslen(EXTRA_FLAGS) + wcslen(args) + 8;
    wchar_t *cmdline = malloc(n * sizeof(wchar_t));
    if (!cmdline) return 1;
    swprintf(cmdline, n, L"\"%ls\" %ls %ls", real, EXTRA_FLAGS, args);

    STARTUPINFOW si = {sizeof(si)};
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(real, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) return 1;

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)code;
}
