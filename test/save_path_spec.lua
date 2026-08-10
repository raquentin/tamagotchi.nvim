local store = require("tamagotchi.store")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

-- v1 wrote to tamagotchi_<Name>.json and read from tamagotchi.json, so nothing
-- ever loaded. Path construction is one function now, and this is its test.
describe("store", function()
    before_each(function()
        config.setup()
        store.delete_all_pets()
        store.write_state({})
    end)

    describe("slug", function()
        it(
            "passes through a simple name",
            function() assert.are.equal("Sasha", store.slug("Sasha")) end
        )

        it(
            "replaces characters that are unsafe in a filename",
            function() assert.are.equal("my_pet_", store.slug("my pet!")) end
        )

        -- v1 concatenated the name straight into a path, so set_name could
        -- write anywhere on disk.
        it("neutralizes a path traversal attempt", function()
            local slug = store.slug("../../../.bashrc")
            assert.is_nil(slug:find("/", 1, true))
            assert.is_nil(slug:find("..", 1, true))
        end)

        it("keeps a traversal attempt inside the pets directory", function()
            local path = store.pet_path("../../../.bashrc")
            assert.are.equal(store.pets_dir(), vim.fn.fnamemodify(path, ":h"))
        end)

        it("rejects an empty name", function()
            assert.has_error(function() store.slug("") end)
        end)

        it("rejects a non-string", function()
            assert.has_error(function() store.slug(42) end)
        end)
    end)

    it("builds a save path under the pets directory", function()
        local path = store.pet_path("Sasha")
        assert.is_truthy(path:find("tamagotchi", 1, true))
        assert.is_truthy(path:find("Sasha.json", 1, true))
    end)

    -- The headline bug: v1 saved to tamagotchi_<Name>.json and loaded from
    -- tamagotchi.json, so a pet's state never survived a restart.
    it("round-trips a pet through save and load", function()
        local pet = Pet.from_def({ name = "Sasha" })
        pet:set_mood(42)
        pet:set_satiety(33)
        store.save_pet(pet)

        local loaded = store.load_pet("Sasha")
        assert.is_not_nil(loaded)
        -- load_pet charges decay for time elapsed since the save.
        assert.is_true(math.abs(loaded:get_mood() - 42) < 1)
        assert.is_true(math.abs(loaded:get_satiety() - 33) < 1)
    end)

    it(
        "returns nil when there is no save",
        function() assert.is_nil(store.load_pet("Dragon")) end
    )

    -- v1 serialized the entire sprite table into every save.
    it("does not persist sprites or vim_events", function()
        local pet = Pet.from_def({ name = "Sasha" })
        local saved = pet:to_table()
        assert.is_nil(saved.sprites)
        assert.is_nil(saved.vim_events)
        assert.is_nil(saved.session_start_time)
    end)

    describe("state pointer", function()
        it("records the last active pet on save", function()
            store.save_pet(Pet.from_def({ name = "Lucy" }))
            assert.are.equal("Lucy", store.read_state().last_active_pet)
        end)

        it("merges into state rather than replacing it", function()
            store.update_state({ legacy_migrated = true })
            store.set_active_pet("Lucy")

            local state = store.read_state()
            assert.is_true(state.legacy_migrated)
            assert.are.equal("Lucy", state.last_active_pet)
        end)
    end)

    describe("resolve_startup_pet", function()
        it(
            "falls back to default_pet when nothing is saved",
            function()
                assert.are.equal("Sasha", store.resolve_startup_pet().name)
            end
        )

        -- The whole point of the pointer file: a menu switch has to survive a
        -- restart, or it is not a switch.
        it("prefers the last active pet over default_pet", function()
            local lucy = Pet.from_def({ name = "Lucy" })
            lucy:set_mood(21)
            store.save_pet(lucy)

            local resolved = store.resolve_startup_pet()
            assert.are.equal("Lucy", resolved.name)
            assert.are.equal(21, resolved:get_mood())
        end)

        it("ignores a pointer at a pet that is no longer configured", function()
            store.update_state({ last_active_pet = "NotARealPet" })
            assert.are.equal("Sasha", store.resolve_startup_pet().name)
        end)
    end)

    describe("delete_all_pets", function()
        it("removes every save and clears the pointer", function()
            store.save_pet(Pet.from_def({ name = "Sasha" }))
            store.save_pet(Pet.from_def({ name = "Lucy" }))
            assert.are.equal(2, #store.list_saved_pets())

            assert.are.equal(2, store.delete_all_pets())
            assert.are.equal(0, #store.list_saved_pets())
            assert.is_nil(store.read_state().last_active_pet)
        end)
    end)

    describe("legacy migration", function()
        local legacy_path

        before_each(function()
            legacy_path = vim.fs.joinpath(
                vim.fn.stdpath("data"),
                "tamagotchi_Dragon.json"
            )
            vim.fn.writefile({
                vim.fn.json_encode({
                    name = "Dragon",
                    mood = 55,
                    satiety = 44,
                    birth_time = 1000,
                    last_vim_close_time = 61000,
                }),
            }, legacy_path)
        end)

        after_each(function() vim.fn.delete(legacy_path) end)

        it("copies a v1 file into the pets directory", function()
            assert.are.equal(1, store.migrate_legacy())

            local loaded = store.load_pet("Dragon")
            assert.is_not_nil(loaded)
            -- load_pet charges decay for time elapsed since the save, so this
            -- lands just under the migrated 55 rather than exactly on it.
            assert.is_true(math.abs(loaded:get_mood() - 55) < 1)
        end)

        -- Deleting a user's save during an upgrade is not recoverable.
        it("leaves the original file in place", function()
            store.migrate_legacy()
            assert.are.equal(1, vim.fn.filereadable(legacy_path))
        end)

        it("only runs once", function()
            assert.are.equal(1, store.migrate_legacy())
            assert.are.equal(0, store.migrate_legacy())
        end)

        it("does not overwrite an existing v2 save", function()
            local dragon = Pet.from_def({ name = "Dragon" })
            dragon:set_mood(99)
            store.save_pet(dragon)

            store.migrate_legacy()

            -- Loading charges decay for the elapsed second or two, so compare
            -- against the v2 value rather than the legacy file's 55.
            assert.is_true(store.load_pet("Dragon"):get_mood() > 90)
        end)
    end)
end)
