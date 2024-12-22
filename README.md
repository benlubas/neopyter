# Neopyter

The bridge between Neovim and Jupyter Lab. Edit in Neovim and preview/run in Jupyter Lab.

---

- [Neopyter](#Neopyter)
  - [How does it work?](#How-does-it-work)
  - [Screenshots](#Screenshots)
  - [Requirements](#Requirements)
  - [Installation](#Installation)
    - [JupyterLab Extension](#JupyterLab-Extension)
    - [Neovim Plugin](#Neovim-Plugin)
  - [Formats](#Formats)
  - [Usage](#Usage)
  - [Available Vim Commands](#Available-Vim-Commands)
  - [Integrations](#Integrations)
  - [API](#API)
  - [Acknowledgments](#Acknowledgments)

## How does it work?

This project includes two parts: a Jupyter Lab extension and a neovim plugin, you
will need to install both.

- The Jupyter Lab extension exposes functions of Jupyter Lab, and provides a remote
  procedure call (RPC) service
- The neovim plugin calls the RPC service when it receives events from neovim via
  auto command (`:h autocmd`)

This project provides two work modes for different network environments. If the
browser where your jupyter lab is located cannot directly access nvim, you must use
`proxy` mode. If you need to collaborate and use the same Jupyter with others, you
must use `direct` mode.

<table>
    <tr>
        <th></th>
        <th>direct</th>
        <th>proxy</th>
    </tr>
    <tr>
        <th>Architecture</th>
        <th style="text-align:center">
            <img alt="direct mode" width="500px" src="./doc/communication_direct.png" />
        </th>
        <th style="text-align:center">
            <img alt="proxy mode" width="500px" src="./doc/communication_proxy.png" />
        </th>
    </tr>
    <tr>
        <th>Advantage</th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Lower communication costs</li>
                <li>Shareable JupyterLab instance</li>
            </ul>
        </th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Lower Neovim load</li>
            </ul>
        </th>
    </tr>
    <tr>
        <th>Disadvantage</th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Higher Neovim load</li>
            </ul>
        </th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Exclusive JupyterLab instance</li>
            </ul>
        </th>
    </tr>
</table>

- `direct` mode: (default, recommended) In this mode, neovim is server and neovim
  plugin(neopyter) is listening to `remote_address`, the browser where jupyter lab is
  located will connect to neovim

- `proxy` mode: In this mode, Jupyter lab server (server side, the host you run
  `jupyter lab` to start JupyterLab) is server and jupyter lab server
  extension (neopyter) is listening to `${IP}:{Port}`, the neovim plugin (neopyter) will
  connect to `${IP}:{Port}`

Ultimately, `Neopyter` can control `Juppyter lab`. `Neopyter` can implement abilities
like [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim).

This plugin does **NOT** allow you to make changes in Jupyter and have them synced in
Neovim. Neovim is the driver, and the only source of truth.

## Screenshots

<table>
    <tr>
        <th></th>
        <th>Completion</th>
        <th>Cell Magic</th>
        <th>Line Magic</th>
    </tr>
    <tr>
        <th>
        </th>
        <th>
            <img alt="Completion" width="300px" src="./doc/completion.png" />
        </th>
        <th>
            <img alt="Cell Magic" width="300px" src="./doc/cell_magic.png" />
        </th>
        <th>
            <img alt="Line Magic" width="300px" src="./doc/line_magic.png" />
        </th>
    </tr>
</table>

## Requirements

- 📔JupyterLab >= 4.0.0
- Neovim v0.10.1+
  - `nvim-lua/plenary.nvim`
  - `AbaoFromCUG/websocket.nvim` (optional for `mode="direct"`)

## Installation

### JupyterLab Extension

To install the Jupyter Lab extension, execute:

```bash
pip install neopyter
```

#### Configure Neopyter in JL Side Panel

<img alt="Neopyter side panel" height="500px" src="./doc/sidepanel.png" />

- `mode`: Refer to the previous introduction about mode
- `IP`: If `mode=proxy`, set to the IP of the host where jupyter server is located.
  If `proxy=direct`, set to the IP of the host where neovim is located
- `Port`: Idle port of the `IP`'s' host

**NOTE:** all settings are saved to localStorage

### Neovim plugin

**Note:** You may have to clone the repository manually to approve the GitLab ssh
fingerprint. If you don't, it will appear that you don't have access to the repo.

<details>
  <summary>Lazy.nvim</summary>

```lua
{
    "SUSTech-data/neopyter",
    ---@type neopyter.Option
    opts = {
        -- ... config
    }
}
```

</details>

<details>
  <summary>Plug</summary>

```vim
Plug 'SUSTech-data/neopyter'

lua << EOF
require("neopyter").setup({
    -- ... config
})
EOF
```

</details>

#### Configure Neovim Plugin

```lua
{
    -- Leave this as 127.0.0.1 if neovim is running on the same machine as your
    -- jupyter kernel. Otherwise, point to the jupyter kernel. Port number needs
    -- to be the same as you set in Jupyter Lab's side panel. Doesn't matter
    -- what it is, long as it's the same
    remote_address = "127.0.0.1:9001",

    -- See ## Formats for more information about the values of this table.
    --
    -- table from file glob to parser name. Neopyter will automatically attach to
    -- any file that matches one of the globs below. globs are checked in order,
    -- first to match is used.
    file_patterns = {
        ["*.ju.*"] = "percent",
        ["*.qmd"] = "markdown",
        ["*.Rmd"] = "markdown",
        ["*.spin.R"] = "spin",
    },

    -- like `file_patterns`, but will not auto attach. Put globs that you sometimes
    -- want to treat like a notebook. In order to attach to one of these notebooks,
    -- run `:Neopyter sync`
    manual_file_patterns = {
        ["*.md"] = "markdown",
        ["*.r"] = "spin",
        ["*.py"] = "percent",
    },

    -- specify default kernels for each filetype. If there isn't a kernel specified
    -- in metadata, these patterns are tested in order, first to match is used.
    kernel_map = {
        ["*.py"] = "ipython",
    },

    -- Map buffer paths to their corresponding `.ipynb` path. This path is used
    -- by `:Neopyter sync open` and will open or create a file at this path to
    -- sync with
    open_filename_mapper = function(ju_path)
        local ipy_file = ju_path
        if ju_path:match("%.ju%.%w+$") then
            ipy_file = ju_path:gsub("%.ju%.%w+", ".ipynb")
        elseif ju_path:match("%.[qR]?md$") then
            ipy_file = ju_path:gsub("%.[qR]?md$", ".ipynb")
        elseif ju_path:match("%.spin%.R$") then
            ipy_file = ju_path:gsub("%.spin%.R$", ".ipynb")
        else
            ipy_file = ju_path:gsub("%.[^.]*$", ".ipynb")
        end
        return ipy_file
    end,

    -- automatically connect to jupyter lab after attaching to a buffer. There is
    -- very little if any reason to turn this off. Better to just configure
    -- `file_patters` and `manual_file_patterns` correctly.
    auto_connect = true,

    -- Given a plaintext file path, return a suitable temporary ipynb file path
    temp_path = function(ju_path)
        local p = ju_path:gsub("%.[^.]*$", "_NPTR_TEMP.ipynb")
        return p
    end,

    mode = "proxy",
    jupyter = {
        auto_activate_file = true,
        -- Always scroll to the current cell.
        scroll = {
            enable = true, -- attach autocommands to be able to scroll

            -- start with scrolling toggled on (change with `:Neopyter scroll
            -- enable/toggle/disable`)
            toggle = true,

            -- Given to Jupyter Lab to determine how it scrolls. Honestly, all
            -- of the options suck, just use auto
            align = "auto",
        },
        -- leave it off, don't risk overwriting notebooks. The notebooks Neopyter
        -- creates are not worth saving anyway. They're good for viewing and running,
        -- this is all.
        auto_save = false,
    },

    highlight = {
        -- this is not useful for markdown cells
        enable = false,
        -- Dim all cells except the current one
        shortsighted = true,
    },

    -- see ## integrations -> nvim-treesitter-textobjects
    -- these only apply to python percent style notebooks
    textobject = {
        enable = true,
    },

    parser = {
        line_magic = true, -- parse line magics in python percent style notebooks
        trim_whitespace = true, -- trim whitespace in percent style notebooks
        experimental_spin_metadata = false, -- parse cell metadata in spin notebooks
    },

    console = {
        -- Extra environment variables to pass to `jupyter console` command
        extra_env = "",
    },

    -- this function is called after neopyter attaches to a buffer. see bellow for
    -- recommended configuration
    on_attach = function(_buf) end,
}

```

#### Suggested Keymaps

_(there are no defaults)_

```lua
on_attach = function(buf)
    local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, ("<cmd>Neopyter execute %s<cr>"):format(rhs),
            { desc = desc, buffer = buf })
    end
    -- Note that you may have trouble mapping <c-enter> or meta+anything. You can use
    -- powertoys keyboard manager on windows to kinda hack around this if you must
    -- have <c-enter> as your run bind.
    map("n", "<leader><cr>", "notebook:run-cell",         "run selected")
    map("n", "<leader>X",    "notebook:run-all-above",    "run all above cell")
    map("n", "<F5>",         "kernelmenu:restart",        "restart kernel")

    -- You can execute any Jupyter Lab command in this way. For a list, refer to:
    -- https://jupyterlab.readthedocs.io/en/stable/user/commands.html#commands-list
end
```

## Formats

### Percent

<details>
  <summary>Example</summary>

```q
# ---
# jupyter:
#   kernelspec:
#     display_name: iPython
#     language: python
#     name: ipython
# ---
# %% [md]
# This is markdown cell. Cells are delimited by `# %%` where `#` is your
# commentstring. So for python the delimiter is `# %%`, for rust it would
# be `// %%`, etc. Delimiters that have `[md]` or `[markdown]` after them
# create markdown cells

# Let's create a code cell now \/

# %%

print("this is a code cell")

# You can have as much as you want in here
# Including regular code comments like this
def add(x, y):
    return x + y

add(4, 5)

# %%

# This is a new cell!
```
</details>

This is the same as the percent style notebooks from Jupytext. Comment string is read
from `:h 'commentstring'` so languages other than python are supported.

Unsupported:
- Markdown and cell magics for ipython
- Cell metadata
- File metadata beyond the kernel name

### Markdown

<details>
  <summary>Example</summary>

````markdown
---
jupyter:
  kernelspec:
    display_name: python3 (ipykernel)
    language: python
    name: python3
---

# markdown

Literally just a markdown document. Create code cells like normal:

```python
print("hi there")
```
````
</details>

This parser supports regular markdown, quarto markdown, and R markdown (and any other
flavor of markdown that the Markdown TS parser supports, as long as the captures for
fenced code blocks are the same).

Unsupported:
- Cell Metadata
- Document metadata beyond kernel name
- Quarto docs with more than one language type (JL can only associate one kernel with
each notebook)

### Spin

<details>
  <summary>Example</summary>

```r
#' ---
#' jupyter:
#'   kernelspec:
#'     display_name: R
#'     language: R
#'     name: ir
#' ---

#' ^ this blank line is required
#' This is a markdown comment
#' Still same cell

#' new markdown cell

# regular r comment
x = "and code in the same r cell"

y = "and this is still in that r code cell"

#+

"new code cell"
```
</details>

This notebook style is documented [here](https://bookdown.org/yihui/rmarkdown-cookbook/spin.html).

Unsupported:
- Block comments of any kind
- Document metadata beyond kernel name
- cell metadata is experimentally supported. You have to enable
`parsers.experimental_spin_metadata`

## Usage

- Make sure you've configured port on Jupyter Lab and neovim
- Launch Jupyter Lab: `jupyter lab --ip "0.0.0.0" ~`
  - You should launch in your home folder or higher, otherwise you might open a file
    in neovim that Jupyter Lab can't see
- Open your plaintext notebook in neovim
  - If it matches something in `file_patterns`, Neopyter will automatically open
  a temp file in jupyter lab
  - If it matches something in `manual_file_patterns`, you will be able to run
  `:Neopyter sync` to open a temp file in jupyter lab
- You can now start typing, and see the contents of the notebook synced to the file
  - Anything that you type is synced, this includes adding/removing cells, updating
  multiple cells at the same time, etc.
- Run code by sending a command like `:Neopyter run current`, or by setting up
keybinds in the `on_attach` function of your config as recommended in
[Suggested Keymaps](####Suggested-Keymaps)
- For example plaintext documents, see [formats](##Formats)

## Available Vim Commands

- Status
  - `:Neopyter status` alias to `:checkhealth neopyter` currently
- Server
  - `:Neopyter connect [remote 'ip:port']`, e.g. `:Neopyter connect 127.0.0.1:9001`,
    connect to Jupyter Lab manually
    - you will not need to run this most of the time
  - `:Neopyter disconnect`
- Sync
  - `:Neopyter sync temp` - Create a temporary ipynb file to sync with. The file is
    cleaned up when the neovim buffer is unloaded
    - Default (ie. `:Neopyter sync` is the same as `:Neopyter sync temp`)
  - `:Neopyter sync current` - sync the current file in nvim with the currently open
    `*.ipynb` in Jupyter Lab. **Warning:** This _will_ overwrite the ipynb file if
    you have the `auto_save` option enabled
  - `:Neopyter sync open` - Use `filename_mapper` to find a matching ipynb file to
    open and sync with
    - Requires setting a custom `filename_mapper` function
    - Will create the file if it doesn't exist
- Scroll
  - `:Neopyter scroll` - toggle scrolling in Jupyter on cursor move
  - `:Neopyter enable`
  - `:Neopyter disable`
- Run
  - `:Neopyter run current`, same as `Run`>`Run Selected Cell and Do not Advance`
    menu in Jupyter Lab
  - `:Neopyter run allAbove`, same as `Run`>`Run All Above Selected Cell` menu in
    Jupyter Lab
  - `:Neopyter run allBelow`, same as `Run`>`Run Selected Cell and All Below` menu in
    Jupyter Lab
  - `:Neopyter run all`, same as `Run`>`Run All Cells` menu in Jupyter Lab
- Kernel
  - `:Neopyter kernel restart`, same as `Kernel`>`Restart Kernel` menu in Jupyter lab
- `:Neopyter kernel restartRunAll`, same as `Kernel`>`Restart Kernel and Run All Cells`
  menu in Jupyter Lab
- Jupyter
  - `:Neopyter execute [command_id] [args]`, execute Jupyter Lab's
    [command](https://jupyterlab.readthedocs.io/en/stable/user/commands.html#commands-list)
    directly, e.g. `:Neopyter execute notebook:export-to-format {"format":"html"}`
- Console
  - `:Neopyter console [term|tmux] [h]`, launch a jupyter console connected to the
    same kernel as the notebook.
    - either tmux split or nvim terminal (default nvim term)
    - defaults to vertical split, pass `h` for horizontal split
    - **NOTE:** The q debugger doesn't run in jupyter console. If you need the
    debugger, unfortunately, you have to start a standalone q session.

## Integrations

<details>
  <summary>vim-slime</summary>

Vim slime is supported out of the box **iff you use tmux splits**. `:Neopyter console
tmux` will automatically set the necessary buffer variables to allow you to send code
to the tmux pane!

</details>

<details>
  <summary>vimcmdline</summary>

In order to send code to the console with vimcmdline, you have to write your own user
function to launch the kernel. This is b/c vimcmdline has to launch the console and
create the split itself.

This will work without `cmdline_in_buffer = 0`. This is just an example.

```lua
{
  "jalvesaq/vimcmdline",
  init = function()
    vim.g.cmdline_in_buffer = 0
    -- other normal vimcmdline config here

    vim.api.nvim_create_user_command("NeopyterConsole", function()
      require("neopyter").get_current_kernel_id(function(id)
        -- note, this function defaults to the current ft if ft!=quarto
        vim.cmd("let b:_QuartoFiletype = cmdline#QuartoLng()")
        local ft = vim.b._QuartoFiletype

        -- yes this will wipe all of your other config. If you have other ft config
        -- that you don't want wiped, you have to add it here. (make sure that it
        -- doesn't clobber -- the current filetype though, otherwise this user
        -- command will not work).
        vim.g.cmdline_app = {
          [ft] = ("jupyter console --existing %s"):format(id)
        }
        vim.cmd("call cmdline#StartApp()")
      end)
    end, {})
  end,
},
```

</details>


<details>
  <summary>neoconf.nvim</summary>

If [neoconf.nvim](https://github.com/SUSTech-data/neopyter) is available, `neopyter`
will automatically register/read `neoconf` settings

[`.neoconf.json`](./.neoconf.json)

```json
{
  "neopyter": {
    "mode": "proxy",
    "remote_address": "127.0.0.1:9001"
  }
}
```

</details>


<details>
  <summary>nvim-cmp</summary>
If you would like Jupyter Kernel completions, you can use this. Otherwise, you can
get python or R completions from their respective language servers. q users
don't have a language server despite their language being paid lol. So they should
consider using kernel completions.

If you do not use `nvim-cmp` as a completion engine, you can use
[`benlubas/cmp2lsp`](https://github.com/benlubas/cmp2lsp) to still get completions
from this plugin's cmp source.

```lua

local lspkind = require("lspkind")
local cmp = require("cmp")

cmp.setup({
    sources = cmp.config.sources({
        -- default: all source, maybe some noice
        { name = "neopyter" },
        -- only kernel source, like jupynium, support jupyterlab completer id:
        -- * "CompletionProvider:kernel"
        -- * "CompletionProvider:context"
        -- * "lsp" if jupyterlab-lsp is installed
        -- * ...
        -- { name = "neopyter", option={ completers = { "CompletionProvider:kernel" } } },
    }),
    -- these config options are only required for fancy icons in your cmp menu
    formatting = {
        format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
            menu = {
                neopyter = "[Neopyter]",
            },
            symbol_map = {
                -- specific complete item kind icon
                ["Magic"] = "🪄",
                ["Path"] = "📁",
                ["Dict key"] = "🔑",
                ["Instance"]="󱃻",
                ["Statement"]="󱇯",
            },
        }),
    },
)}

-- menu item highlight
vim.api.nvim_set_hl(0, "CmpItemKindMagic", { bg = "NONE", fg = "#D4D434" })
vim.api.nvim_set_hl(0, "CmpItemKindPath", { link = "CmpItemKindFolder" })
vim.api.nvim_set_hl(0, "CmpItemKindDictkey", { link = "CmpItemKindKeyword" })
vim.api.nvim_set_hl(0, "CmpItemKindInstance", { link = "CmpItemKindVariable" })
vim.api.nvim_set_hl(0, "CmpItemKindStatement", { link = "CmpItemKindVariable" })

```

More information, see [nvim-cmp wiki](https://github.com/hrsh7th/nvim-cmp/wiki/Menu-Appearance)

</details>

<details>
  <summary>nvim-treesitter-textobjects</summary>

Supported captures in `textobjects` query group

- `@cell`
  - `@cell.code`
  - `@cell.magic`
  - `@cell.markdown`
  - `@cell.raw`
  - `@cell.special`
- `@cellseparator`
  - `@cellseparator.code`
  - `@cellseparator.magic`
  - `@cellseparator.markdown`
  - `@cellseparator.raw`
  - `@cellseparator.special`
- `@cellbody`
  - `@cellbody.code`
  - `@cellbody.magic`
  - `@cellbody.markdown`
  - `@cellbody.raw`
  - `@cellbody.special`
- `@cellcontent`
  - `@cellcontent.code`
  - `@cellcontent.magic`
  - `@cellcontent.markdown`
  - `@cellcontent.raw`
  - `@cellcontent.special`
- `@cellborder`
  - `@cellborder.start`
    - `@cellborder.start.markdown`
    - `@cellborder.start.raw`
    - `@cellborder.start.special`
  - `@cellborder.end`
    - `@cellborder.end.markdown`
    - `@cellborder.end.raw`
    - `@cellborder.end.special`
- `@linemagic`

```lua
require('nvim-treesitter.configs').setup({
    textobjects = {
        move = {
            enable = true,
            goto_next_start = {
                ["]j"] = "@cellseparator",
                ["]c"] = "@cellcontent",
            },
            goto_previous_start = {
                ["[j"] = "@cellseparator",
                ["[c"] = "@cellcontent",
            },
        },
    },
})
```

</details>

## API

`Neopyter` provides rich lua APIs

- Jupyter Lab

  - `Neopyter execute ...` <-> `require("neopyter.jupyter").jupyterlab:execute_command(...)`
  - All APIs see `:=require("neopyter.jupyter.jupyterlab").__injected_methods`

- Notebook
  - `:Neopyter run current` <-> `require("neopyter.jupyter").notebook:run_selected_cell()`
  - `:Neopyter run allAbove` <-> `require("neopyter.jupyter").notebook:run_all_above()`
  - `:Neopyter run allBelow` <-> `require("neopyter.jupyter").notebook:run_all_below()`
  - All APIs see `:=require("neopyter.jupyter.notebook").__injected_methods`

## Acknowledgments

- [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim): Selenium-automated
  Jupyter Notebook that is synchronised with Neovim in real-time.

<!-- vim: set tw=85: -->
