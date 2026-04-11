# 📋 System & stack audit

*Generated: 2026-04-11T21:14:06.129612+00:00*

## 📁 Audit paths

| Field            | Value                                |
| ---------------- | ------------------------------------ |
| Workspace root   | C:\Users\kbsbr\RoadmapAgent          |
| Output directory | C:\Users\kbsbr\RoadmapAgent\.sysinfo |
| Resolution       | marker-.git                          |

## 🖥 Operating system & hardware

| Field               | Value                                         |
| ------------------- | --------------------------------------------- |
| OS                  | Windows 11 10.0.26200 SP0 Multiprocessor Free |
| System              | Windows                                       |
| Kernel / build      | 10.0.26200                                    |
| Architecture        | x86_64 (64-bit)                               |
| Hostname            | MINIPC-9OB1Z                                  |
| CPU cores (logical) | 16                                            |
| RAM                 | 28.9 GiB                                      |
| Uptime              | 1d 21h 25m 38s                                |

## 🐍 Python environment

| Field                             | Value        |
| --------------------------------- | ------------ |
| Virtual env active                | False        |
| Kind hints                        | —            |
| VIRTUAL_ENV                       | —            |
| CONDA_PREFIX                      | —            |
| sys.prefix                        | C:\Python313 |
| Interpreter inside workspace venv | —            |

**Workspace venv candidates:**

| Relative path | Detection  |
| ------------- | ---------- |
| .rma/venv     | pyvenv.cfg |

**Example activate commands:**

| Shell        | Command                          |
| ------------ | -------------------------------- |
| unix bash    | source .rma/venv/bin/activate    |
| windows cmd  | .rma\venv\Scripts\activate.bat   |
| windows pwsh | .\.rma\venv\Scripts\Activate.ps1 |

**Recommendation:**

**No virtual environment is active** for this interpreter (global/system install).
Prefer a project venv so dependencies do not pollute the system Python.
Auto-detected venv at **`.rma/venv`**. Activate it, then re-run sysinfo:
- PowerShell: `.\.rma\venv\Scripts\Activate.ps1`
- cmd.exe: `.rma\venv\Scripts\activate.bat`

## 🐳 Environment & container hints

| Signal            | Value                                                |
| ----------------- | ---------------------------------------------------- |
| Summary           | No strong container signal (likely bare metal or VM) |
| GitHub Codespaces | False                                                |
| GitHub Actions    | False                                                |
| GitLab CI         | False                                                |
| Dev container     | False                                                |
| /.dockerenv       | False                                                |

## 🛠 Toolchain versions

| Tool                  | Detected | Version                                                          |
| --------------------- | -------- | ---------------------------------------------------------------- |
| bun                   | no       | —                                                                |
| cargo                 | no       | —                                                                |
| docker                | yes      | Docker version 29.3.1, build c2be9cc                             |
| docker_compose_plugin | yes      | Docker Compose version v5.1.1                                    |
| dotnet                | yes      | 8.0.419                                                          |
| git                   | yes      | git version 2.53.0.windows.1                                     |
| go                    | no       | —                                                                |
| gradle                | no       | —                                                                |
| java                  | yes      | java version "25.0.1" 2025-10-21 LTS                             |
| javac                 | yes      | javac 25.0.1                                                     |
| mongod                | no       | —                                                                |
| mvn                   | no       | —                                                                |
| mysql                 | no       | —                                                                |
| node                  | yes      | v25.9.0                                                          |
| npm                   | no       | —                                                                |
| php                   | no       | —                                                                |
| pip                   | yes      | pip 26.0.1 from C:\Python313\Lib\site-packages\pip (python 3.13) |
| pnpm                  | no       | —                                                                |
| podman                | no       | —                                                                |
| psql                  | yes      | psql (PostgreSQL) 17.0                                           |
| python                | yes      | Python 3.13.7                                                    |
| redis-cli             | no       | —                                                                |
| ruby                  | no       | —                                                                |
| rustc                 | no       | —                                                                |
| sqlite3               | no       | —                                                                |
| yarn                  | no       | —                                                                |

## 🔒 Lockfiles found

| File              | Path                                          |
| ----------------- | --------------------------------------------- |
| package-lock.json | C:\Users\kbsbr\RoadmapAgent\package-lock.json |

## Python requirements (notable lines)

| Package hint | Line          |
| ------------ | ------------- |
| pytest       | pytest>=7.4.0 |

## 🛣 Extra tools on PATH

| Tool      | Path                                                     |
| --------- | -------------------------------------------------------- |
| clang     | —                                                        |
| cmake     | —                                                        |
| curl      | C:\WINDOWS\system32\curl.EXE                             |
| gcc       | —                                                        |
| gh        | —                                                        |
| kubectl   | C:\Program Files\Docker\Docker\resources\bin\kubectl.EXE |
| make      | —                                                        |
| terraform | —                                                        |
| wget      | —                                                        |

---
*Audit script: sysinfo.py* — read-only; outputs under `.sysinfo/`.
