local aegisub = aegisub
local tr = aegisub.gettext

script_name = tr "Arabic Ruller"
script_description = tr "Fixes and cleans Arabic subtitles !"
script_author = tr "Bilal Bassam, bilal2453@github.com"
script_version = "1.2"
script_modified = "2 August 2019"

local re = require 'aegisub.re' -- 'Re' doesn't have any issues with Arabic unlike gsub

--[[
	When rendering Arabic language ltr characters (like . , :) at the end of line,
	it appears flipped, that's why some translators flips ltr chars,
	in Arabic language this '.Hello' (Hello refers to any Arabic word)
	is the correct thing to type,
	but it has a flipped rendering in aegisub,
	it appears as 'Hello.' and '.Hello' appears as 'Hello.',
	so Arabs translators uses 'Hello.' instead.

	The problem is, when you use some softwares like MeGUI, it actually renders it correctly
	(renders 'Hello.' as it is, when aegisub renders it as '.Hello')

	to fix that, first, reverse ltr chars in sub lines and then insert 'rtl override' character
		'U+202E', so vsfilter knows where to render these characters.
]]

local function iterSubs(subs, c)
	subs = type(subs) == "userdata" and subs or error("bad argument #1 to 'iterSubs' (subtitle object expected, got ".. type(subs)..')')
	c = type(c) == "function" and c or error("bad argument #2 to 'iterSubs' (function expected, got ".. type(c)..')')

	local e, x
	for i, v in ipairs(subs) do
		aegisub.progress.set(i * 100 / #subs)
		if aegisub.progress.is_cancelled() then aegisub.cancel() end

		if v.class == 'dialogue' and not v.comment then -- Because only used in macros as a shortcut
			e, x = pcall(c, i, v)
			if not e then error(x) end
		end
	end
end

function reverse(tx)
	local rvSym = {'.', ',', '!', '?', ':', ';',}
	local rvArabicSym = {'،', '؛',}

	for _, v in ipairs(rvSym) do
		tx = tx:gsub('^([%'..v..']+)(%s?)(.*)', '%3%2%1')
			:gsub('^"([%'..v..']+)(%s?)(.*)"$', '"%3%2%1"')
			:gsub("^'([%"..v.."]+)(%s?)(.*)'$", "'%3%2%1'")
	end

	for _, v in ipairs(rvArabicSym) do
		tx = tx:gsub('^('..v..')(.*)', "%2%1")
	end

	return tx
end

function clean(tx)
	local patterns = {
		-- TODO: Use \\.{3,} instead of this
		{'\\s*\\.\\.\\.[\\.]*\\s*([^\\.])', '.. \\1'},-- Converts "مثال...مثال" to "مثال.. مثال"
		{'\\s*\\.\\.\\.[\\.]*\\s*$', ' ..'},			 -- Converts "...مثال" to ".. مثال" (At end of line)
		{'([^\\.\\s])\\.\\s*$', '\\1'},					 -- Converts '.مثال' to 'مثال' (strips full stop)
		{'([^\\.^\\s])\\.\\s*"$', '\\1"'},				 -- Converts '".مثال"' to '"مثال"' (Same above but inside quotation marks)
		{"([^\\.^\\s])\\.\\s*'$", '\\1\''},				 -- Converts "'.مثال'" to "'مثال'" (Same above but inside single quotation marks)
		{'(\\S)؟', '\\1 ؟'},									 -- Converts "مثال؟" to "مثال ؟"
		{'([^؟])([!]+)$', '\\1 \\2'},					 -- Converts "Example!" to "Example !" and yeah... 'مثال' means 'example' !
	}

	for _, p in ipairs(patterns) do
		tx = re.sub(tx, p[1], p[2])
	end

	return tx
end

function insertRTL(tx)
	return '\226\128\143\226\128\171\226\128\171\226\128\174\226\128\171\226\128\143\226\128\143\226\128\174\226\128\174'.. tx
	-- U+202E - 'Right to left override'
	-- TODO: HEX version of that thing... Too lazy for a hex version... nah maybe later...
end

function stripWawSpace(tx)
	-- Normal gsub will do...
	return tx:gsub('(%s\217\136)%s+', '%1'):gsub('^(\217\136)%s+','%1') -- \217\136 = U+0648 Arabic letter "Waw" - 'و'
end

function convertHuhToWhat(tx) -- Because it's Arabic !!
	return tx:gsub("\217\135\216\167\217\135", "\217\133\216\167\216\176\216\167")
	-- \217\135\216\167\217\135 = "هاه" (Huh)
	-- \217\133\216\167\216\176\216\167 = "ماذا" (what)
	-- Note: Every two codes equals one letter
end

function convertDotToComma(tx)
	return tx:gsub('([^%.%d].)%.([^%.%d].)', '%1\216\140%2') -- \216\140 = U+060C - Arabic comma
end

-- Macros --

function clean_macro(subs)
	iterSubs(subs, function(i, v)
		v.text = clean(v.text)
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

function reverse_macro(subs)
	iterSubs(subs, function(i, v)
		v.text = reverse(v.text)
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

function insertRTL_macro(subs)
	iterSubs(subs, function(i, v)
		v.text = insertRTL(v.text)
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

function stripWawSpace_macro(subs)
	iterSubs(subs, function(i, v)
		v.text = stripWawSpace(v.text)
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

function convertHuhToWhat_macro(subs)
	iterSubs(subs, function(i, v)
		v.text = convertHuhToWhat(v.text)
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

function convertDotToComma_macro(subs)
	iterSubs(subs, function(i, v)
		v.text = convertDotToComma(v.text)
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

function allInOne_macro(subs)
	-- Not going to use above macros functions directly here because of 'set_undo_point'
	iterSubs(subs, function(i, v)
		v.text = reverse(v.text)
		v.text = clean(v.text)
		v.text = stripWawSpace(v.text)
		v.text = convertHuhToWhat(v.text)
		v.text = insertRTL(v.text)
		v.text = convertDotToComma(v.text)
		
		subs[i] = v
	end)

	aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name.."/Clean", 'Cleans and re-arange Arabic subtitle lines.', clean_macro)
aegisub.register_macro(script_name.."/Reverse Symbols", 'Reverse LTR Chars on the first of lines.', reverse_macro)
aegisub.register_macro(script_name.."/Insert RTL Char", 'Insert RTL Override character to fix fliped LTR Chars.', insertRTL_macro)
aegisub.register_macro(script_name.."/Strip Waw Space", 'Strips any space before Arabic letter Waw.', stripWawSpace_macro)
aegisub.register_macro(script_name.."/Convert Huh to What", 'Convert "هاه" to "ماذا".', convertHuhToWhat_macro)
aegisub.register_macro(script_name.."/Convert dot to comma", 'Convert fullstops in center of lines to Arabic comma.', convertDotToComma_macro)
aegisub.register_macro(script_name.."/All in One", 'Applys all above macros by a speacific order.', allInOne_macro)
