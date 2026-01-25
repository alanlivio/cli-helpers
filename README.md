# cli-helpers

`cli-helpers` is a library to organise your bash and powershell helper scripts. It loads scripts at `os/` given OS and load scripts at `programs/` if the given program exists. To use the library, you need setup the loading of [`init.sh`](init.sh) from your `.bashrc` and [`init.ps1`](init.ps1) from your `profile.ps1`. The diagram below overview the library behaviour.

**from bash:**

```mermaid
flowchart LR
    bashrc[".bashrc"]
    %% ps-init["init.ps1"]
    sh-init["init.sh"]
    program-dependent["
        programs/[program].bash
        ...
    "]
    OS-dependent["
        os/any.bash
        os/win.bash
        os/ubu.bash
        ...
    "]
    
    bashrc --> |"loads"| sh-init
    sh-init --> |"1: loads if running at OS"| OS-dependent
    sh-init --> |"2: loads if program installed"| program-dependent
    %% sh-init --> |"3: create bash alias functions at"| ps-init
```

**from powershell:**

```mermaid
flowchart LR
    psprofile["profile.ps1"]
    ps-init["init.ps1"]
    %% sh-init["init.sh"]
    program-dependent["
        programs/[program].ps1
        ...
    "]
    OS-dependent["
        os/any.ps1
        os/win.ps1
        os/ubu.ps1
        ...
    "]

    psprofile--> |"loads"| ps-init
    ps-init --> |"1: loads if running at OS"| OS-dependent
    ps-init --> |"2: loads if program installed"| program-dependent
    %%ps-init --> |"3: create ps1 alias to functions at"| sh-init
```

## Setup at your bash profile

You can use the Bash commands below to fetch, install, and setup `cli-helpers` to be loaded in your `.bashrc`:

```bash
git clone https://github.com/alanlivio/cli-helpers ~/cli-helpers
. ~/cli-helpers/setup_profile_loading.ps1
```

## Setup at your PowerShell profile

You can use the PowerShell commands below to fetch, install, and setup `cli-helpers` to be loaded in your `profile.ps1`:

```bash
git clone https://github.com/alanlivio/cli-helpers ${env:userprofile}\ps1-sh-helpers
. ~/cli-helpers/setup_profile_loading.sh
```

## References

This project takes inspiration from:

- <https://github.com/Bash-it/bash-it>
- <https://github.com/milianw/shell-helpers>
- <https://github.com/wd5gnr/bashrc>
- <https://github.com/martinburger/bash-common-helpers>
- <https://github.com/jonathantneal/git-bash-helpers>
- <https://github.com/donnemartin/dev-setup>
- <https://github.com/aspiers/shell-env>
- <https://github.com/nafigator/bash-helpers>
- <https://github.com/TiSiE/BASH.helpers>
- <https://github.com/midwire/bash.env>
- <https://github.com/e-picas/bash-library>
- <https://github.com/awesome-windows11/windows11>
- <https://github.com/99natmar99/Windows-11-Fixer>
- <https://github.com/W4RH4WK/Debloat-windows-10/tree/master/scripts>
