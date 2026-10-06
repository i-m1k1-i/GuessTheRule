return {
	["Interface"]={
		["MaxSlots"]=9;
		["UnderlineOnSelection"]=false;
		["OutlineOnSelection"]=true;
		--[[
		AppearanceOnFill: The slots only appear on screen once a tool
		gets assigned to them. (ie they remain visible only when
		they have a tool)
		--]]
		["AppearanceOnFill"]=true;
		--[[
		ItemStacks: You can make certain items stack, instead of going
		in individual slots. In order to make a tool stack, add a boolean
		attribute to the tool and rename it exactly to "Stacks".
		]]--
		["ItemStacks"]=true;
		--[[
		InventoryHotkey: Set it to nil if you do not want any hotkey to trigger
		the inventory.
		]]--
		["InventoryHotkey"]=Enum.KeyCode.Backquote,
		
		["SlotsPerPage"]=15; -- Changing this may cause problems with layout
		--[[ Do Not Touch ]]--
		["CurrentSlot"]=Instance.new("StringValue"); 	
		["CurrentPage"]="Page.1";
		["Debounce"]={
			["Status"]=false;
			["Duration"]=0.1;
		}
	};
	--[[ Do Not Touch ]]--
	["AssignedSlots"]={};
	["StackList"]={};
	["Deleting"] = false
}