-- All on-disk state lives here: path construction, reads, writes, and the
-- one-time migration off v1's flat layout.
--
-- This module exists because v1 built save paths in two places that disagreed
-- -- Pet:get_save_path() wrote to `tamagotchi_<Name>.json` while the loader
-- defaulted to `tamagotchi.json` -- so nothing ever loaded. Path construction
-- is now one function with one test.
--
--   stdpath("data")/tamagotchi/
--     state.json          which pet was last active, migration markers
--     pets/<slug>.json    one file per pet
--     graveyard/          archived pets (see the `stakes` option)
local M = {}

local STATE_VERSION = 2

function M.root() return vim.fs.joinpath(vim.fn.stdpath("data"), "tamagotchi") end

function M.pets_dir() return vim.fs.joinpath(M.root(), "pets") end

function M.graveyard_dir() return vim.fs.joinpath(M.root(), "graveyard") end

function M.state_path() return vim.fs.joinpath(M.root(), "state.json") end

-- Pet names reach the filesystem, and v1 concatenated them in raw -- so
-- `set_name("../../../.bashrc")` was a path-traversal write. Reduce to a
-- filename-safe token and reject anything that could still escape.
function M.slug(name)
    assert(
        type(name) == "string" and #name > 0,
        "pet name must be a non-empty string"
    )

    local s = name:gsub("[^%w%-_]", "_")

    assert(
        s ~= "" and s ~= "." and s ~= "..",
        "pet name must contain a usable character"
    )
    assert(not s:find("%.%."), "pet name must not contain '..'")

    return s
end

function M.pet_path(name)
    return vim.fs.joinpath(M.pets_dir(), M.slug(name) .. ".json")
end

local function ensure_dir(path)
    if vim.fn.isdirectory(path) == 0 then vim.fn.mkdir(path, "p") end
end

local function read_json(path)
    if vim.fn.filereadable(path) == 0 then return nil end

    local lines = vim.fn.readfile(path)
    if not lines or #lines == 0 then return nil end

    local ok, data = pcall(vim.fn.json_decode, table.concat(lines, ""))
    if not ok or type(data) ~= "table" then return nil end

    return data
end

local function write_json(path, tbl)
    ensure_dir(vim.fn.fnamemodify(path, ":h"))

    local ok, encoded = pcall(vim.fn.json_encode, tbl)
    if not ok then
        vim.notify(
            "tamagotchi: could not encode " .. path .. ": " .. tostring(encoded),
            vim.log.levels.ERROR
        )
        return false
    end

    local failed = vim.fn.writefile({ encoded }, path)
    if failed ~= 0 then
        vim.notify("tamagotchi: could not write " .. path, vim.log.levels.ERROR)
        return false
    end

    return true
end

M._read_json = read_json
M._write_json = write_json

function M.read_state()
    return read_json(M.state_path()) or { schema_version = STATE_VERSION }
end

function M.write_state(state)
    state.schema_version = STATE_VERSION
    return write_json(M.state_path(), state)
end

-- Merge a few keys into state.json without clobbering the rest.
function M.update_state(patch)
    local state = M.read_state()
    for k, v in pairs(patch) do
        state[k] = v
    end
    return M.write_state(state)
end

function M.set_active_pet(name)
    return M.update_state({
        last_active_pet = name,
        last_active_at = os.time(),
    })
end

function M.save_pet(pet)
    if not pet or not pet.name then return false end

    pet.last_seen_time = os.time()

    if not write_json(M.pet_path(pet.name), pet:to_table()) then
        return false
    end

    return M.set_active_pet(pet.name)
end

-- Load a pet by name and bring it up to date. Returns nil when there is no save.
--
-- Decay is charged exactly once here, via the same apply_decay every other
-- caller uses -- v1 had a separate retroactive-decay implementation at load
-- time with its own cap and its own floor.
function M.load_pet(name)
    local Pet = require("tamagotchi.pet")

    local data = read_json(M.pet_path(name))
    if not data then return nil end

    local pet = Pet:new(Pet.migrate(data))
    pet:apply_decay()

    return pet
end

function M.delete_pet(name)
    local path = M.pet_path(name)
    if vim.fn.filereadable(path) == 1 then
        vim.fn.delete(path)
        return true
    end
    return false
end

