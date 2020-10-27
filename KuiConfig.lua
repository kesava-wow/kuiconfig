-- kesava-wow @ github
-- all rights reserved
local MAJOR, MINOR = 'KuiConfig-1.1', 1
local kc = LibStub:NewLibrary(MAJOR, MINOR)
if not kc then return end
local config_meta = {}
config_meta.__index = config_meta
-- library functions ##########################################################
-- entry point; initialise saved variables, return KuiConfig table
function kc:Initialise(var_prefix,defaults)
    assert(var_prefix)
    assert(type(defaults) == 'table')

    local config_tbl = {}
    setmetatable(config_tbl, config_meta)
    config_tbl.defaults = defaults

    local gsv_name = var_prefix..'Saved'
    if not _G[gsv_name] then _G[gsv_name] = {} end
    config_tbl.gsv_name = gsv_name

    local csv_name = var_prefix..'CharacterSaved'
    if not _G[csv_name] then _G[csv_name] = {} end
    config_tbl.csv_name = csv_name

    local gsv = config_tbl:GSV()
    if not gsv.profiles then
        gsv.profiles = {}
    end

    local csv = config_tbl:CSV()
    if not csv.profile then
        csv.profile = 'default'
    end

    if not config_tbl:ProfileExists(csv.profile) then
        config_tbl:CreateProfile(csv.profile)
    end

    return config_tbl
end
-- call callbacks of listeners for given config table [config]
local function CallListeners(config,...)
    if type(config.listeners) == 'table' then
        for _,listener in ipairs(config.listeners) do
            if type(listener) == 'function' then
                listener(config,...)
            else
                local parent,key = unpack(listener)
                parent[key](parent,config,...)
            end
        end
    end
end
-- config table prototype ######################################################
-- add config changed listener:
-- arg1 = table / function
-- arg2 = key of function in table [arg1]
function config_meta:RegisterConfigChanged(arg1,arg2)
    if not self.listeners then self.listeners = {} end
    if type(arg1) == 'function' then
        tinsert(self.listeners,arg1)
    else
        assert(type(arg1) == 'table')
        assert(type(arg2) == 'string')
        assert(type(arg1[arg2]) == 'function')
        tinsert(self.listeners,{arg1,arg2})
    end
end
-- global aliases
function config_meta:GSV() return _G[self.gsv_name] end
function config_meta:CSV() return _G[self.csv_name] end
-- key shortcuts ##############################################################
-- set config key [k] to value [v] and update
function config_meta:SetKey(k,v)
    self:Profile()[k] = v
    CallListeners(self,k,v)
end
-- return config key [k]
function config_meta:GetKey(k)
    local p = self:Profile()[k]
    if p ~= nil then
        return p
    else
        return self.defaults[k]
    end
end
-- reset config key [k]
function config_meta:ResetKey(k)
    self:SetKey(k,nil)
end
-- profile functions ##########################################################
function config_meta:ProfileExists(name)
    return type(self:GSV().profiles[name]) == 'table'
end
function config_meta:CreateProfile(name)
    if self:ProfileExists(name) then return end
    self:GSV().profiles[name] = {}
    return self:GSV().profiles[name]
end
-- switch to given extant profile
function config_meta:SetProfile(name)
    assert(self:ProfileExists(name))

    -- remember profile for this character
    self:CSV().profile = name

    -- inform listeners of profile change / run callbacks
    CallListeners(self)
end
-- return named profile table
function config_meta:GetProfile(name)
    return self:GSV().profiles[name]
end
-- return active profile table (or nothing)
function config_meta:Profile()
    return self:GetProfile(self:CSV().profile)
end
-- delete named profile
function config_meta:DeleteProfile(profile_name)
    self:GSV().profiles[profile_name] = nil
end
-- copy named profile to given name
function config_meta:CopyProfile(profile_name,new_name)
    assert(profile_name)
    assert(new_name)
    assert(not self:ProfileExists(new_name))

    local profile = self:CreateProfile(new_name)
    if not profile then return end

    Mixin(profile,self:GetProfile(profile_name))
    return true
end
-- copy named profile to given name and delete the old one
function config_meta:RenameProfile(profile_name,new_name)
    assert(profile_name)
    assert(new_name)
    -- copy the profile to the new name
    if self:CopyProfile(profile_name,new_name) then
        -- switch to it
        self:SetProfile(new_name)
        -- and delete the old name
        self:DeleteProfile(profile_name)
    end
end
-- reset named profile to defaults (by deleting and recreating it)
function config_meta:ResetProfile(profile_name)
    assert(profile_name)
    self:DeleteProfile(profile_name)
    self:CreateProfile(profile_name)
end
