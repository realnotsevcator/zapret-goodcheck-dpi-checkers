#!/usr/bin/env python3
"""Interactive runner for zapret GoodCheck strategies.

This script is a Python rewrite of the original ``GoodCheck.cmd`` batch file.
It keeps the user-facing workflow intact while improving robustness and
readability.  The runner asks the user for the path to ``winws.exe`` and to a
strategy list, starts *winws* with every strategy, executes the built-in HTTP
checks with ``curl.exe`` and prints human readable results.

The implementation deliberately mirrors the behaviour of the original script:

* strategy files may contain ``_strategyExtraKeys`` and
  ``_strategyCurlExtraKeys`` directives;
* the predefined list of HTTP checks and thresholds is preserved;
* a random query parameter is attached to every request to prevent caching;
* pass results are aggregated per strategy and summarised at the end.

Running on Windows is required for real checks because both ``winws.exe`` and
``curl.exe`` are Windows binaries.  The code, however, keeps the logic
platform-agnostic so that it can be linted and tested on other systems.
"""

from __future__ import annotations

import os
import platform
import random
import shlex
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import List, Sequence, Tuple

# ---------------------------------------------------------------------------
# Configuration constants that mirror GoodCheck.cmd defaults
# ---------------------------------------------------------------------------

TCP_TIMEOUT_MS = 5000
OK_THRESHOLD_BYTES = 65536
CURL_MIN_TIMEOUT = 2
FAKE_SNI = "www.google.com"
FAKE_HEX_RAW = (
    "1603030135010001310303424143facf5c983ac8ff20b819cfd634cbf5143c0005b2b8b142a6cd3"
    "35012c220008969b6b387683dedb4114d466ca90be3212b2bde0c4f56261a9801"
)
FAKE_HEX_BYTES = ""
NETWORK_TEST_URL = "https://ya.ru"


# The list of HTTP checks is copied verbatim from ConfigureTests in
# GoodCheck.cmd.  Each entry is (test id, provider, url, repetitions).
TEST_CASES: Tuple[Tuple[str, str, str, int], ...] = (
    ("CF-01", "Cloudflare", "https://speed.cloudflare.com/__down?bytes=65536", 1),
    ("CF-02", "Cloudflare", "https://www.cloudflare.com/cdn-cgi/trace", 1),
    ("HZ-01", "Hetzner", "https://mirror.hetzner.com/100MB.bin", 1),
    ("OVH-01", "OVH", "https://proof.ovh.net/files/1Mb.dat", 1),
    ("OVH-02", "OVH", "https://ovh.sfx.ovh/10M.bin", 1),
    ("OR-01", "Oracle", "https://oracle.sfx.ovh/10M.bin", 1),
    ("AWS-01", "AWS", "https://tms.delta.com/delta/dl_anderson/Bootstrap.js", 1),
    (
        "AWS-02",
        "AWS",
        "https://corp.kaltura.com/wp-content/cache/min/1/"
        "wp-content/themes/airfleet/dist/styles/theme.css",
        1,
    ),
    (
        "FST-01",
        "Fastly",
        "https://www.juniper.net/content/dam/www/assets/images/diy/DIY_th.jpg"
        "/jcr:content/renditions/600x600.jpeg",
        1,
    ),
    (
        "FST-02",
        "Fastly",
        "https://www.graco.com/etc.clientlibs/clientlib-site/resources/fonts/lato"
        "/Lato-Regular.woff2",
        1,
    ),
    ("AKM-01", "Akamai", "https://www.lg.com/lg5-common-gp/library/jquery.min.js", 1),
    (
        "AKM-02",
        "Akamai",
        "https://media-assets.stryker.com/is/image/stryker/gateway_1?$max_width_1410$",
        1,
    ),
)


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------


@dataclass
class Strategy:
    """A single Zapret strategy command line."""

    index: int
    text: str

    def split_arguments(self) -> List[str]:
        """Split the strategy command line into arguments.

        ``shlex.split`` with ``posix=False`` mimics the way cmd.exe splits
        command lines while respecting quoted strings.
        """

        text = self.text.strip()
        if not text:
            return []
        return shlex.split(text, posix=False)


