local PrimeUI = require "prime"

local function sizeChk(inp)
    inp = inp:gsub("^%s*(.-)%s*$", "%1")
    local size, unit = inp:match("^(%d+%.?%d*)%s*([KkMmGg]?[Bb]?)$")

    if not size or not unit then
        return nil, nil
    end

    size = tonumber(size)
    unit = unit:upper():gsub("B", "")

    local unitMap = {
        ["K"] = "KB",
        ["M"] = "MB",
        ["G"] = "GB",
        [""] = "B"
    }

    unit = unitMap[unit] or "B"

    return size, unit
end

local function write_bytes(filename, byte_table, start_position)
    local file = fs.open(filename, "rb")
    local content = file and file.readAll() or ""
    if file then file.close() end

    local bytes = {string.byte(content, 1, #content)}

    local end_position = start_position + #byte_table - 1
    while #bytes < end_position do
        table.insert(bytes, 0)
    end

    for i, byte in ipairs(byte_table) do
        bytes[start_position + i - 1] = byte
    end

    local newContent = string.char(table.unpack(bytes))

    file = fs.open(filename, "wb")
    file.write(newContent)
    file.close()
end

local subFSver = "0.000.b"
local function main()
    PrimeUI.clear()
    local entries = {
        "Create a disk",
        "Disk info",
        "Exit",
    }
    local entries_descriptions = {
        "Create a .vhd file using subFS",
        "Read disk metadata",
        "Exit this menu",
    }
    local redraw = PrimeUI.textBox(term.current(), 2, 11, 40, 3, entries_descriptions[1])
    PrimeUI.borderBox(term.current(), 3, 2, 40, 8)
    PrimeUI.selectionBox(term.current(), 3, 2, 40, 8, entries, "done", function(option) redraw(entries_descriptions[option]) end)
    local _, _, selection = PrimeUI.run()
    PrimeUI.clear()
    local txt = "subFS"

    if selection == "Create a disk" then
        local text
        local fName
        local inode_num,size,unit,blockSize,totalBlocks

        PrimeUI.label(term.current(), 3, 2, txt)
        PrimeUI.horizontalLine(term.current(), 3, 3, #txt + 2)
        PrimeUI.label(term.current(), 3, 5, "Enter filename(.vhd)")
        PrimeUI.borderBox(term.current(), 4, 7, 40, 1)
        PrimeUI.inputBox(term.current(), 4, 7, 40, "result")
        _, _, fName = PrimeUI.run()
        PrimeUI.clear()

        while true do
            PrimeUI.label(term.current(), 3, 2, txt)
            PrimeUI.horizontalLine(term.current(), 3, 3, #txt + 2)
            PrimeUI.label(term.current(), 3, 5, "disk size (use B, KB, MB, GB)")
            local freeSpace = fs.getFreeSpace("/")
            if freeSpace/1024/1024 > 1024 then
                freeSpace = tostring(math.floor(freeSpace/1024/1024/1024)).."gB"
            elseif freeSpace/1024 > 1024 then
                freeSpace = tostring(math.floor(freeSpace/1024/1024)).."mB"
            else
                freeSpace = tostring(math.floor(freeSpace/1024)).."kB"
            end
            PrimeUI.label(term.current(), 3, 6, freeSpace.." left")
            PrimeUI.borderBox(term.current(), 4, 8, 40, 1)
            PrimeUI.inputBox(term.current(), 4, 8, 40, "result")
            _, _, text = PrimeUI.run()
            PrimeUI.clear()
            if sizeChk(text) then
                break
            end
        end

        size,unit = sizeChk(text)

        if unit == "KB" then
            size = size * 1024
        elseif unit == "MB" then
            size = size * 1024 * 1024
        elseif unit == "GB" then
            size = size * 1024 * 1024 * 1024
        end

        size = math.floor(size)

        local sizekB = size/1024

        entries = {
            "4kb/inode",
            "2kb/inode (reccomended)",
            "1kb/inode (many files)",
        }
        entries_descriptions = {
            tostring(math.floor(sizekB/4)).." inodes with your current configuration\n"..tostring(sizekB*16/1024).." kB allocated to inodes",
            tostring(math.floor(sizekB/2)).." inodes with your current configuration\n"..tostring(sizekB*32/1024).." kB allocated to inodes",
            tostring(math.floor(sizekB)).." inodes with your current configuration\n"..tostring(sizekB*64/1024).." kB allocated to inodes",
        }
        redraw = PrimeUI.textBox(term.current(), 2, 11, 40, 3, entries_descriptions[1])
        PrimeUI.borderBox(term.current(), 3, 2, 40, 8)
        PrimeUI.selectionBox(term.current(), 3, 2, 40, 8, entries, "done", function(option) redraw(entries_descriptions[option]) end)
        _, _, selection = PrimeUI.run()
        PrimeUI.clear()

        if selection == "4kb/inode" then
            inode_num = math.floor(sizekB/4)
        elseif selection == "2kb/inode (reccomended)" then
            inode_num = math.floor(sizekB/2)
        else
            inode_num = math.floor(sizekB)
        end

        entries = {
            "512 byte blocks",
            "1kb blocks (reccomended)",
            "2kb blocks (bigger disk)",
        }
        entries_descriptions = {
            tostring(math.floor(sizekB*2)).." blocks with your current configuration",
            tostring(math.floor(sizekB)).." blocks with your current configuration",
            tostring(math.floor(sizekB/2)).." blocks with your current configuration"
        }
        redraw = PrimeUI.textBox(term.current(), 2, 11, 40, 3, entries_descriptions[1])
        PrimeUI.borderBox(term.current(), 3, 2, 40, 8)
        PrimeUI.selectionBox(term.current(), 3, 2, 40, 8, entries, "done", function(option) redraw(entries_descriptions[option]) end)
        _, _, selection = PrimeUI.run()
        PrimeUI.clear()

        if selection == "512 byte blocks" then
            blockSize = 512
        elseif selection == "1kb blocks (reccomended)" then
            blockSize = 1024
        else
            blockSize = 2048
        end

        totalBlocks = math.floor(size/blockSize)

        local repSize = string.rep("\0", 32 - #(tostring(size))) .. tostring(size)
        local repBlocks = string.rep("\0", 32 - #(tostring(totalBlocks))) .. tostring(totalBlocks)
        local repBlockSize = string.rep("\0",4 - #(tostring(blockSize))) .. tostring(blockSize)
        local diskFreeSpace = size - 128 - (inode_num * 64) -- 128 is superblock size in bytes. Make sure to update!
        local repDiskFreeSpace = string.rep("\0",32 - #(tostring(diskFreeSpace))) .. tostring(diskFreeSpace)
        local repInodeNum = string.rep("\0",16 - #(tostring(inode_num))) .. tostring(inode_num)
        --[[
            superblock format:
            subFS (5)
            version (7)
            size in bytes (32)
            total blocks (32)
            block size (4)
            free space in bytes (32)
            inode count (16)
        ]]
        local superblock = "subFS"..subFSver..repSize..repBlocks..repBlockSize..repDiskFreeSpace..repInodeNum

        local vhdFile = fs.open(fName..".vhd","wb")
        vhdFile.write(superblock..string.char(128)..string.rep("\0",size - #superblock - 1))
        vhdFile.close()
        print(fName..".vhd has been created.")
    elseif selection == "Disk info" then
        local fName

        PrimeUI.label(term.current(), 3, 2, txt)
        PrimeUI.horizontalLine(term.current(), 3, 3, #txt + 2)
        PrimeUI.label(term.current(), 3, 5, "Enter filename, including extension")
        PrimeUI.borderBox(term.current(), 4, 7, 40, 1)
        PrimeUI.inputBox(term.current(), 4, 7, 40, "result")
        _, _, fName = PrimeUI.run()
        PrimeUI.clear()

        local vhdFile = fs.open(fName,"rb")
        local vhdDat = vhdFile.read(128)
        vhdFile.close()

        local sb_subFS = string.sub(vhdDat,1,5):gsub("\0","")
        local sb_ver = string.sub(vhdDat,6,12):gsub("\0","")
        local sb_size = string.sub(vhdDat,13,44):gsub("\0","")
        local sb_blocks = string.sub(vhdDat,45,76):gsub("\0","")
        local sb_blocksize = string.sub(vhdDat,77,80):gsub("\0","")
        local sb_freespace = string.sub(vhdDat,81,112):gsub("\0","")
        local sb_inodes = string.sub(vhdDat,113,128):gsub("\0","")

        local info = "subFS Identifier   "..sb_subFS.."\nsubFS Version      "..sb_ver.."\nTotal disk size    "..sb_size.."B\nBlock count        "..sb_blocks.."\nBlock size         "..sb_blocksize.."\nFree space left    "..sb_freespace.."B\nTotal inodes       "..sb_inodes

        PrimeUI.clear()
        PrimeUI.label(term.current(), 3, 2, txt)
        PrimeUI.horizontalLine(term.current(), 3, 3, #txt + 2)
        PrimeUI.borderBox(term.current(), 4, 6, 40, 10)
        local scroller = PrimeUI.scrollBox(term.current(), 4, 6, 40, 10, 9000, true, true)
        PrimeUI.drawText(scroller, info, true)
        PrimeUI.button(term.current(), 3, 18, "Done", "done")
        PrimeUI.keyAction(keys.enter, "done")
        PrimeUI.run()
        PrimeUI.clear()
    end
end

local function pad_left(inp, length)
    local current_length = #(tostring(inp))
    if current_length >= length then
        return inp
    end

    local pad_size = length - current_length
    local padding = string.rep("\0", pad_size)

    return padding .. inp
end

local function chkRequire() -- this is janky. allows a user interface & API to be packaged in one file though
    local level = 2
    while true do
        local info = debug.getinfo(level, "n")
        if not info then break end
        if info.name == "require" then
            return true
        end
        level = level + 1
    end
    return false
end

local function parse_permissions(perm_str)
    if #perm_str ~= 9 then
        error("Invalid permission string format. Expected 9 characters.")
    end

    local function perm_to_digit(start)
        local r = (perm_str:sub(start, start) == "r") and 4 or 0
        local w = (perm_str:sub(start + 1, start + 1) == "w") and 2 or 0
        local x = (perm_str:sub(start + 2, start + 2) == "x") and 1 or 0
        return r + w + x
    end

    local owner = perm_to_digit(1)
    local group = perm_to_digit(4)
    local others = perm_to_digit(7)

    return tonumber(string.format("%d%d%d", owner, group, others))
end

local function create_permissions(octal)
    local octal_str = tostring(octal)
    if #octal_str ~= 3 then
        error("Invalid octal format. Expected 3 digits (e.g., 754).")
    end

    local function digit_to_perm(digit)
        digit = tonumber(digit)
        return string.format("%s%s%s",
            (bit.band(digit, 4) > 0) and "r" or "-",
            (bit.band(digit, 2) > 0) and "w" or "-",
            (bit.band(digit, 1) > 0) and "x" or "-")
    end

    return digit_to_perm(octal_str:sub(1,1)) ..
           digit_to_perm(octal_str:sub(2,2)) ..
           digit_to_perm(octal_str:sub(3,3))
end

--[[
local perm_str = "rwxr-xr--"
local octal = parse_permissions(perm_str)
print("parsed:", octal)  --> Output: 754

local perm_str_back = create_permissions(octal) --> rwxr-xr--
print("generated:", perm_str_back)  --> Output: rwxr-xr--
]]

local function to_byte_table(input, little_endian)
    local byte_table = {}

    if type(input) == "string" then
        for i = 1, #input do
            table.insert(byte_table, string.byte(input, i))
        end
    elseif type(input) == "number" then
        while input > 0 do
            table.insert(byte_table, 1, bit.band(input, 0xFF))
            input = bit.brshift(input, 8)
        end
        if little_endian then
            local reversed = {}
            for i = #byte_table, 1, -1 do
                table.insert(reversed, byte_table[i])
            end
            byte_table = reversed
        end
    else
        error("Unsupported type. Input must be a string or number.")
    end

    return byte_table
end

--[[
local str_bytes = to_byte_table("ABC")  --> {65, 66, 67}
local num_bytes_le = to_byte_table(0x123456, true)  --> {86, 52, 18} (little-endian)

print("string to bytes:", table.concat(str_bytes, ", "))  -- Output: 65, 66, 67
print("number to bytes (little-endian):", table.concat(num_bytes_le, ", "))  -- Output: 86, 52, 18
]]

local function epochToBytes(num)
    num = num % 4294967296

    local byte1 = num % 256
    local byte2 = math.floor(num / 256) % 256
    local byte3 = math.floor(num / 65536) % 256
    local byte4 = math.floor(num / 16777216) % 256

    return string.char(byte4, byte3, byte2, byte1)
end

--[[
local num = 1234567890
local byteString = epochToBytes(num)
print(byteString)
]]

local subFS = {}

subFS.parse_permissions = parse_permissions
subFS.create_permissions = create_permissions
subFS.byte_table = to_byte_table

function subFS.createDisk(fName,size,blockSize,kbinode)
    local inodes = math.floor(size/1024/kbinode)
    local totalBlocks = math.floor(size/blockSize)

    local repSize = string.rep("\0", 32 - #(tostring(size))) .. tostring(size)
    local repBlocks = string.rep("\0", 32 - #(tostring(totalBlocks))) .. tostring(totalBlocks)
    local repBlockSize = string.rep("\0",4 - #(tostring(blockSize))) .. tostring(blockSize)
    local diskFreeSpace = size - 128 - (inodes * 64) -- 128 is superblock size in bytes. Make sure to update!
    local repDiskFreeSpace = string.rep("\0",32 - #(tostring(diskFreeSpace))) .. tostring(diskFreeSpace)
    local repInodeNum = string.rep("\0",16 - #(tostring(inodes))) .. tostring(inodes)
    --[[
        superblock format:
        subFS (5)
        version (7)
        size in bytes (32)
        total blocks (32)
        block size (4)
        free space in bytes (32)
        inode count (16)
    ]]
    local superblock = "subFS"..subFSver..repSize..repBlocks..repBlockSize..repDiskFreeSpace..repInodeNum

    local vhdFile = fs.open(fName,"wb")
    vhdFile.write(superblock..string.char(128)..string.rep("\0",size - #superblock - 1))
    vhdFile.close()
end

--[[
subFS.createDisk("testing.vhd",1048576,1024,2) -- testing.vhd becomes a 1mb disk with 1kb blocks and 512 inodes
]]

function subFS.getDiskInfo(fName)
    local vhdFile = fs.open(fName,"rb")
    local vhdDat = vhdFile.read(128)
    vhdFile.close()

    local sb_subFS = string.sub(vhdDat,1,5):gsub("\0","")
    local sb_ver = string.sub(vhdDat,6,12):gsub("\0","")
    local sb_size = string.sub(vhdDat,13,44):gsub("\0","")
    local sb_blocks = string.sub(vhdDat,45,76):gsub("\0","")
    local sb_blocksize = string.sub(vhdDat,77,80):gsub("\0","")
    local sb_freespace = string.sub(vhdDat,81,112):gsub("\0","")
    local sb_inodes = string.sub(vhdDat,113,128):gsub("\0","")

    return {sb_subFS,sb_ver,sb_size,sb_blocks,sb_blocksize,sb_freespace,sb_inodes}
end

--[[
local data = subFS.getDiskInfo("testing.vhd") 
-- subFS identifier, version, size (bytes), blocks, block size (bytes), free space (bytes), inodes (bytes)

local info = "subFS Identifier   "..data[1].."\nsubFS Version      "..data[2].."\nTotal disk size    "..data[3].."B\nBlock count        "..data[4].."\nBlock size         "..data[5].."\nFree space left    "..data[6].."B\nTotal inodes       "..data[7]
print(info)
]]

function subFS.formatDiskInfo(data)
    local retDat = {}
    local c = 1
    local function insDat(num)
        retDat[c] = pad_left(data[c],num)
        c = c + 1
    end

    insDat(5)
    insDat(7)
    insDat(32)
    insDat(32)
    insDat(4)
    insDat(32)
    insDat(16)

    return retDat
end

function subFS.setDiskInfo(fName, data)
    local vhd = fs.open(fName,"r+b")
    vhd.seek("set", 0)
    vhd.write(table.concat(data,""))
    vhd.close()
end

--[[
local data = subFS.getDiskInfo("testing.vhd")
data[6] = "42069"

subFS.setDiskInfo("testing.vhd",subFS.formatDiskInfo(data))
-- sets free space to 42069 bytes
]]

function subFS.findUnallocatedBlocks(fName, num)
    local bindat = {}
    local c = 0
    local blocktable = {}
    local data = subFS.getDiskInfo(fName)
    local drive = fs.open(fName,"rb")
    drive.seek("set",128)
    local bytecount = math.ceil(data[4]/8)
    local bytedat = drive.read(bytecount)
    for i = 1, #bytedat do
        local byte = string.byte(bytedat,i)
        for j = 7, 0, -1 do
            table.insert(bindat, bit32.extract(byte, j) == 1)
        end
    end

    for i = 1, data[4] do
        if bindat[i] == false then
            c = c + 1
            table.insert(blocktable,i)
            if c >= num then
                return blocktable
            end
        end
    end
    return false
end

--[[
local testblocks = subFS.findUnallocatedBlocks("testing.vhd",10)
if testblocks then
    print(textutils.serialise(testblocks))
end
]]

function subFS.getRealFreeSpace(fName)
    local bindat = {}
    local c = 0
    local data = subFS.getDiskInfo(fName)
    local drive = fs.open(fName,"rb")
    drive.seek("set",128)
    local bytecount = math.ceil(data[4]/8)
    local bytedat = drive.read(bytecount)
    for i = 1, #bytedat do
        local byte = string.byte(bytedat,i)
        for j = 7, 0, -1 do
            table.insert(bindat, bit32.extract(byte, j) == 1)
        end
    end

    for i = 1, data[4] do
        if bindat[i] == false then
            c = c + 1
        end
    end
    return c * data[5]
end

print(subFS.getRealFreeSpace("testing.vhd"))

local function computeInodePos(fName)
    local data = subFS.getDiskInfo(fName)
    local c = 128
    c = c + math.ceil(data[4] / 8)
    return c
end

local function setBlock(fName, bytes, bitIndex, value)
    local vhdFile = fs.open(fName,"rb")
    vhdFile.seek("set",128)

    local data = vhdFile.read(bytes)

    local byteTable = {string.byte(data, 1, #data)}

    local bytePos = math.floor(bitIndex / 8) + 1
    local bitPos = bitIndex % 8

    if bytePos > bytes then return nil, "Bit index out of range" end

    if value then
        byteTable[bytePos] = bit.bor(byteTable[bytePos], bit.blshift(1, bitPos))
    else
        byteTable[bytePos] = bit.band(byteTable[bytePos], bit.bnot((bit.blshift(1, bitPos))))
    end

    local newData = string.char(table.unpack(byteTable))

    vhdFile.write(newData)
    vhdFile.close()
end

function subFS.addInode(fName,Itype,Iperms,Iowner,Iguid,Ifsize,Iptype,Ipointers)
    --[[
    typeByte (1) regular/directory --> 1/2
    permBytes (2)
    ownerBytes (4)
    groupBytes (4)
    sizeBytes (8)
    Iptype (1) direct/SIP/DIP --> d/i/2
    pointers (40)
    timestamp (4)

    64 bytes total

    pointers:
    d --> direct pointer, 10.2kb max on 1kb block systems
    i --> indirect pointer (references other blocks, 2.5mb max on 1kb block systems)
    2 --> dual indirect pointer (references other indirect pointers, 2.5gb max on 1kb block systems)
    ]]
    local typeByte
    if Itype == "regular" then
        typeByte = "1"
    elseif Itype == "directory" then
        typeByte = "2"
    end

    local ptypeByte
    if Iptype == "direct" then
        ptypeByte = "d"
    elseif Iptype == "SIP" then
        ptypeByte = "i"
    elseif Iptype == "DIP" then
        ptypeByte = "2"
    end

    local permBytes = to_byte_table(pad_left(Iperms,2),true)

    local ownerBytes = to_byte_table(pad_left(Iowner,4),true)
    local groupBytes = to_byte_table(pad_left(Iguid,4),true)

    local sizeBytes = to_byte_table(pad_left(Ifsize,8),true)

    local timestamp = os.epoch("utc")/1000
    timestamp = epochToBytes(timestamp)

    local pointerstr = ""
    local c = 0
    for _,pointer in ipairs(Ipointers) do
        pointerstr = pointerstr..epochToBytes(pointer) -- epochToBytes returns a padded 4 byte version of a number. works here too!
        c = c + 1
    end
    if c > 10 then
        error("Could not add inode to "..fName.." due to too many pointers. Maximum number is 10. Try using indirect (i) or dual indirect (2) pointers")
    end

    local data = subFS.getDiskInfo(fName)
    local vhdFile = fs.open(fName, "rb")
    local iPos
    vhdFile.seek("set",computeInodePos(fName))
    local inodeDat

    for i = 1, tonumber(data[7]) do
        inodeDat = vhdFile.read(64)
        if inodeDat == string.rep("\0",64) then
            iPos = i
            break
        end
    end

    vhdFile.close()

    if iPos == nil then
        error("Could not add inode to "..fName.." due to no available inodes found")
    end

    vhdFile = fs.open(fName,"rb")

    local blockTrack = {}
    local pointerDat
    local sipDat

    if ptypeByte == "d" then
        blockTrack = Ipointers
    
    elseif ptypeByte == "i" then
        for _, pointerBlock in ipairs(Ipointers) do
            vhdFile.seek("set", pointerBlock * data[5])  -- Seek to indirect block
            for i = 1, math.floor(data[5] / 4) do
                pointerDat = vhdFile.read(4)
                if pointerDat ~= string.rep("\0", 4) then
                    blockTrack[#blockTrack + 1] = string.unpack("<I4", pointerDat)  -- Store data block pointer
                end
            end
        end
    
    elseif ptypeByte == "2" then  -- Double Indirect Case
        for _, dipBlock in ipairs(Ipointers) do
            vhdFile.seek("set", dipBlock * data[5])  -- Seek to double indirect block
            
            local sipBlocks = {}  -- Store all single indirect block pointers
            for i = 1, math.floor(data[5] / 4) do
                sipDat = vhdFile.read(4)
                if sipDat ~= string.rep("\0", 4) then
                    sipBlocks[#sipBlocks + 1] = string.unpack("<I4", sipDat)  -- Store all SIP blocks
                end
            end
    
            for _, sipBlock in ipairs(sipBlocks) do
                vhdFile.seek("set", sipBlock * data[5])  -- Seek to single indirect block
                for j = 1, math.floor(data[5] / 4) do
                    pointerDat = vhdFile.read(4)
                    if pointerDat ~= string.rep("\0", 4) then
                        blockTrack[#blockTrack + 1] = string.unpack("<I4", pointerDat)  -- Store data block pointer
                    end
                end
            end
        end
    end
    

    vhdFile.close()

    print("Direct pointers as per referenced by indirect block pointer(s): "..table.concat(Ipointers,", "))
    print(textutils.serialise(blockTrack))
    --print(#blockTrack)
end

local inode = subFS.addInode(                      -- returns the assigned inode number
    "testing.vhd",                                 -- add inode to testing.vhd
    "regular",                                     -- regular file type
    parse_permissions("rwxr-xr--"),                -- rwxr-xr-- permissions
    0,                                             -- owner UID
    0,                                             -- GUID
    10000000000,                                   -- file size (B)
    "DIP",                                         -- dual indirect (layer) pointer
    {3}                                            -- using block 3 as an indirect pointer (not reccomended to use manually assigned blocks unless using SIP or DIP pointers)
)

--[[
local inode = subFS.addInode(                      -- returns the assigned inode number
    "testing.vhd",                                 -- add inode to testing.vhd
    "regular",                                     -- regular file type
    parse_permissions("rwxr-xr--"),                -- rwxr-xr-- permissions
    0,                                             -- owner UID
    0,                                             -- GUID
    10000000,                                      -- file size (B)
    "SIP",                                         -- single indirect (layer) pointer
    {3}                                            -- using block 3 as an indirect pointer (not reccomended to use manually assigned blocks unless using SIP or DIP pointers)
)

local inode = subFS.addInode(                      -- returns the assigned inode number
    "testing.vhd",                                 -- add inode to testing.vhd
    "regular",                                     -- regular file type
    parse_permissions("rwxr-xr--"),                -- rwxr-xr-- permissions
    0,                                             -- owner UID
    0,                                             -- GUID
    10000,                                         -- file size (B)
    "direct",                                      -- direct pointer
    subFS.findUnallocatedBlocks("testing.vhd",10)  -- automatically assign blocks
)
]]

if chkRequire() then
    return subFS
else
    --main()
end

-- we need more block functionality, add partition table!