struct VkParam
	typ::VkElType
	name::String
	optional::Bool
	attr::Attributes
end

VkParam(attr) = VkParam(VkElUnknown(),"",false,attr)

struct VkCommand
	name::String
	ret::VkElType
	params::Vector{VkParam}
	attr::Attributes
end

VkCommand(attr) = VkCommand("",VkElUnknown(),VkParam[],attr)