@dataclass
class CurlResult:
    """Parsed outcome of a single curl execution."""

    status: str
    status_text: str
    bytes_downloaded: int
    http_code: str
    remote_ip: str
    error_message: str


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------


def prompt_path(prompt: str, must_exist: bool = True) -> Path:
    """Prompt the user for a filesystem path."""

    while True:
        raw = input(prompt).strip().strip('"')
        if not raw:
            print("Путь не может быть пустым. Повторите ввод.")
            continue
        path = Path(raw).expanduser()
        if must_exist and not path.exists():
            print(f"Файл или каталог не найден: {path}")
            continue
        return path


def prompt_passes() -> int:
    """Ask the user how many passes should be executed (1-9)."""

    while True:
        raw = input("Количество прогонов (1-9, по умолчанию 1): ").strip()
        if not raw:
            return 1
        if not raw.isdigit():
            print("Введите число от 1 до 9.")
            continue
        value = int(raw)
        if 1 <= value <= 9:
            return value
        print("Введите число от 1 до 9.")


def split_arguments(command_line: str) -> List[str]:
    """Split command line arguments respecting Windows quoting rules."""

    command_line = command_line.strip()
    if not command_line:
        return []
    return shlex.split(command_line, posix=False)


def load_strategies(path: Path) -> Tuple[List[Strategy], List[str]]:
    """Read strategy definitions from ``path``.

    Returns a list of :class:`Strategy` objects and additional curl arguments
    specified via ``_strategyCurlExtraKeys``.  The loader now also understands
    optional ``_strategyPort80`` and ``_strategyPort443`` directives that make
    it possible to combine HTTP and HTTPS parameters into a single winws
    invocation.
    """

    strategy_extra = ""
    strategy_curl_extra = ""
    raw_entries: List[str] = []
    port80_entries: List[str] = []
    port443_entries: List[str] = []

    base_dir = path.parent.resolve()
    replacements = {
        "FAKESNI": FAKE_SNI,
        "FAKEHEX": FAKE_HEX_RAW,
        "FAKEHEXBYTES": FAKE_HEX_BYTES,
        "%LISTDIR%": os.environ.get("LISTDIR", str(base_dir)),
        "%BIN%": os.environ.get("BIN", str(base_dir)),
    }

    def apply_replacements(text: str) -> str:
        for key, replacement in replacements.items():
            if replacement:
                text = text.replace(key, replacement)
        return text.strip()

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped or stripped.startswith("/"):
                continue
            directive, sep, value = stripped.partition("#")
            lower_directive = directive.lower()
            if sep and lower_directive == "_strategyextrakeys":
                strategy_extra = value.strip()
                continue
            if sep and lower_directive == "_strategycurlextrakeys":
                strategy_curl_extra = value.strip()
                continue
            if sep and lower_directive == "_strategyport80":
                port80_entries.append(apply_replacements(value))
                continue
            if sep and lower_directive == "_strategyport443":
                port443_entries.append(apply_replacements(value))
                continue

            raw_entries.append(apply_replacements(stripped))

    strategies: List[Strategy] = []
    if port443_entries and raw_entries:
        combined_entries = raw_entries + port443_entries
    elif port443_entries:
        combined_entries = port443_entries.copy()
    else:
        combined_entries = raw_entries.copy()

    if port80_entries:
        if not combined_entries:
            raise ValueError(
                "Для объединённых стратегий требуется хотя бы одна запись для порта 443."
            )

        index = 1
        base_prefix = strategy_extra.strip()
        for port80 in port80_entries:
            port80 = port80.strip()
            for port443 in combined_entries:
                port443 = port443.strip()
                parts: List[str] = []
                if base_prefix:
                    parts.append(base_prefix)
                parts.append("--wf-tcp=80,443")
                port80_segment = f"--filter-tcp=80 {port80}".strip()
                port443_segment = f"--filter-tcp=443 {port443}".strip()
                parts.append(port80_segment)
                parts.append("--new")
                parts.append(port443_segment)
                text = " ".join(parts)
                if "--filter-tcp=80" not in text or "--filter-tcp=443" not in text:
                    raise ValueError(
                        "Объединённая стратегия должна содержать параметры для портов 80 и 443."
                    )
                strategies.append(Strategy(index=index, text=" ".join(text.split())))
                index += 1
    else:
        index = 1
        for entry in raw_entries + port443_entries:
            command = " ".join(part for part in (strategy_extra, entry) if part).strip()
            if command:
                strategies.append(Strategy(index=index, text=" ".join(command.split())))
                index += 1

    if not strategies:
        raise ValueError("Файл стратегий не содержит данных.")

    curl_args = split_arguments(strategy_curl_extra)
    return strategies, curl_args


