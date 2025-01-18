local Pet = require("tamagotchi.pet")
local vim = vim
local assert = require("luassert")

describe("pet persistence", function()
    local test_filepath = vim.fn.stdpath("data") .. "/tamagotchi_test.json"
    local pet

    before_each(function()
        pet = Pet:new({ hunger = 70, happiness = 80 })
        -- ensure clean test file each time
        if vim.fn.filereadable(test_filepath) == 1 then
            vim.fn.delete(test_filepath)
        end
    end)

    after_each(function()
        -- clean up the test file if it exists
        if vim.fn.filereadable(test_filepath) == 1 then
            vim.fn.delete(test_filepath)
        end
    end)

    it("should save pet state to a file", function()
        pet:save(test_filepath)
        assert.is_true(vim.fn.filereadable(test_filepath) == 1)

        local lines = vim.fn.readfile(test_filepath)
        local content = table.concat(lines, "")
        local data = vim.fn.json_decode(content)
        assert.are.equal(70, data.hunger)
        assert.are.equal(80, data.happiness)
        assert.is_true(type(data.birth_time) == "number")
    end)

    it("should load pet state from a file", function()
        pet:save(test_filepath)
        local loaded_pet = Pet.load(test_filepath)
        assert.is_not_nil(loaded_pet)
        assert.are.equal(70, loaded_pet:get_hunger())
        assert.are.equal(80, loaded_pet:get_happiness())
        assert.are.equal(pet.birth_time, loaded_pet.birth_time)
    end)

    it("should return nil if no save file exists", function()
        local loaded_pet = Pet.load(test_filepath)
        assert.is_nil(loaded_pet)
    end)
end)