-- Every pet with a save file, whether or not it is still in the user's config.
function M.list_saved_pets()
    local out = {}
    for _, path in ipairs(vim.fn.glob(M.pets_dir() .. "/*.json", false, true)) do
        out[#out + 1] = path
    end
    table.sort(out)
    return out
end

function M.clear_active_pet()
    local state = M.read_state()
    -- Not update_state({last_active_pet = nil}): nil in a table literal means
    -- the key is simply absent, so such a patch clears nothing.
    state.last_active_pet = nil
    state.last_active_at = nil
    return M.write_state(state)
end

function M.delete_all_pets()
    local count = 0
    for _, path in ipairs(M.list_saved_pets()) do
        vim.fn.delete(path)
        count = count + 1
    end
    M.clear_active_pet()
    return count
end

-- Archive a pet rather than deleting it, so a death is recoverable.
function M.archive_pet(pet)
    if not pet or not pet.name then return false end

    ensure_dir(M.graveyard_dir())
    local path = vim.fs.joinpath(
        M.graveyard_dir(),
        ("%s-%d.json"):format(M.slug(pet.name), os.time())
    )

    local ok = write_json(path, pet:to_table())
    if ok then M.delete_pet(pet.name) end
    return ok
end

-- Copy v1's flat `tamagotchi_<Name>.json` files into pets/, once.
--
-- Deliberately non-destructive: the originals are left in place so a user who
-- downgrades still has their data. Nothing here overwrites an existing v2 save.
local function legacy_paths()
    local data_dir = vim.fn.stdpath("data")

    local paths = vim.fn.glob(data_dir .. "/tamagotchi_*.json", false, true)

    local bare = vim.fs.joinpath(data_dir, "tamagotchi.json")
    if vim.fn.filereadable(bare) == 1 then paths[#paths + 1] = bare end

    return paths
end

-- Returns migrated (boolean), name, mtime -- nil name when the file is unusable.
local function migrate_one(path)
    local Pet = require("tamagotchi.pet")

    local data = read_json(path)
    if not data or type(data.name) ~= "string" or #data.name == 0 then
        return false, nil, nil
    end

    local ok, target = pcall(M.pet_path, data.name)
    if not ok then return false, nil, nil end

    local migrated = false
    if vim.fn.filereadable(target) == 0 then
        migrated = write_json(target, Pet.migrate(data))
    end

    -- v1 timestamps are monotonic and unorderable across boots, so the file's
    -- own mtime is the only trustworthy wall clock here.
    local stat = vim.uv.fs_stat(path)
    return migrated, data.name, stat and stat.mtime.sec or -1
end

function M.migrate_legacy()
    local state = M.read_state()
    if state.legacy_migrated then return 0 end

    local migrated, newest_name, newest_mtime = 0, nil, -1

    for _, path in ipairs(legacy_paths()) do
        local ok, name, mtime = migrate_one(path)
        if ok then migrated = migrated + 1 end
        if name and mtime > newest_mtime then
            newest_mtime, newest_name = mtime, name
        end
    end

    local patch = { legacy_migrated = true }
    if newest_name and not state.last_active_pet then
        patch.last_active_pet = newest_name
        patch.last_active_at = newest_mtime
    end
    M.update_state(patch)

    if migrated > 0 then
        vim.notify(
            ("tamagotchi: migrated %d save file(s) to %s"):format(
                migrated,
                M.pets_dir()
            ),
            vim.log.levels.INFO
        )
    end

    return migrated
end

-- Pick the pet to load at startup.
--
-- state.json wins over `default_pet` on purpose: `default_pet` means "which pet
-- do I start with", and a menu switch that does not survive a restart is not a
-- switch. Falls back to a fresh pet, then to a random one.
function M.resolve_startup_pet()
    local Pet = require("tamagotchi.pet")
    local config = require("tamagotchi.config").values

    local function def_for(name)
        if not name then return nil end
        for _, d in ipairs(config.pets or {}) do
            if d.name == name then return d end
        end
        return nil
    end

    local state = M.read_state()

    for _, name in ipairs({ state.last_active_pet, config.default_pet }) do
        if def_for(name) then
            local loaded = M.load_pet(name)
            if loaded then return loaded end
        end
    end

    local chosen = def_for(config.default_pet)

    if not chosen then
        assert(
            config.pets and #config.pets > 0,
            "No pets available in configuration"
        )
        math.randomseed(os.time())
        chosen = config.pets[math.random(#config.pets)]
    end

    return Pet.from_def(chosen)
end

return M