def find_curl_executable(root: Path) -> Path:
    """Locate curl.exe similarly to the batch script."""

    arch_dir = "x86"
    machine = platform.machine().lower()
    if machine in {"amd64", "x86_64", "arm64"}:
        arch_dir = "x86_64"

    candidates = [
        root / "Curl" / arch_dir / "curl.exe",
        root / "Curl" / "curl.exe",
        root / "curl.exe",
    ]

    if platform.system() == "Windows":
        system_root = Path(os.environ.get("SystemRoot", r"C:\Windows"))
        candidates.extend(
            [
                system_root / "System32" / "curl.exe",
                system_root / "SysWOW64" / "curl.exe",
            ]
        )
        where = system_root / "System32" / "where.exe"
        if where.exists():
            try:
                result = subprocess.run(
                    [str(where), "curl.exe"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                for line in result.stdout.splitlines():
                    line = line.strip()
                    if line:
                        candidates.append(Path(line))
            except OSError:
                pass

    for candidate in candidates:
        if candidate.exists():
            return candidate

    raise FileNotFoundError("curl.exe не найден. Убедитесь, что он присутствует в каталоге Curl или доступен в PATH.")


def append_cache_buster(url: str) -> str:
    """Append a random query parameter to the URL to prevent caching."""

    suffix = f"t={random.randint(100000, 999999)}{random.randint(100000, 999999)}"
    separator = "&" if "?" in url else "?"
    return f"{url}{separator}{suffix}"


def run_curl(
    curl_path: Path,
    extra_args: Sequence[str],
    url: str,
    timeout_sec: int,
) -> CurlResult:
    """Execute curl and convert its output into :class:`CurlResult`."""

    write_out = "HTTP_CODE=%{http_code};SIZE=%{size_download};IP=%{remote_ip};ERR=%{errormsg}"
    command = [
        str(curl_path),
        *extra_args,
        "--silent",
        "--show-error",
        "--no-progress-meter",
        "--max-time",
        str(timeout_sec),
        "--connect-timeout",
        str(timeout_sec),
        "--range",
        "0-65535",
        "--output",
        os.devnull,
        "--write-out",
        write_out,
        url,
    ]

    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as exc:
        raise RuntimeError(f"Не удалось запустить curl: {exc}") from exc

    combined_output = "\n".join(
        part.strip() for part in (completed.stdout, completed.stderr) if part
    )
    curl_meta = None
    curl_error = None
    for line in combined_output.splitlines():
        line = line.strip()
        if not line:
            continue
        if "HTTP_CODE=" in line:
            curl_meta = line
        elif curl_error is None:
            curl_error = line

    http_code = "000"
    download_size = "0"
    remote_ip = "unknown"
    error_message = ""

    if curl_meta:
        for chunk in curl_meta.split(";"):
            key, _, value = chunk.partition("=")
            key = key.strip().upper()
            if key == "HTTP_CODE":
                http_code = value.strip() or "000"
            elif key == "SIZE":
                download_size = value.strip() or "0"
            elif key == "IP":
                remote_ip = value.strip() or "unknown"
            elif key == "ERR":
                error_message = value.strip()

    if not error_message and curl_error:
        error_message = curl_error

    try:
        bytes_downloaded = int(download_size.split(".")[0])
    except ValueError:
        bytes_downloaded = 0

    status = "FAIL"
    status_text = "Failed to complete"

    if completed.returncode == 0:
        if bytes_downloaded >= OK_THRESHOLD_BYTES:
            status = "OK"
            status_text = "Not detected"
        else:
            status = "WARN"
            status_text = "Possibly detected"
    elif completed.returncode == 28:
        status = "DETECTED"
        if http_code == "000":
            status_text = "Detected (timeout without HTTP)"
        else:
            status_text = "Detected"
    else:
        if not error_message:
            error_message = f"exit {completed.returncode}"

    if not error_message:
        error_message = "none"

    return CurlResult(
        status=status,
        status_text=status_text,
        bytes_downloaded=bytes_downloaded,
        http_code=http_code,
        remote_ip=remote_ip,
        error_message=error_message,
    )



def run_test_suite(
    curl_path: Path,
    curl_extra_args: Sequence[str],
    timeout_sec: int,
) -> Tuple[int, str]:
    """Execute all HTTP checks once and return (ok_count, summary_text)."""

    tasks: List[Tuple[int, int, int, str, str, str]] = []
    total_tasks = 0
    for order, (test_id, provider, url, times) in enumerate(TEST_CASES):
        repeats = max(times, 1)
        total_tasks += repeats
        for attempt in range(1, repeats + 1):
            tasks.append((order, attempt, repeats, test_id, provider, url))

    if total_tasks == 0:
        return 0, "OK:0, Warn:0, Detected:0, Fail:0"

    ok = warn = detected = fail = 0
    results: List[Tuple[int, int, int, str, str, CurlResult]] = []

    max_workers = max(1, min(8, total_tasks))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [
            executor.submit(
                run_curl,
                curl_path,
                curl_extra_args,
                append_cache_buster(url),
                timeout_sec,
            )
            for _, _, _, _, _, url in tasks
        ]

        for (order, attempt, repeats, test_id, provider, _), future in zip(tasks, futures):
            result = future.result()
            results.append((order, attempt, repeats, test_id, provider, result))

    results.sort(key=lambda item: (item[0], item[1]))

    for _, attempt, repeats, test_id, provider, result in results:
        if result.status.upper() == "OK":
            ok += 1
        elif result.status.upper() == "WARN":
            warn += 1
        elif result.status.upper() == "DETECTED":
            detected += 1
        else:
            fail += 1

        print(
            f"Тест {test_id} ({provider}) #{attempt}/{repeats} - {result.status_text} "
            f"(HTTP {result.http_code}, bytes {result.bytes_downloaded}, "
            f"IP {result.remote_ip}, error {result.error_message})"
        )

    summary = f"OK:{ok}, Warn:{warn}, Detected:{detected}, Fail:{fail}"
    return ok, summary

def start_winws(executable: Path, strategy: Strategy) -> subprocess.Popen:
    """Start winws.exe with the provided strategy."""

    arguments = [str(executable), *strategy.split_arguments()]
    creationflags = 0
    if platform.system() == "Windows":
        # Launch winws.exe in a separate console window to mirror the
        # behaviour of the original batch script.
        creationflags = getattr(subprocess, "CREATE_NEW_CONSOLE", 0)

    try:
        return subprocess.Popen(arguments, creationflags=creationflags)
    except OSError as exc:
        raise RuntimeError(f"Не удалось запустить {executable.name}: {exc}") from exc


def terminate_winws(process: subprocess.Popen | None, executable: Path) -> None:
    """Terminate the winws process and attempt to kill remaining instances."""

    is_windows = platform.system() == "Windows"
    if is_windows:
        exe_name = executable.name
        try:
            subprocess.run(
                ["taskkill", "/F", "/T", "/IM", exe_name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        except OSError:
            pass

    if process is not None and process.poll() is None:
        if is_windows:
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
        else:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()

    if is_windows:
        try:
            subprocess.run(
                ["sc", "stop", "windivert"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        except OSError:
            pass



def check_network(curl_path: Path, curl_extra_args: List[str]) -> None:
    """Replicate the pre-flight network check from GoodCheck.cmd."""

    base_command = [
        str(curl_path),
        *curl_extra_args,
        "--silent",
        "--show-error",
        "--max-time",
        str(CURL_MIN_TIMEOUT),
        "--output",
        os.devnull,
        NETWORK_TEST_URL,
    ]

    result = subprocess.run(base_command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode == 0:
        return

    print("Предупреждение: HTTPS проверка не удалась, повторная попытка с --insecure.")
    insecure_command = base_command.copy()
    insecure_command.insert(1 + len(curl_extra_args), "--insecure")
    result = subprocess.run(
        insecure_command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        print(
            "Предупреждение: сетевой тест не пройден. Проверки могут завершиться "
            "со статусом DETECTED/FAIL до устранения проблем с подключением."
        )
    elif "--insecure" not in curl_extra_args:
        curl_extra_args.append("--insecure")


def summarise_results(results: List[Tuple[int, Strategy, str]], total_checks: int) -> None:
    """Print a grouped summary mirroring the batch script output."""

    if not results:
        return

    print("\nСводка по количеству успешных тестов:")
    for successes in range(total_checks + 1):
        matching = [
            f"{item[1].text} ({item[2]})"
            for item in results
            if item[0] == successes
        ]
        if matching:
            joined = " ".join(matching)
            print(f"{successes} успехов - Стратегии: {joined}")


def main() -> int:
    print("==============================")
    print("GoodCheck Python")
    print("==============================")

    root = Path(__file__).resolve().parent

    winws_path = prompt_path("Введите путь до winws.exe: ")
    strategy_path = prompt_path("Введите путь до файла стратегий (.txt): ")

    try:
        strategies, strategy_curl_extra = load_strategies(strategy_path)
    except Exception as exc:  # pragma: no cover - interactive error path
        print(f"Ошибка при чтении стратегий: {exc}")
        return 1

    try:
        curl_path = find_curl_executable(root)
    except FileNotFoundError as exc:
        print(exc)
        return 1

    curl_extra_args = strategy_curl_extra.copy()
    timeout_sec = max(1, (TCP_TIMEOUT_MS + 999) // 1000)

    check_network(curl_path, curl_extra_args)

    passes = prompt_passes()
    total_checks = sum(max(item[3], 1) for item in TEST_CASES)

    print(f"Загружено стратегий: {len(strategies)}")
    print(f"Будет выполнено {total_checks} HTTP-проверок на каждый прогон.")

    results: List[Tuple[int, Strategy, str]] = []
    most_successful = -1

    for strategy in strategies:
        print("\n----------------------------------------")
        print(
            f"Стратегия {strategy.index}/{len(strategies)}: {strategy.text}"
        )
        process: subprocess.Popen | None = None
        try:
            process = start_winws(winws_path, strategy)
            time.sleep(1)
        except Exception as exc:
            print(f"Не удалось запустить winws.exe: {exc}")
            terminate_winws(process, winws_path)
            continue

        best_score = -1
        best_summary = "Нет данных"

        try:
            for current_pass in range(1, passes + 1):
                print(f"\nПрогон {current_pass} из {passes}")
                pass_score, summary = run_test_suite(
                    curl_path=curl_path,
                    curl_extra_args=curl_extra_args,
                    timeout_sec=timeout_sec,
                )
                print(
                    f"Результат прогона: {pass_score}/{total_checks} ({summary})"
                )
                if best_score < 0 or pass_score < best_score:
                    best_score = pass_score
                    best_summary = summary
        finally:
            terminate_winws(process, winws_path)

        if best_score >= 0:
            results.append((best_score, strategy, best_summary))
            if best_score > most_successful:
                most_successful = best_score

    summarise_results(results, total_checks)

    if most_successful >= 0:
        top_strategies = [
            item for item in results if item[0] == most_successful
        ]
        print("\nЛучшие стратегии (по числу успехов):")
        for _, strategy, summary in top_strategies:
            print(f"* {strategy.text} -> {summary}")

    print("\nГотово.")
    return 0


if __name__ == "__main__":  # pragma: no cover - script entry point
    sys.exit(main())

